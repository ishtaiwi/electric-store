import 'package:equatable/equatable.dart';

class User extends Equatable {
  final int? id;
  final String username;
  final String password;
  final String role;
  final String? fullName;
  final DateTime? createdDate;

  const User({
    this.id,
    required this.username,
    required this.password,
    required this.role,
    this.fullName,
    this.createdDate,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int?,
      username: map['username'] as String,
      password: map['password'] as String,
      role: map['role'] as String,
      fullName: map['full_name'] as String?,
      createdDate: map['created_date'] != null
          ? DateTime.parse(map['created_date'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'username': username,
      'password': password,
      'role': role,
      'full_name': fullName,
    };
  }

  User copyWith({
    int? id,
    String? username,
    String? password,
    String? role,
    String? fullName,
    DateTime? createdDate,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      role: role ?? this.role,
      fullName: fullName ?? this.fullName,
      createdDate: createdDate ?? this.createdDate,
    );
  }

  bool get isAdmin => role == 'admin';
  bool get isManager => role == 'manager' || role == 'admin';
  bool get isCashier => role == 'cashier';

  @override
  List<Object?> get props => [id, username, password, role, fullName, createdDate];
}
