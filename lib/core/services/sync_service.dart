import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../supabase/supabase_client_service.dart';
import '../supabase/supabase_config.dart';

class SyncResult {
  final bool success;
  final String message;
  final Map<String, int> pushed;
  final Map<String, int> pulled;
  final List<String> errors;

  const SyncResult({
    required this.success,
    required this.message,
    this.pushed = const {},
    this.pulled = const {},
    this.errors = const [],
  });
}

enum SyncDirection { push, pull, both }

/// Hybrid sync: local SQLite ↔ Supabase Postgres.
///
/// **Policy: desktop is the source of truth.**
/// Default and automatic sync only **push** local → Supabase so the cloud
/// always mirrors this PC. Pull is available only as a manual recovery tool.
class SyncService {
  SyncService(this._databaseHelper, this._supabase);

  final DatabaseHelper _databaseHelper;
  final SupabaseClientService _supabase;

  static const int _pageSize = 1000;

  Timer? _debounceTimer;
  Timer? _periodicTimer;
  bool _pushInFlight = false;
  bool _pushQueued = false;

  /// Debounced upload (desktop → cloud). Call after local data changes.
  void scheduleDesktopPush({
    Duration delay = const Duration(seconds: 2),
  }) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, () {
      unawaited(pushFromDesktop());
    });
  }

  /// Periodic upload while the app is open (keeps Supabase = desktop).
  void startPeriodicDesktopPush({
    Duration interval = const Duration(minutes: 2),
  }) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(interval, (_) {
      unawaited(pushFromDesktop());
    });
  }

  void stopPeriodicDesktopPush() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  /// Upload local SQLite to Supabase (desktop source of truth).
  Future<SyncResult> pushFromDesktop() async {
    final enabled = await _supabase.getSyncEnabled();
    if (!enabled) {
      return const SyncResult(
        success: false,
        message: 'Cloud sync is disabled in Settings.',
      );
    }
    return sync(direction: SyncDirection.push);
  }

  Future<SyncResult> sync({
    SyncDirection direction = SyncDirection.push,
  }) async {
    if (direction == SyncDirection.push || direction == SyncDirection.both) {
      if (_pushInFlight) {
        _pushQueued = true;
        return const SyncResult(
          success: true,
          message: 'Push already running; queued another pass.',
        );
      }
      _pushInFlight = true;
    }

    final errors = <String>[];
    final pushed = <String, int>{};
    final pulled = <String, int>{};

    try {
      final ready = await _supabase.initializeFromSettings();
      if (!ready || _supabase.client == null) {
        return const SyncResult(
          success: false,
          message:
              'Supabase is not configured. Add URL and anon key in Settings.',
        );
      }

      final ok = await _supabase.testConnection();
      if (!ok) {
        return const SyncResult(
          success: false,
          message: 'Cannot reach Supabase. Check internet and credentials.',
        );
      }

      if (direction == SyncDirection.push || direction == SyncDirection.both) {
        // 1) Upsert all local rows (parents first)
        for (final table in supabaseSyncTables) {
          try {
            pushed[table] = await _upsertTable(table);
          } catch (e) {
            errors.add('push $table: $e');
            debugPrint('push $table error: $e');
          }
        }
        // 2) Remove cloud rows that no longer exist on desktop (children first)
        for (final table in supabaseSyncTables.reversed) {
          try {
            await _pruneRemoteTable(table);
          } catch (e) {
            errors.add('prune $table: $e');
            debugPrint('prune $table error: $e');
          }
        }
      }

      if (direction == SyncDirection.pull || direction == SyncDirection.both) {
        final preservedCreds = await _supabase.getStoredCredentials();
        final preservedEnabled = await _supabase.getSyncEnabled();
        final preservedAuto = await _supabase.getAutoSync();
        final preservedLast = await _supabase.getLastSyncAt();

        await _databaseHelper.withoutSyncNotify(() async {
          try {
            await _clearLocalTables();
          } catch (e) {
            errors.add('clear local: $e');
          }
          for (final table in supabaseSyncTables) {
            try {
              pulled[table] = await _pullTable(table, clearFirst: false);
            } catch (e) {
              errors.add('pull $table: $e');
              debugPrint('pull $table error: $e');
            }
          }
        });

        await _supabase.saveCredentials(
          url: preservedCreds['url'] ?? '',
          anonKey: preservedCreds['anonKey'] ?? '',
        );
        await _supabase.setSyncEnabled(preservedEnabled);
        await _supabase.setAutoSync(preservedAuto);
        if (preservedLast != null && preservedLast.isNotEmpty) {
          await _supabase.setLastSyncAt(
            DateTime.tryParse(preservedLast) ?? DateTime.now(),
          );
        }
      }

      await _supabase.setLastSyncAt(DateTime.now());

      final success = errors.isEmpty;
      final summary = StringBuffer();
      if (pushed.isNotEmpty) {
        final total = pushed.values.fold<int>(0, (a, b) => a + b);
        summary.write('Uploaded $total rows from desktop. ');
      }
      if (pulled.isNotEmpty) {
        final total = pulled.values.fold<int>(0, (a, b) => a + b);
        summary.write('Downloaded $total rows. ');
      }
      if (errors.isNotEmpty) {
        summary.write('${errors.length} error(s).');
      }

      return SyncResult(
        success: success,
        message: summary.toString().trim().isEmpty
            ? 'Sync finished'
            : summary.toString().trim(),
        pushed: pushed,
        pulled: pulled,
        errors: errors,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        message: 'Sync failed: $e',
        pushed: pushed,
        pulled: pulled,
        errors: [...errors, e.toString()],
      );
    } finally {
      if (direction == SyncDirection.push || direction == SyncDirection.both) {
        _pushInFlight = false;
        if (_pushQueued) {
          _pushQueued = false;
          scheduleDesktopPush(delay: const Duration(seconds: 2));
        }
      }
    }
  }

  Future<int> _upsertTable(String table) async {
    final db = await _databaseHelper.database;
    List<Map<String, Object?>> rows;
    try {
      rows = await db.query(table);
    } catch (_) {
      return 0;
    }

    final client = _supabase.client!;
    if (rows.isEmpty) return 0;

    var count = 0;
    for (var i = 0; i < rows.length; i += _pageSize) {
      final end = (i + _pageSize < rows.length) ? i + _pageSize : rows.length;
      final chunk = rows.sublist(i, end).map(_normalizeRowForRemote).toList();
      await client.from(table).upsert(chunk, onConflict: 'id');
      count += chunk.length;
    }
    return count;
  }

  /// Delete remote rows whose ids are not present on the desktop DB.
  Future<void> _pruneRemoteTable(String table) async {
    final db = await _databaseHelper.database;
    Set<int> localIds;
    try {
      final rows = await db.query(table, columns: ['id']);
      localIds = {
        for (final r in rows)
          if (r['id'] != null) int.parse(r['id'].toString()),
      };
    } catch (_) {
      return;
    }

    final client = _supabase.client!;
    final remoteIds = <int>[];
    var from = 0;
    while (true) {
      final page = await client
          .from(table)
          .select('id')
          .range(from, from + _pageSize - 1);
      final list = List<Map<String, dynamic>>.from(page as List);
      for (final row in list) {
        final id = row['id'];
        if (id != null) remoteIds.add(int.parse(id.toString()));
      }
      if (list.length < _pageSize) break;
      from += _pageSize;
    }

    final toDelete =
        remoteIds.where((id) => !localIds.contains(id)).toList();
    if (toDelete.isEmpty) return;

    for (var i = 0; i < toDelete.length; i += 100) {
      final end = (i + 100 < toDelete.length) ? i + 100 : toDelete.length;
      final chunk = toDelete.sublist(i, end);
      await client.from(table).delete().inFilter('id', chunk);
    }
    debugPrint('pruned $table: removed ${toDelete.length} remote row(s)');
  }

  Future<void> _clearLocalTables() async {
    final db = await _databaseHelper.database;
    await db.execute('PRAGMA foreign_keys = OFF');
    try {
      await db.transaction((txn) async {
        for (final table in supabaseSyncTables.reversed) {
          try {
            await txn.delete(table);
          } catch (_) {}
        }
      });
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
    }
  }

  Future<int> _pullTable(String table, {bool clearFirst = true}) async {
    final client = _supabase.client!;
    final db = await _databaseHelper.database;

    final allRows = <Map<String, dynamic>>[];
    var from = 0;
    while (true) {
      final page = await client
          .from(table)
          .select()
          .range(from, from + _pageSize - 1);
      final list = List<Map<String, dynamic>>.from(page as List);
      allRows.addAll(list);
      if (list.length < _pageSize) break;
      from += _pageSize;
    }

    Map<String, String>? preserve;
    if (table == 'store_settings') {
      preserve = {};
      for (final key in localOnlySettingKeys) {
        final existing = await db.query(
          'store_settings',
          where: 'setting_key = ?',
          whereArgs: [key],
        );
        if (existing.isNotEmpty) {
          preserve[key] = existing.first['setting_value'] as String;
        }
      }
    }

    await db.transaction((txn) async {
      if (clearFirst) {
        await txn.delete(table);
      }
      for (final raw in allRows) {
        final row = _normalizeRowForLocal(raw);
        if (table == 'store_settings') {
          final key = row['setting_key'] as String?;
          if (key != null && localOnlySettingKeys.contains(key)) {
            continue;
          }
        }
        await txn.insert(
          table,
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      if (table == 'store_settings' && preserve != null) {
        for (final entry in preserve.entries) {
          final updated = await txn.update(
            'store_settings',
            {
              'setting_value': entry.value,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'setting_key = ?',
            whereArgs: [entry.key],
          );
          if (updated == 0) {
            await txn.insert('store_settings', {
              'setting_key': entry.key,
              'setting_value': entry.value,
            });
          }
        }
      }
    });

    return allRows.length;
  }

  Map<String, dynamic> _normalizeRowForRemote(Map<String, Object?> row) {
    final out = <String, dynamic>{};
    row.forEach((key, value) {
      if (value is bool) {
        out[key] = value;
      } else if (key == 'is_active' && value is int) {
        out[key] = value != 0;
      } else {
        out[key] = value;
      }
    });
    return out;
  }

  Map<String, Object?> _normalizeRowForLocal(Map<String, dynamic> row) {
    final out = <String, Object?>{};
    row.forEach((key, value) {
      if (value is bool) {
        out[key] = value ? 1 : 0;
      } else if (value is num) {
        out[key] = value;
      } else {
        out[key] = value?.toString();
      }
    });
    for (final idKey in [
      'id',
      'quantity',
      'min_stock',
      'year',
      'month',
      'product_id',
      'customer_id',
      'supplier_id',
      'invoice_id',
      'user_id',
      'created_by',
      'cancelled_by',
      'original_sale_id',
      'price_list_id',
      'supplier_invoice_id',
      'entity_id',
    ]) {
      if (out.containsKey(idKey) && out[idKey] != null) {
        final parsed = int.tryParse(out[idKey].toString());
        if (parsed != null) out[idKey] = parsed;
      }
    }
    for (final numKey in [
      'price',
      'cost_price',
      'sale_price',
      'total_amount',
      'discount_amount',
      'final_amount',
      'paid_amount',
      'total_profit',
      'profit',
      'amount',
      'balance_adjustment',
      'monthly_limit',
      'current_spent',
      'unit_price',
      'total_price',
      'discount_value',
      'min_amount',
    ]) {
      if (out.containsKey(numKey) && out[numKey] != null) {
        final parsed = double.tryParse(out[numKey].toString());
        if (parsed != null) out[numKey] = parsed;
      }
    }
    return out;
  }
}
