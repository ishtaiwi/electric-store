import 'package:equatable/equatable.dart';

/// Represents a single sale record (item-level) with customer info,
/// used in the "All Sales" page for flat item-level view.
class SaleRecord extends Equatable {
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
  final String? customerName;
  final double discountAmount;
  final double finalAmount;
  final int? invoiceId;
  final String? invoiceNumber;
  final String? note;

  const SaleRecord({
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
    this.customerName,
    this.discountAmount = 0,
    required this.finalAmount,
    this.invoiceId,
    this.invoiceNumber,
    this.note,
  });

  bool get isCustomProduct => productId == null;

  factory SaleRecord.fromMap(Map<String, dynamic> map) {
    return SaleRecord(
      id: map['id'] as int?,
      productId: map['product_id'] as int?,
      barcode: map['barcode'] as String?,
      productName: (map['product_name'] as String?) ?? 'Unknown Product',
      quantity: (map['quantity'] as int?) ?? 0,
      costPrice: (map['cost_price'] as num?)?.toDouble() ?? 0,
      salePrice: (map['sale_price'] as num?)?.toDouble() ?? 0,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0,
      profit: (map['profit'] as num?)?.toDouble() ?? 0,
      saleDate: map['sale_date'] != null
          ? DateTime.tryParse(map['sale_date'] as String)
          : null,
      customerId: map['customer_id'] as int?,
      customerName: map['customer_name'] as String?,
      discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0,
      finalAmount: (map['final_amount'] as num?)?.toDouble() ?? 0,
      invoiceId: map['invoice_id'] as int?,
      invoiceNumber: map['invoice_number'] as String?,
      note: map['note'] as String?,
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
        customerName,
        discountAmount,
        finalAmount,
        invoiceId,
        invoiceNumber,
        note,
      ];
}
