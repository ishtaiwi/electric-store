import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';

/// Audit action types for logging
enum AuditAction {
  // Auth actions
  login('LOGIN'),
  logout('LOGOUT'),
  loginFailed('LOGIN_FAILED'),
  passwordChanged('PASSWORD_CHANGED'),
  userCreated('USER_CREATED'),
  userDeleted('USER_DELETED'),
  
  // Data actions
  create('CREATE'),
  update('UPDATE'),
  delete('DELETE'),
  
  // Specific actions
  invoiceCreated('INVOICE_CREATED'),
  invoiceUpdated('INVOICE_UPDATED'),
  invoiceDeleted('INVOICE_DELETED'),
  paymentRecorded('PAYMENT_RECORDED'),
  productCreated('PRODUCT_CREATED'),
  productUpdated('PRODUCT_UPDATED'),
  productDeleted('PRODUCT_DELETED'),
  customerCreated('CUSTOMER_CREATED'),
  customerUpdated('CUSTOMER_UPDATED'),
  customerDeleted('CUSTOMER_DELETED'),
  expenseCreated('EXPENSE_CREATED'),
  expenseUpdated('EXPENSE_UPDATED'),
  expenseDeleted('EXPENSE_DELETED'),
  supplierCreated('SUPPLIER_CREATED'),
  supplierUpdated('SUPPLIER_UPDATED'),
  supplierDeleted('SUPPLIER_DELETED'),
  supplierInvoiceCreated('SUPPLIER_INVOICE_CREATED'),
  supplierInvoiceUpdated('SUPPLIER_INVOICE_UPDATED'),
  supplierInvoiceDeleted('SUPPLIER_INVOICE_DELETED'),
  supplierPaymentRecorded('SUPPLIER_PAYMENT_RECORDED'),
  customerPaymentRecorded('CUSTOMER_PAYMENT_RECORDED'),
  customerPaymentDeleted('CUSTOMER_PAYMENT_DELETED'),
  backupCreated('BACKUP_CREATED'),
  backupRestored('BACKUP_RESTORED'),
  settingsChanged('SETTINGS_CHANGED'),
  stockAdjusted('STOCK_ADJUSTED'),
  
  // System actions
  systemStart('SYSTEM_START'),
  systemError('SYSTEM_ERROR'),
  databaseError('DATABASE_ERROR');

  final String value;
  const AuditAction(this.value);
}

/// Audit log entry model
class AuditLogEntry {
  final int? id;
  final String action;
  final String entityType;
  final int? entityId;
  final String? entityName;
  final int? userId;
  final String? userName;
  final String? oldValue;
  final String? newValue;
  final String? details;
  final String? ipAddress;
  final DateTime timestamp;

  AuditLogEntry({
    this.id,
    required this.action,
    required this.entityType,
    this.entityId,
    this.entityName,
    this.userId,
    this.userName,
    this.oldValue,
    this.newValue,
    this.details,
    this.ipAddress,
    required this.timestamp,
  });

