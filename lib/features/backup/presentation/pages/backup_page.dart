import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/localization_service.dart';
import '../../../backup/domain/repositories/backup_repository.dart';
import '../../../../core/di/injection_container.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool _isBackingUp = false;
  bool _isRestoring = false;
  List<Map<String, dynamic>> _backupHistory = [];
  final _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  @override
  void initState() {
    super.initState();
    _loadBackupHistory();
  }

  Future<void> _loadBackupHistory() async {
    // In a real app, you'd load from a backup log file
    // For now, we'll scan the backup directory
    try {
      final repo = sl<BackupRepository>();
      final backupDir = await repo.getBackupDirectory();
      final dir = Directory(backupDir);
      
      if (await dir.exists()) {
        final files = await dir
            .list()
            .where((f) => f.path.endsWith('.zip'))
            .toList();
        
        final history = <Map<String, dynamic>>[];
        for (final file in files) {
          final stat = await (file as File).stat();
          history.add({
            'path': file.path,
            'name': file.path.split(Platform.pathSeparator).last,
            'date': stat.modified,
            'size': stat.size,
          });
        }
        
        history.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
        
        setState(() => _backupHistory = history);
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _createBackup() async {
    setState(() => _isBackingUp = true);
    
    try {
      final repo = sl<BackupRepository>();
      final path = await repo.createBackup();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${LocalizationService().get('backupCreated')} $path'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 5),
          ),
        );
        _loadBackupHistory();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${LocalizationService().get('backupFailed')} $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
    
    if (mounted) {
      setState(() => _isBackingUp = false);
    }
  }

  Future<void> _restoreBackup(String path) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LocalizationService().get('confirmRestore')),
        content: Text(LocalizationService().get('restoreWarning')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(LocalizationService().get('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
            child: Text(LocalizationService().get('restore')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isRestoring = true);

    try {
      final repo = sl<BackupRepository>();
      await repo.restoreBackup(path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LocalizationService().get('backupRestored')),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${LocalizationService().get('restoreFailed')} $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isRestoring = false);
    }
  }

  Future<void> _deleteBackup(String path) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.confirmDelete),
        content: Text(LocalizationService().get('confirmDeleteBackup')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(LocalizationService().get('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(LocalizationService().get('delete')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        _loadBackupHistory();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(LocalizationService().get('backupDeleted')),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${LocalizationService().get('deleteFailed')} $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            LocalizationService().get('backup'),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 24),

          // Backup Actions
          Row(
            children: [
              Expanded(
                child: _ActionCard(
                  icon: Icons.backup,
                  title: LocalizationService().get('createBackup'),
                  description: LocalizationService().get('createBackupDesc'),
                  buttonText: LocalizationService().get('createBackup'),
                  isLoading: _isBackingUp,
                  onPressed: _createBackup,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _ActionCard(
                  icon: Icons.restore,
                  title: LocalizationService().get('restoreFromFile'),
                  description: LocalizationService().get('selectBackupFile'),
                  buttonText: LocalizationService().get('browseFiles'),
                  isLoading: _isRestoring,
                  onPressed: () async {
                    // In a real app, you'd use file_picker here
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(LocalizationService().get('selectBackupHint')),
                      ),
                    );
                  },
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Backup History
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                LocalizationService().get('backupHistory'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadBackupHistory,
                tooltip: LocalizationService().get('refresh'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Backup List
          Expanded(
            child: _backupHistory.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.backup_outlined,
                          size: 64,
                          color: AppColors.textSecondary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          LocalizationService().get('noBackupsFound'),
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          LocalizationService().get('createFirstBackup'),
                          style: TextStyle(
                            color: AppColors.textSecondary.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _backupHistory.length,
                    itemBuilder: (context, index) {
                      final backup = _backupHistory[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.archive,
                              color: AppColors.primary,
                            ),
                          ),
                          title: Text(backup['name'] ?? LocalizationService().get('unknown')),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                _dateFormat.format(backup['date'] as DateTime),
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                _formatFileSize(backup['size'] as int),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.restore),
                                onPressed: _isRestoring
                                    ? null
                                    : () => _restoreBackup(backup['path']),
                                tooltip: LocalizationService().get('restore'),
                                color: AppColors.warning,
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _deleteBackup(backup['path']),
                                tooltip: LocalizationService().get('delete'),
                                color: AppColors.error,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.info.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.info),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LocalizationService().get('backupTips'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.info,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Create regular backups to protect your data. Store backup files in a safe location such as an external drive or cloud storage.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String buttonText;
  final bool isLoading;
  final VoidCallback onPressed;
  final Color color;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.isLoading,
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text(buttonText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
