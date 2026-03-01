import '../../../../core/database/database_helper.dart';
import '../../../../core/services/security_service.dart';
import '../../../../core/services/audit_logger_service.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final DatabaseHelper _databaseHelper;
  final SecurityService _securityService = SecurityService();
  final AuditLoggerService _auditLogger = AuditLoggerService();

  AuthRepositoryImpl(this._databaseHelper);

  @override
  Future<User?> login(String username, String password) async {
    final db = await _databaseHelper.database;
    
    // First, get user by username
    final result = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );
    
    if (result.isEmpty) {
      // Log failed login attempt
      _auditLogger.log(
        action: AuditAction.loginFailed,
        entityType: 'user',
        details: 'Username not found: $username',
      );
      return null;
    }
    
    final userData = result.first;
    final storedPassword = userData['password'] as String;
    final hashedInput = _securityService.hashPassword(password);
    
    // Check if password matches (hashed)
    bool passwordMatch = storedPassword == hashedInput;
    
    // Fallback: Check if it's a legacy plain text password
    // This allows migration from old plain text to hashed passwords
    if (!passwordMatch && storedPassword == password) {
      passwordMatch = true;
      // Upgrade to hashed password
      await db.update(
        'users',
        {'password': hashedInput},
        where: 'id = ?',
        whereArgs: [userData['id']],
      );
    }
    
    if (!passwordMatch) {
      _auditLogger.log(
        action: AuditAction.loginFailed,
        entityType: 'user',
        entityId: userData['id'] as int?,
        entityName: username,
        details: 'Invalid password',
      );
      return null;
    }
    
    final user = User.fromMap(userData);
    
    // Set current user for audit logging
    _auditLogger.setCurrentUser(user.id, user.username);
    
    // Log successful login
    _auditLogger.log(
      action: AuditAction.login,
      entityType: 'user',
      entityId: user.id,
      entityName: user.username,
    );
    
    return user;
  }

  @override
  Future<List<User>> getAllUsers() async {
    final db = await _databaseHelper.database;
    final result = await db.query('users', orderBy: 'id ASC');
    return result.map((map) => User.fromMap(map)).toList();
  }

  @override
  Future<User?> getUserById(int id) async {
    final db = await _databaseHelper.database;
    final result = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    return User.fromMap(result.first);
  }

  @override
  Future<int> createUser(User user) async {
    final db = await _databaseHelper.database;
    
    // Hash the password before storing
    final hashedPassword = _securityService.hashPassword(user.password);
    final userMap = user.toMap();
    userMap['password'] = hashedPassword;
    
    final id = await db.insert('users', userMap);
    
    // Log user creation
    _auditLogger.log(
      action: AuditAction.userCreated,
      entityType: 'user',
      entityId: id,
      entityName: user.username,
      details: 'Role: ${user.role}',
    );
    
    return id;
  }

  @override
  Future<int> updateUser(User user) async {
    final db = await _databaseHelper.database;
    return await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  @override
  Future<int> deleteUser(int id) async {
    final db = await _databaseHelper.database;
    
    // Get user info for audit log
    final userResult = await db.query('users', where: 'id = ?', whereArgs: [id]);
    final userName = userResult.isNotEmpty ? userResult.first['username'] as String? : null;
    
    final result = await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (result > 0) {
      _auditLogger.log(
        action: AuditAction.userDeleted,
        entityType: 'user',
        entityId: id,
        entityName: userName,
      );
    }
    
    return result;
  }

  @override
  Future<bool> changePassword(int userId, String oldPassword, String newPassword) async {
    final db = await _databaseHelper.database;
    
    // Get user
    final userResult = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
    );
    
    if (userResult.isEmpty) return false;
    
    final storedPassword = userResult.first['password'] as String;
    final hashedOldPassword = _securityService.hashPassword(oldPassword);
    
    // Verify old password (check both hashed and plain text for migration)
    bool oldPasswordMatch = storedPassword == hashedOldPassword || storedPassword == oldPassword;
    
    if (!oldPasswordMatch) {
      _auditLogger.log(
        action: AuditAction.passwordChanged,
        entityType: 'user',
        entityId: userId,
        details: 'Failed - incorrect old password',
      );
      return false;
    }

    // Hash new password
    final hashedNewPassword = _securityService.hashPassword(newPassword);
    
    await db.update(
      'users',
      {'password': hashedNewPassword},
      where: 'id = ?',
      whereArgs: [userId],
    );
    
    _auditLogger.log(
      action: AuditAction.passwordChanged,
      entityType: 'user',
      entityId: userId,
      details: 'Password changed successfully',
    );
    
    return true;
  }

  /// Logout - clear audit logger user
  void logout() {
    _auditLogger.log(
      action: AuditAction.logout,
      entityType: 'user',
      entityId: _auditLogger.hashCode, // Current user
    );
    _auditLogger.clearCurrentUser();
  }
}
