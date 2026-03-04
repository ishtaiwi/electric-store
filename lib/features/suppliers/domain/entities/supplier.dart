import 'package:equatable/equatable.dart';

class Supplier extends Equatable {
  final int? id;
  final String name;
  final String? phone;
  final String? address;
  final String? note;
  final DateTime? createdDate;

  const Supplier({
    this.id,
    required this.name,
    this.phone,
    this.address,
    this.note,
    this.createdDate,
  });

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'] as int?,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      note: map['note'] as String?,
      createdDate: map['created_date'] != null
          ? DateTime.parse(map['created_date'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'note': note,
    };
  }

  Supplier copyWith({
    int? id,
    String? name,
    String? phone,
    String? address,
    String? note,
    DateTime? createdDate,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      note: note ?? this.note,
      createdDate: createdDate ?? this.createdDate,
    );
  }

  @override
  List<Object?> get props => [id, name, phone, address, note, createdDate];
}
