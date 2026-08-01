import 'package:equatable/equatable.dart';

class Product extends Equatable {
  final int? id;
  final String name;
  final String? barcode;
  final int quantity;
  final double price;
  final double costPrice;
  final String? note;
  /// Brand / make (النوع) e.g. Lieber, Nesco, Givz
  final String? brand;
  /// Product class (الصنف) e.g. lamps, LED rope, outlets
  final String? category;
  final String? supplier;
  final int? supplierId;
  final int minStock;
  /// Public Supabase Storage URL for the product photo
  final String? imageUrl;
  final DateTime? lastUpdated;

  const Product({
    this.id,
    required this.name,
    this.barcode,
    required this.quantity,
    required this.price,
    required this.costPrice,
    this.note,
    this.brand,
    this.category,
    this.supplier,
    this.supplierId,
    this.minStock = 5,
    this.imageUrl,
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
      brand: map['brand'] as String?,
      category: map['category'] as String?,
      supplier: map['supplier'] as String?,
      supplierId: map['supplier_id'] as int?,
      minStock: map['min_stock'] as int? ?? 5,
      imageUrl: map['image_url'] as String?,
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
      'brand': brand,
      'category': category,
      'supplier': supplier,
      'supplier_id': supplierId,
      'min_stock': minStock,
      'image_url': imageUrl,
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
    String? brand,
    String? category,
    String? supplier,
    int? supplierId,
    int? minStock,
    String? imageUrl,
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
      brand: brand ?? this.brand,
      category: category ?? this.category,
      supplier: supplier ?? this.supplier,
      supplierId: supplierId ?? this.supplierId,
      minStock: minStock ?? this.minStock,
      imageUrl: imageUrl ?? this.imageUrl,
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
        brand,
        category,
        supplier,
        supplierId,
        minStock,
        imageUrl,
        lastUpdated,
      ];
}