  factory AuditLogEntry.fromMap(Map<String, dynamic> map) {
    return AuditLogEntry(
      id: map['id'] as int?,
      action: map['action'] as String,
      entityType: map['entity_type'] as String,
      entityId: map['entity_id'] as int?,
      entityName: map['entity_name'] as String?,
      userId: map['user_id'] as int?,
      userName: map['user_name'] as String?,
      oldValue: map['old_value'] as String?,
      newValue: map['new_value'] as String?,
      details: map['details'] as String?,
      ipAddress: map['ip_address'] as String?,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'action': action,
      'entity_type': entityType,
      'entity_id': entityId,
      'entity_name': entityName,
      'user_id': userId,
      'user_name': userName,
      'old_value': oldValue,
      'new_value': newValue,
      'details': details,
      'ip_address': ipAddress,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Audit Logger Service for tracking all system activities
/// Provides auditability and compliance support
class AuditLoggerService {
  static final AuditLoggerService _instance = AuditLoggerService._internal();
  factory AuditLoggerService() => _instance;
  AuditLoggerService._internal();

  DatabaseHelper? _databaseHelper;
  int? _currentUserId;
  String? _currentUserName;

  /// Initialize the audit logger with database helper
  void initialize(DatabaseHelper databaseHelper) {
    _databaseHelper = databaseHelper;
    _ensureAuditTableExists();
  }

  /// Set the current user for audit logging
  void setCurrentUser(int? userId, String? userName) {
    _currentUserId = userId;
    _currentUserName = userName;
  }

  /// Clear current user (on logout)
  void clearCurrentUser() {
    _currentUserId = null;
    _currentUserName = null;
  }

  /// Ensure the audit_logs table exists
  Future<void> _ensureAuditTableExists() async {
    if (_databaseHelper == null) return;
    
    try {
      final db = await _databaseHelper!.database;
      await db.execute('''
        CREATE TABLE IF NOT EXISTS audit_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          action TEXT NOT NULL,
          entity_type TEXT NOT NULL,
          entity_id INTEGER,
          entity_name TEXT,
          user_id INTEGER,
          user_name TEXT,
          old_value TEXT,
          new_value TEXT,
          details TEXT,
          ip_address TEXT,
          timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_audit_logs_timestamp ON audit_logs(timestamp)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs(entity_type, entity_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON audit_logs(user_id)');
    } catch (e) {
      debugPrint('Error creating audit_logs table: $e');
    }
  }

  /// Log an audit entry
  Future<void> log({
    required AuditAction action,
    required String entityType,
    int? entityId,
    String? entityName,
    String? oldValue,
    String? newValue,
    String? details,
  }) async {
    if (_databaseHelper == null) {
      debugPrint('AuditLogger: Database not initialized');
      return;
    }

    try {
      final entry = AuditLogEntry(
        action: action.value,
        entityType: entityType,
        entityId: entityId,
        entityName: entityName,
        userId: _currentUserId,
        userName: _currentUserName,
        oldValue: oldValue,
        newValue: newValue,
        details: details,
        timestamp: DateTime.now(),
      );

      final db = await _databaseHelper!.database;
      await db.insert('audit_logs', entry.toMap());
      
      // Also log to console in debug mode
      debugPrint('AUDIT: ${action.value} - $entityType ${entityId ?? ''} by ${_currentUserName ?? 'System'}');
    } catch (e) {
      debugPrint('Error logging audit entry: $e');
    }
  }

  /// Get audit logs with optional filters
  Future<List<AuditLogEntry>> getLogs({
    AuditAction? action,
    String? entityType,
    int? entityId,
    int? userId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
    int offset = 0,
  }) async {
    if (_databaseHelper == null) return [];

    try {
      final db = await _databaseHelper!.database;
      
      final whereConditions = <String>[];
      final whereArgs = <dynamic>[];

      if (action != null) {
        whereConditions.add('action = ?');
        whereArgs.add(action.value);
      }
      if (entityType != null) {
        whereConditions.add('entity_type = ?');
        whereArgs.add(entityType);
      }
      if (entityId != null) {
        whereConditions.add('entity_id = ?');
        whereArgs.add(entityId);
      }
      if (userId != null) {
        whereConditions.add('user_id = ?');
        whereArgs.add(userId);
      }
      if (startDate != null) {
        whereConditions.add('timestamp >= ?');
        whereArgs.add(startDate.toIso8601String());
      }
      if (endDate != null) {
        whereConditions.add('timestamp <= ?');
        whereArgs.add(endDate.toIso8601String());
      }

      final whereClause = whereConditions.isEmpty 
          ? null 
          : whereConditions.join(' AND ');

      final result = await db.query(
        'audit_logs',
        where: whereClause,
        whereArgs: whereArgs.isEmpty ? null : whereArgs,
        orderBy: 'timestamp DESC',
        limit: limit,
        offset: offset,
      );

      return result.map((map) => AuditLogEntry.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error getting audit logs: $e');
      return [];
    }
  }

  /// Get audit log count for pagination
  Future<int> getLogCount({
    AuditAction? action,
    String? entityType,
    int? userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (_databaseHelper == null) return 0;

    try {
      final db = await _databaseHelper!.database;
      
      final whereConditions = <String>[];
      final whereArgs = <dynamic>[];

      if (action != null) {
        whereConditions.add('action = ?');
        whereArgs.add(action.value);
      }
      if (entityType != null) {
        whereConditions.add('entity_type = ?');
        whereArgs.add(entityType);
      }
      if (userId != null) {
        whereConditions.add('user_id = ?');
        whereArgs.add(userId);
      }
      if (startDate != null) {
        whereConditions.add('timestamp >= ?');
        whereArgs.add(startDate.toIso8601String());
      }
      if (endDate != null) {
        whereConditions.add('timestamp <= ?');
        whereArgs.add(endDate.toIso8601String());
      }

      String query = 'SELECT COUNT(*) as count FROM audit_logs';
      if (whereConditions.isNotEmpty) {
        query += ' WHERE ${whereConditions.join(' AND ')}';
      }

      final result = await db.rawQuery(query, whereArgs);
      return (result.first['count'] as int?) ?? 0;
    } catch (e) {
      debugPrint('Error getting audit log count: $e');
      return 0;
    }
  }

  /// Clean up old audit logs (for maintenance)
  Future<int> cleanOldLogs({required int daysToKeep}) async {
    if (_databaseHelper == null) return 0;

    try {
      final db = await _databaseHelper!.database;
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
      
      return await db.delete(
        'audit_logs',
        where: 'timestamp < ?',
        whereArgs: [cutoffDate.toIso8601String()],
      );
    } catch (e) {
      debugPrint('Error cleaning old audit logs: $e');
      return 0;
    }
  }

  /// Export audit logs to a list of maps (for backup/export)
  Future<List<Map<String, dynamic>>> exportLogs({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final logs = await getLogs(
      startDate: startDate,
      endDate: endDate,
      limit: 100000, // Export all within range
    );
    return logs.map((log) => log.toMap()).toList();
  }
}
