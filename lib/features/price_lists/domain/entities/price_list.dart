import 'package:equatable/equatable.dart';
import 'price_list_item.dart';

class PriceList extends Equatable {
  final int? id;
  final String title;
  final int? customerId;
  final String? customerName;
  final String? notes;
  final DateTime? createdDate;
  final DateTime? updatedDate;
  final List<PriceListItem>? items;

  const PriceList({
    this.id,
    required this.title,
    this.customerId,
    this.customerName,
    this.notes,
    this.createdDate,
    this.updatedDate,
    this.items,
  });

  /// Total amount of all items
  double get totalAmount =>
      items?.fold(0.0, (sum, item) => sum! + item.totalPrice) ?? 0.0;

  /// Number of items
  int get itemCount => items?.length ?? 0;

  DateTime get createdAt => createdDate ?? DateTime.now();

  factory PriceList.fromMap(Map<String, dynamic> map) {
    return PriceList(
      id: map['id'] as int?,
      title: map['title'] as String,
      customerId: map['customer_id'] as int?,
      customerName: map['customer_name'] as String?,
      notes: map['notes'] as String?,
      createdDate: map['created_date'] != null
          ? DateTime.parse(map['created_date'] as String)
          : null,
      updatedDate: map['updated_date'] != null
          ? DateTime.parse(map['updated_date'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'customer_id': customerId,
      'notes': notes,
    };
  }

  PriceList copyWith({
    int? id,
    String? title,
    int? customerId,
    String? customerName,
    String? notes,
    DateTime? createdDate,
    DateTime? updatedDate,
    List<PriceListItem>? items,
  }) {
    return PriceList(
      id: id ?? this.id,
      title: title ?? this.title,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      notes: notes ?? this.notes,
      createdDate: createdDate ?? this.createdDate,
      updatedDate: updatedDate ?? this.updatedDate,
      items: items ?? this.items,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        customerId,
        notes,
        createdDate,
        updatedDate,
        items,
      ];
}
