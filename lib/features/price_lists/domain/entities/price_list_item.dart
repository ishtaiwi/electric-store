import 'package:equatable/equatable.dart';

class PriceListItem extends Equatable {
  final int? id;
  final int? priceListId;
  final int? productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String? notes;

  const PriceListItem({
    this.id,
    this.priceListId,
    this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.notes,
  });

  factory PriceListItem.fromMap(Map<String, dynamic> map) {
    return PriceListItem(
      id: map['id'] as int?,
      priceListId: map['price_list_id'] as int?,
      productId: map['product_id'] as int?,
      productName: (map['product_name'] as String?) ?? 'Unknown Product',
      quantity: map['quantity'] as int,
      unitPrice: (map['unit_price'] as num).toDouble(),
      totalPrice: (map['total_price'] as num).toDouble(),
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'price_list_id': priceListId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
      'notes': notes,
    };
  }

  PriceListItem copyWith({
    int? id,
    int? priceListId,
    int? productId,
    String? productName,
    int? quantity,
    double? unitPrice,
    double? totalPrice,
    String? notes,
  }) {
    return PriceListItem(
      id: id ?? this.id,
      priceListId: priceListId ?? this.priceListId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      notes: notes ?? this.notes,
    );
  }

  @override
  List<Object?> get props => [
        id,
        priceListId,
        productId,
        productName,
        quantity,
        unitPrice,
        totalPrice,
        notes,
      ];
}
