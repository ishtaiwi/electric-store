import 'package:equatable/equatable.dart';

class SaleItem extends Equatable {
  final int? id;
  final int? productId;
  final String? barcode;
  final String productName;
  final int quantity;
  final double costPrice;
  final double salePrice;
  final double totalAmount;
  final double profit;
  final DateTime? saleDate;
  final int? customerId;
  final double discountAmount;
  final double finalAmount;
  final int? invoiceId;
  final String? note;

  const SaleItem({
    this.id,
    this.productId,
    this.barcode,
    required this.productName,
    required this.quantity,
    required this.costPrice,
    required this.salePrice,
    required this.totalAmount,
    this.profit = 0,
    this.saleDate,
    this.customerId,
    this.discountAmount = 0,
    required this.finalAmount,
    this.invoiceId,
    this.note,
  });

  // Convenience getters for UI
  double get unitPrice => salePrice;
  double get totalPrice => totalAmount;

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'] as int?,
      productId: map['product_id'] as int?,
      barcode: map['barcode'] as String?,
      productName: (map['product_name'] as String?) ?? 'Unknown Product',
      quantity: map['quantity'] as int,
      costPrice: (map['cost_price'] as num).toDouble(),
      salePrice: (map['sale_price'] as num).toDouble(),
      totalAmount: (map['total_amount'] as num).toDouble(),
      profit: (map['profit'] as num?)?.toDouble() ?? 0,
      saleDate: map['sale_date'] != null
          ? DateTime.parse(map['sale_date'] as String)
          : null,
      customerId: map['customer_id'] as int?,
      discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0,
      finalAmount: (map['final_amount'] as num).toDouble(),
      invoiceId: map['invoice_id'] as int?,
      note: map['note'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'product_id': productId,
      'barcode': barcode,
      'product_name': productName,
      'quantity': quantity,
      'cost_price': costPrice,
      'sale_price': salePrice,
      'total_amount': totalAmount,
      'profit': profit,
      'customer_id': customerId,
      'discount_amount': discountAmount,
      'final_amount': finalAmount,
      'invoice_id': invoiceId,
      if (note != null) 'note': note,
    };
  }

  SaleItem copyWith({
    int? id,
    int? productId,
    String? barcode,
    String? productName,
    int? quantity,
    double? costPrice,
    double? salePrice,
    double? totalAmount,
    double? profit,
    DateTime? saleDate,
    int? customerId,
    double? discountAmount,
    double? finalAmount,
    int? invoiceId,
    String? note,
    bool clearNote = false,
  }) {
    return SaleItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      barcode: barcode ?? this.barcode,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      costPrice: costPrice ?? this.costPrice,
      salePrice: salePrice ?? this.salePrice,
      totalAmount: totalAmount ?? this.totalAmount,
      profit: profit ?? this.profit,
      saleDate: saleDate ?? this.saleDate,
      customerId: customerId ?? this.customerId,
      discountAmount: discountAmount ?? this.discountAmount,
      finalAmount: finalAmount ?? this.finalAmount,
      invoiceId: invoiceId ?? this.invoiceId,
      note: clearNote ? null : (note ?? this.note),
    );
  }

  @override
  List<Object?> get props => [
        id,
        productId,
        barcode,
        productName,
        quantity,
        costPrice,
        salePrice,
        totalAmount,
        profit,
        saleDate,
        customerId,
        discountAmount,
        finalAmount,
        invoiceId,
        note,
      ];
}
