import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import '../../../../core/database/database_helper.dart';
import '../../domain/repositories/backup_repository.dart';

class BackupRepositoryImpl implements BackupRepository {
  final DatabaseHelper _databaseHelper;

  BackupRepositoryImpl(this._databaseHelper);

  @override
  Future<String> getBackupDirectory() async {
    final dbPath = await _databaseHelper.getDatabasePath();
    final dbDir = path.dirname(dbPath);
    final backupDir = path.join(dbDir, 'backups');
    
    final dir = Directory(backupDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    return backupDir;
  }

  @override
  Future<String> createBackup([String? destinationPath]) async {
    final dbPath = await _databaseHelper.getDatabasePath();
    final db = await _databaseHelper.database;
    
    // Use provided destination or default backup directory
    final destPath = destinationPath ?? await getBackupDirectory();
    
    // Close database connections to ensure data integrity
    await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
    
    // Create backup filename with timestamp
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final backupFileName = 'backup_$timestamp.db';
    final backupPath = path.join(destPath, backupFileName);

    // Ensure destination directory exists
    final destDir = Directory(destPath);
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }

    // Copy database file
    final sourceFile = File(dbPath);
    if (!await sourceFile.exists()) {
      throw Exception('Database file not found at: $dbPath');
    }
    await sourceFile.copy(backupPath);

    // Also copy WAL and SHM files if they exist
    final walFile = File('$dbPath-wal');
    if (await walFile.exists()) {
      await walFile.copy('$backupPath-wal');
    }

    final shmFile = File('$dbPath-shm');
    if (await shmFile.exists()) {
      await shmFile.copy('$backupPath-shm');
    }

    return backupPath;
  }

  @override
  Future<bool> restoreBackup(String backupPath) async {
    try {
      final backupFile = File(backupPath);
      if (!await backupFile.exists()) {
        return false;
      }

      final dbPath = await _databaseHelper.getDatabasePath();
      
      // Create a safety backup before overwriting
      final safetyBackupPath = '$dbPath.safety_backup';
      final currentDb = File(dbPath);
      if (await currentDb.exists()) {
        await currentDb.copy(safetyBackupPath);
      }

      try {
        // Close current database
        await _databaseHelper.close();

        // Remove current database files
        if (await currentDb.exists()) {
          await currentDb.delete();
        }

        final walFile = File('$dbPath-wal');
        if (await walFile.exists()) {
          await walFile.delete();
        }

        final shmFile = File('$dbPath-shm');
        if (await shmFile.exists()) {
          await shmFile.delete();
        }

        // Copy backup to database location
        await backupFile.copy(dbPath);

        // Copy WAL file if exists
        final backupWal = File('$backupPath-wal');
        if (await backupWal.exists()) {
          await backupWal.copy('$dbPath-wal');
        }

        // Success — remove safety backup
        final safetyFile = File(safetyBackupPath);
        if (await safetyFile.exists()) {
          await safetyFile.delete();
        }

        return true;
      } catch (e) {
        // Restore from safety backup if copy failed
        final safetyFile = File(safetyBackupPath);
        if (await safetyFile.exists()) {
          try {
            await safetyFile.copy(dbPath);
          } catch (_) {
            // Last resort: safety backup copy also failed
          }
        }
        rethrow;
      }
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listBackups(String directory) async {
    final List<Map<String, dynamic>> backups = [];
    final dir = Directory(directory);
    
    if (!await dir.exists()) {
      return backups;
    }

    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.db') && path.basename(entity.path).startsWith('backup_')) {
        final stat = await entity.stat();
        backups.add({
          'path': entity.path,
          'name': path.basename(entity.path),
          'size': stat.size,
          'created': stat.modified,
        });
      }
    }

    // Sort by creation date, newest first
    backups.sort((a, b) => (b['created'] as DateTime).compareTo(a['created'] as DateTime));
    
    return backups;
  }

  @override
  Future<String> getDatabasePath() async {
    return await _databaseHelper.getDatabasePath();
  }
}
