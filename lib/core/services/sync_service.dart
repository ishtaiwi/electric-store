import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
/// **Upload mode (main PC):** auto-push on every local DB change.
/// **Download mode (secondary PC):** auto-pull when cloud data changes.
/// Mobile-only tables are never synced to desktop.
/// Product photos in Supabase Storage are never deleted by sync; `image_url`
/// is preserved when the desktop has no photo.
class SyncService {
  SyncService(this._databaseHelper, this._supabase);

  final DatabaseHelper _databaseHelper;
  final SupabaseClientService _supabase;

  static const int _pageSize = 1000;
  static const _realtimeTables = [
    'products',
    'invoices',
    'sales',
    'customers',
    'customer_payments',
    'suppliers',
    'expenses',
    'users',
  ];

  Timer? _debounceTimer;
  Timer? _periodicTimer;
  bool _pushInFlight = false;
  bool _pushQueued = false;
  bool _pullInFlight = false;
  bool _pullQueued = false;
  RealtimeChannel? _pullChannel;

  /// Called after any local DB write — pushes only in upload mode.
  void scheduleAutoSync({
    Duration delay = const Duration(seconds: 2),
  }) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, () async {
      final mode = await _supabase.getSyncMode();
      if (mode == DesktopSyncMode.upload) {
        unawaited(pushFromDesktop());
      }
      // Download mode reacts to cloud changes (realtime / periodic), not local writes.
    });
  }

  /// Back-compat alias used by older call sites.
  void scheduleDesktopPush({Duration delay = const Duration(seconds: 2)}) {
    scheduleAutoSync(delay: delay);
  }

  /// Start automatic sync for the current mode (upload or download).
  Future<void> applySyncMode() async {
    stopAutomaticSync();
    final mode = await _supabase.getSyncMode();
    switch (mode) {
      case DesktopSyncMode.upload:
        startPeriodicDesktopPush(interval: const Duration(minutes: 5));
        unawaited(pushFromDesktop());
      case DesktopSyncMode.download:
        await _startDownloadListeners();
        startPeriodicDesktopPull(interval: const Duration(minutes: 2));
        // First sync: full replace so secondary gets ALL desktop tables.
        unawaited(pullFromCloud(soft: false));
      case DesktopSyncMode.off:
        break;
    }
  }

  void startPeriodicDesktopPush({
    Duration interval = const Duration(minutes: 5),
  }) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(interval, (_) {
      unawaited(pushFromDesktop());
    });
  }

  void startPeriodicDesktopPull({
    Duration interval = const Duration(minutes: 2),
  }) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(interval, (_) {
      unawaited(pullFromCloud(soft: true));
    });
  }

  void stopPeriodicDesktopPush() => stopAutomaticSync();

  void stopAutomaticSync() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    unawaited(_stopDownloadListeners());
  }

  Future<void> _startDownloadListeners() async {
    await _stopDownloadListeners();
    final client = _supabase.client;
    if (client == null) return;

    var channel = client.channel('desktop-auto-pull');
    for (final table in _realtimeTables) {
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) {
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(seconds: 3), () {
            unawaited(pullFromCloud(soft: true));
          });
        },
      );
    }
    _pullChannel = channel.subscribe();
  }

  Future<void> _stopDownloadListeners() async {
    final channel = _pullChannel;
    _pullChannel = null;
    if (channel == null) return;
    try {
      await _supabase.client?.removeChannel(channel);
    } catch (e) {
      debugPrint('stop download listeners: $e');
    }
  }

  /// Automatic upload (upload mode only).
  Future<SyncResult> pushFromDesktop() async {
    final mode = await _supabase.getSyncMode();
    if (mode != DesktopSyncMode.upload) {
      return const SyncResult(
        success: false,
        message: 'Upload mode is off on this PC.',
      );
    }
    return sync(direction: SyncDirection.push);
  }

  /// Automatic / soft download (download mode only).
  Future<SyncResult> pullFromCloud({bool soft = true}) async {
    final mode = await _supabase.getSyncMode();
    if (mode != DesktopSyncMode.download) {
      return const SyncResult(
        success: false,
        message: 'Download mode is off on this PC.',
      );
    }
    return sync(direction: SyncDirection.pull, softPull: soft);
  }

  /// Manual upload from Settings (works in any mode).
  Future<SyncResult> uploadNow() => sync(direction: SyncDirection.push);

  /// Manual full download from Settings (works in any mode).
  Future<SyncResult> downloadNow() =>
      sync(direction: SyncDirection.pull, softPull: false);

  Future<SyncResult> sync({
    SyncDirection direction = SyncDirection.push,
    bool softPull = false,
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
    if (direction == SyncDirection.pull || direction == SyncDirection.both) {
      if (_pullInFlight) {
        _pullQueued = true;
        return const SyncResult(
          success: true,
          message: 'Pull already running; queued another pass.',
        );
      }
      _pullInFlight = true;
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
        for (final table in supabaseSyncTables) {
          try {
            pushed[table] = await _upsertTable(table);
          } catch (e) {
            errors.add('push $table: $e');
            debugPrint('push $table error: $e');
          }
        }
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
        final preservedMode = await _supabase.getSyncMode();
        final preservedLast = await _supabase.getLastSyncAt();

        await _databaseHelper.withoutSyncNotify(() async {
          final db = await _databaseHelper.database;
          await db.execute('PRAGMA foreign_keys = OFF');
          try {
            if (!softPull) {
              try {
                await _clearLocalTables(restoreForeignKeys: false);
              } catch (e) {
                errors.add('clear local: $e');
              }
            }

            for (final table in supabaseSyncTables) {
              try {
                if (!await _localTableExists(table)) {
                  debugPrint('pull skip $table: missing locally');
                  continue;
                }
                final clearFirst = softPull && softPullReplaceTables.contains(table);
                pulled[table] = await _pullTable(
                  table,
                  clearFirst: clearFirst,
                );
              } catch (e) {
                errors.add('pull $table: $e');
                debugPrint('pull $table error: $e');
              }
            }

            if (softPull) {
              for (final table in supabaseSyncTables.reversed) {
                try {
                  if (!await _localTableExists(table)) continue;
                  await _pruneLocalTable(table);
                } catch (e) {
                  errors.add('prune local $table: $e');
                  debugPrint('prune local $table error: $e');
                }
              }
            }
          } finally {
            await db.execute('PRAGMA foreign_keys = ON');
          }
        });

        await _supabase.setSyncMode(preservedMode);
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
        summary.write('Uploaded $total rows. ');
      }
      if (pulled.isNotEmpty) {
        final total = pulled.values.fold<int>(0, (a, b) => a + b);
        final parts = pulled.entries
            .where((e) => e.value > 0)
            .map((e) => '${e.key}:${e.value}')
            .join(', ');
        summary.write('Downloaded $total rows');
        if (parts.isNotEmpty) {
          summary.write(' ($parts)');
        }
        summary.write('. ');
      }
      if (errors.isNotEmpty) {
        summary.write('${errors.length} error(s): ${errors.take(3).join(' | ')}');
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
          scheduleAutoSync(delay: const Duration(seconds: 2));
        }
      }
      if (direction == SyncDirection.pull || direction == SyncDirection.both) {
        _pullInFlight = false;
        if (_pullQueued) {
          _pullQueued = false;
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(seconds: 2), () {
            unawaited(pullFromCloud(soft: true));
          });
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
      var chunk = rows.sublist(i, end).map(_normalizeRowForRemote).toList();
      if (table == 'products') {
        chunk = await _mergeRemoteProductImages(chunk);
      }
      // store_settings is unique on setting_key; local/cloud ids often differ.
      String onConflict = 'id';
      if (table == 'store_settings') {
        onConflict = 'setting_key';
        chunk = chunk.map((row) {
          final copy = Map<String, dynamic>.from(row)..remove('id');
          return copy;
        }).toList();
      }
      // defaultToNull: false — omitted columns (e.g. image_url) are not forced to null on insert.
      await client.from(table).upsert(
            chunk,
            onConflict: onConflict,
            defaultToNull: false,
          );
      count += chunk.length;
    }
    return count;
  }

  /// Keep Supabase product photos when desktop has no local image_url yet.
  /// Sync never touches Storage (`product-images` bucket) — files stay forever.
  Future<List<Map<String, dynamic>>> _mergeRemoteProductImages(
    List<Map<String, dynamic>> chunk,
  ) async {
    String? cleanedUrl(dynamic value) {
      if (value is! String) return null;
      final t = value.trim();
      return t.isEmpty ? null : t;
    }

    final idsNeedingRemote = <int>[];
    for (final row in chunk) {
      final local = cleanedUrl(row['image_url']);
      if (local != null) {
        row['image_url'] = local;
        continue;
      }
      // Omit empty/null so upsert does not wipe cloud photos.
      row.remove('image_url');
      final id = row['id'];
      if (id != null) idsNeedingRemote.add(int.parse(id.toString()));
    }

    if (idsNeedingRemote.isEmpty) return chunk;

    try {
      final remoteRows = await _supabase.client!
          .from('products')
          .select('id, image_url')
          .inFilter('id', idsNeedingRemote);
      final remoteById = <int, String>{};
      for (final row in List<Map<String, dynamic>>.from(remoteRows as List)) {
        final id = row['id'];
        final url = cleanedUrl(row['image_url']);
        if (id != null && url != null) {
          remoteById[int.parse(id.toString())] = url;
        }
      }
      for (final row in chunk) {
        if (row.containsKey('image_url')) continue;
        final id = row['id'];
        if (id == null) continue;
        final remoteUrl = remoteById[int.parse(id.toString())];
        if (remoteUrl != null) {
          row['image_url'] = remoteUrl;
        }
      }
    } catch (e) {
      // On failure, image_url stays omitted → cloud photo is left unchanged.
      debugPrint('preserve product images failed: $e');
    }
    return chunk;
  }

  /// Delete remote rows whose ids are not present on the desktop DB.
  /// Never deletes files from Supabase Storage (product images stay in bucket).
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

    // Note: product-images Storage files are never deleted here.
    // image_url on surviving products is protected during upsert merge.
    for (var i = 0; i < toDelete.length; i += 100) {
      final end = (i + 100 < toDelete.length) ? i + 100 : toDelete.length;
      final chunk = toDelete.sublist(i, end);
      await client.from(table).delete().inFilter('id', chunk);
    }
    debugPrint('pruned $table: removed ${toDelete.length} remote row(s)');
  }

  /// Soft pull helper: remove local rows that no longer exist in cloud.
  Future<void> _pruneLocalTable(String table) async {
    if (table == 'store_settings') return;

    final client = _supabase.client!;
    final db = await _databaseHelper.database;

    final remoteIds = <int>{};
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

    List<Map<String, Object?>> localRows;
    try {
      localRows = await db.query(table, columns: ['id']);
    } catch (_) {
      return;
    }

    final toDelete = <int>[];
    for (final row in localRows) {
      final id = row['id'];
      if (id == null) continue;
      final localId = int.parse(id.toString());
      if (!remoteIds.contains(localId)) toDelete.add(localId);
    }
    if (toDelete.isEmpty) return;

    for (var i = 0; i < toDelete.length; i += 100) {
      final end = (i + 100 < toDelete.length) ? i + 100 : toDelete.length;
      final chunk = toDelete.sublist(i, end);
      final placeholders = List.filled(chunk.length, '?').join(',');
      await db.delete(
        table,
        where: 'id IN ($placeholders)',
        whereArgs: chunk,
      );
    }
  }

  Future<void> _clearLocalTables({bool restoreForeignKeys = true}) async {
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
      if (restoreForeignKeys) {
        await db.execute('PRAGMA foreign_keys = ON');
      }
    }
  }

  Future<bool> _localTableExists(String table) async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [table],
    );
    return rows.isNotEmpty;
  }

  Future<Set<String>> _localColumnNames(String table) async {
    final db = await _databaseHelper.database;
    final info = await db.rawQuery('PRAGMA table_info($table)');
    return {
      for (final col in info)
        if (col['name'] != null) col['name'] as String,
    };
  }

  Future<int> _pullTable(String table, {bool clearFirst = true}) async {
    final client = _supabase.client!;
    final db = await _databaseHelper.database;
    final localColumns = await _localColumnNames(table);
    if (localColumns.isEmpty) return 0;

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

    var inserted = 0;
    await db.transaction((txn) async {
      if (clearFirst) {
        await txn.delete(table);
      }
      for (final raw in allRows) {
        final row = _normalizeRowForLocal(raw);
        row.removeWhere((key, _) => !localColumns.contains(key));
        if (row.isEmpty) continue;

        if (table == 'store_settings') {
          final key = row['setting_key'] as String?;
          if (key != null && localOnlySettingKeys.contains(key)) {
            continue;
          }
        }

        try {
          await txn.insert(
            table,
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          inserted++;
        } catch (e) {
          // Soft-pull unique conflicts: replace by deleting matching name then insert.
          if (table == 'product_brands' || table == 'product_categories') {
            final name = row['name'];
            if (name != null) {
              await txn.delete(table, where: 'name = ?', whereArgs: [name]);
              await txn.insert(table, row);
              inserted++;
              continue;
            }
          }
          rethrow;
        }
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

    debugPrint('pulled $table: $inserted / ${allRows.length} rows');
    return inserted;
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
    // Also drop empty image_url strings so they never wipe cloud photos.
    final imageUrl = out['image_url'];
    if (imageUrl == null || (imageUrl is String && imageUrl.trim().isEmpty)) {
      out.remove('image_url');
    }
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
