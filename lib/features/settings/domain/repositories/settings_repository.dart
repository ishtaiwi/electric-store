abstract class SettingsRepository {
  Future<Map<String, String>> getAllSettings();
  Future<String?> getSetting(String key);
  Future<void> setSetting(String key, String value);
  Future<void> deleteSettings(String key);
  
  // Convenience methods for store settings
  Future<Map<String, dynamic>> getSettings();
  Future<void> updateSettings(Map<String, dynamic> settings);
}
