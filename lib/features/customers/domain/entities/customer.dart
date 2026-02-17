import 'package:equatable/equatable.dart';

class Customer extends Equatable {
  final int? id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final DateTime? createdDate;
  final double balance;
  final double balanceAdjustment;

  const Customer({
    this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.createdDate,
    this.balance = 0,
    this.balanceAdjustment = 0,
  });

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as int?,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      address: map['address'] as String?,
      createdDate: map['created_date'] != null
          ? DateTime.parse(map['created_date'] as String)
          : null,
      balance: (map['balance'] as num?)?.toDouble() ?? 0,
      balanceAdjustment: (map['balance_adjustment'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'balance_adjustment': balanceAdjustment,
    };
  }

  Customer copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    DateTime? createdDate,
    double? balance,
    double? balanceAdjustment,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      createdDate: createdDate ?? this.createdDate,
      balance: balance ?? this.balance,
      balanceAdjustment: balanceAdjustment ?? this.balanceAdjustment,
    );
  }

  bool get hasDebt => balance > 0;
  bool get hasCredit => balance < 0;

  @override
  List<Object?> get props => [id, name, phone, email, address, createdDate, balance, balanceAdjustment];
}
