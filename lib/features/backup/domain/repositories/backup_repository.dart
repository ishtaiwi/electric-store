abstract class BackupRepository {
  Future<String> createBackup([String? destinationPath]);
  Future<bool> restoreBackup(String backupPath);
  Future<List<Map<String, dynamic>>> listBackups(String directory);
  Future<String> getDatabasePath();
  Future<String> getBackupDirectory();
}
