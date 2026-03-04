import 'package:equatable/equatable.dart';

class Product extends Equatable {
  final int? id;
  final String name;
  final String? barcode;
  final int quantity;
  final double price;
  final double costPrice;
  final String? note;
  final String? supplier;
  final int? supplierId;
  final int minStock;
  final DateTime? lastUpdated;

  const Product({
    this.id,
    required this.name,
    this.barcode,
    required this.quantity,
    required this.price,
    required this.costPrice,
    this.note,
    this.supplier,
    this.supplierId,
    this.minStock = 5,
    this.lastUpdated,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      name: map['name'] as String,
      barcode: map['barcode'] as String?,
      quantity: map['quantity'] as int,
      price: (map['price'] as num).toDouble(),
      costPrice: (map['cost_price'] as num? ?? 0).toDouble(),
      note: map['note'] as String?,
      supplier: map['supplier'] as String?,
      supplierId: map['supplier_id'] as int?,
      minStock: map['min_stock'] as int? ?? 5,
      lastUpdated: map['last_updated'] != null
          ? DateTime.parse(map['last_updated'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'barcode': barcode,
      'quantity': quantity,
      'price': price,
      'cost_price': costPrice,
      'note': note,
      'supplier': supplier,
      'supplier_id': supplierId,
      'min_stock': minStock,
    };
  }

  Product copyWith({
    int? id,
    String? name,
    String? barcode,
    int? quantity,
    double? price,
    double? costPrice,
    String? note,
    String? supplier,
    int? supplierId,
    int? minStock,
    DateTime? lastUpdated,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      note: note ?? this.note,
      supplier: supplier ?? this.supplier,
      supplierId: supplierId ?? this.supplierId,
      minStock: minStock ?? this.minStock,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  double get profit => price - costPrice;
  double get profitMargin => costPrice > 0 ? ((price - costPrice) / costPrice) * 100 : 0;
  bool get isLowStock => quantity <= minStock;
  bool get isOutOfStock => quantity <= 0;

  @override
  List<Object?> get props => [
        id,
        name,
        barcode,
        quantity,
        price,
        costPrice,
        note,
        supplier,
        supplierId,
        minStock,
        lastUpdated,
      ];
}
