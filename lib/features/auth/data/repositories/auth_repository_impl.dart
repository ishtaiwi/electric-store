import '../../../../core/database/database_helper.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final DatabaseHelper _databaseHelper;

  AuthRepositoryImpl(this._databaseHelper);

  @override
  Future<User?> login(String username, String password) async {
    final db = await _databaseHelper.database;
    final result = await db.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
    );
    if (result.isEmpty) return null;
    return User.fromMap(result.first);
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
    return await db.insert('users', user.toMap());
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
    return await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<bool> changePassword(int userId, String oldPassword, String newPassword) async {
    final db = await _databaseHelper.database;
    final user = await db.query(
      'users',
      where: 'id = ? AND password = ?',
      whereArgs: [userId, oldPassword],
    );
    if (user.isEmpty) return false;

    await db.update(
      'users',
      {'password': newPassword},
      where: 'id = ?',
      whereArgs: [userId],
    );
    return true;
  }
}
