import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_secrets.dart';
import '../database/database_helper.dart';
import 'supabase_config.dart';

/// Initializes and exposes the Supabase client for hybrid sync.
/// URL / anon key come from gitignored [SupabaseSecrets] (generated from `.env`).
class SupabaseClientService {
  SupabaseClientService(this._databaseHelper);

  final DatabaseHelper _databaseHelper;
  bool _initialized = false;
  String? _url;

  bool get isInitialized => _initialized;
  String? get url => _url;

  SupabaseClient? get client {
    if (!_initialized) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>> _readSettings() async {
    final db = await _databaseHelper.database;
    final rows = await db.query('store_settings');
    return {
      for (final row in rows)
        row['setting_key'] as String: row['setting_value'] as String,
    };
  }

  Future<void> _writeSetting(String key, String value) async {
    Future<void> write() async {
      final db = await _databaseHelper.database;
      final updated = await db.update(
        'store_settings',
        {
          'setting_value': value,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'setting_key = ?',
        whereArgs: [key],
      );
      if (updated == 0) {
        await db.insert('store_settings', {
          'setting_key': key,
          'setting_value': value,
        });
      }
    }

    if (localOnlySettingKeys.contains(key)) {
      await _databaseHelper.withoutSyncNotify(write);
    } else {
      await write();
    }
  }

  /// Initialize using embedded secrets from `.env` (never shown in UI).
  Future<bool> initializeFromSettings() async {
    return initialize(
      url: SupabaseSecrets.url,
      anonKey: SupabaseSecrets.anonKey,
    );
  }

  Future<bool> initialize({
    required String url,
    required String anonKey,
  }) async {
    final cleanUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    final cleanKey = anonKey.trim();
    if (cleanUrl.isEmpty ||
        cleanKey.isEmpty ||
        cleanUrl.contains('YOUR_PROJECT') ||
        cleanKey.contains('YOUR_ANON')) {
      _initialized = false;
      return false;
    }

    try {
      if (_initialized && _url == cleanUrl) {
        return true;
      }

      await Supabase.initialize(
        url: cleanUrl,
        publishableKey: cleanKey,
      );
      _url = cleanUrl;
      _initialized = true;
      debugPrint('Supabase initialized');
      return true;
    } catch (e) {
      try {
        final _ = Supabase.instance.client;
        _url = cleanUrl;
        _initialized = true;
        debugPrint('Supabase already initialized, reusing client');
        return true;
      } catch (_) {
        debugPrint('Supabase init error: $e');
        _initialized = false;
        return false;
      }
    }
  }

  /// Credentials are embedded; this only keeps sync flags in store_settings.
  Future<void> saveCredentials({
    required String url,
    required String anonKey,
  }) async {
    // Intentionally do not persist URL/anon key to the database.
  }

  Future<bool> getSyncEnabled() async {
    final mode = await getSyncMode();
    return mode != DesktopSyncMode.off;
  }

  Future<void> setSyncEnabled(bool enabled) async {
    await _writeSetting(
      SupabaseConfigKeys.syncEnabled,
      enabled ? '1' : '0',
    );
  }

  Future<bool> getAutoSync() async {
    return (await getSyncMode()) == DesktopSyncMode.upload;
  }

  Future<void> setAutoSync(bool enabled) async {
    await _writeSetting(
      SupabaseConfigKeys.autoSync,
      enabled ? '1' : '0',
    );
  }

  /// Preferred API: upload (main) / download (secondary) / off.
  /// Default is [DesktopSyncMode.off] until the user enables a mode.
  /// Once saved, the choice persists across app restarts.
  Future<DesktopSyncMode> getSyncMode() async {
    final settings = await _readSettings();
    final raw = settings[SupabaseConfigKeys.syncMode];
    if (raw != null && raw.trim().isNotEmpty) {
      return DesktopSyncModeX.parse(raw);
    }
    // No saved choice yet → both switches stay off.
    return DesktopSyncMode.off;
  }

  Future<void> setSyncMode(DesktopSyncMode mode) async {
    await _writeSetting(SupabaseConfigKeys.syncMode, mode.storageValue);
    await setSyncEnabled(mode != DesktopSyncMode.off);
    await setAutoSync(mode == DesktopSyncMode.upload);
  }

  Future<String?> getLastSyncAt() async {
    final settings = await _readSettings();
    return settings[SupabaseConfigKeys.lastSyncAt];
  }

  Future<void> setLastSyncAt(DateTime time) async {
    await _writeSetting(
      SupabaseConfigKeys.lastSyncAt,
      time.toIso8601String(),
    );
  }

  Future<Map<String, String>> getStoredCredentials() async {
    return {
      'url': SupabaseSecrets.url,
      'anonKey': SupabaseSecrets.anonKey,
    };
  }

  Future<bool> testConnection() async {
    final c = client;
    if (c == null) return false;
    try {
      await c.from('store_settings').select('id').limit(1);
      return true;
    } catch (e) {
      debugPrint('Supabase connection test failed: $e');
      return false;
    }
  }
}
