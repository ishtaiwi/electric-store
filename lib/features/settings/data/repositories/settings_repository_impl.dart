import '../../../../core/database/database_helper.dart';
import '../../domain/repositories/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final DatabaseHelper _databaseHelper;

  SettingsRepositoryImpl(this._databaseHelper);

  @override
  Future<Map<String, String>> getAllSettings() async {
    final db = await _databaseHelper.database;
    final result = await db.query('store_settings');
    
    final Map<String, String> settings = {};
    for (final row in result) {
      settings[row['setting_key'] as String] = row['setting_value'] as String;
    }
    return settings;
  }

  @override
  Future<String?> getSetting(String key) async {
    final db = await _databaseHelper.database;
    final result = await db.query(
      'store_settings',
      where: 'setting_key = ?',
      whereArgs: [key],
    );
    
    if (result.isEmpty) return null;
    return result.first['setting_value'] as String?;
  }

  @override
  Future<void> setSetting(String key, String value) async {
    final db = await _databaseHelper.database;
    
    // Try to update first
    final updated = await db.update(
      'store_settings',
      {'setting_value': value, 'updated_at': DateTime.now().toIso8601String()},
      where: 'setting_key = ?',
      whereArgs: [key],
    );
    
    // If not updated, insert new
    if (updated == 0) {
      await db.insert('store_settings', {
        'setting_key': key,
        'setting_value': value,
      });
    }
  }

  @override
  Future<void> deleteSettings(String key) async {
    final db = await _databaseHelper.database;
    await db.delete(
      'store_settings',
      where: 'setting_key = ?',
      whereArgs: [key],
    );
  }

  @override
  Future<Map<String, dynamic>> getSettings() async {
    final stringSettings = await getAllSettings();
    return {
      'store_name': stringSettings['store_name'] ?? 'Electrical Store',
      'address': stringSettings['address'] ?? '',
      'phone': stringSettings['phone'] ?? '',
      'email': stringSettings['email'] ?? '',
      'tax_rate': double.tryParse(stringSettings['tax_rate'] ?? '0') ?? 0,
      'currency': stringSettings['currency'] ?? 'USD',
    };
  }

  @override
  Future<void> updateSettings(Map<String, dynamic> settings) async {
    for (final entry in settings.entries) {
      await setSetting(entry.key, entry.value.toString());
    }
  }
}
