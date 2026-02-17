import '../entities/user.dart';

abstract class AuthRepository {
  Future<User?> login(String username, String password);
  Future<List<User>> getAllUsers();
  Future<User?> getUserById(int id);
  Future<int> createUser(User user);
  Future<int> updateUser(User user);
  Future<int> deleteUser(int id);
  Future<bool> changePassword(int userId, String oldPassword, String newPassword);
}
