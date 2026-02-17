import 'package:equatable/equatable.dart';
import 'sale_item.dart';

class Invoice extends Equatable {
  final int? id;
  final String invoiceNumber;
  final int? customerId;
  final String? customerName;
  final double totalAmount;
  final double discountAmount;
  final double finalAmount;
  final double paidAmount;
  final double totalProfit;
  final String paymentMethod;
  final int? createdBy;
  final String? userName;
  final String? notes;
  final DateTime? createdDate;
  final DateTime? saleDate;
  final List<SaleItem>? items;

  const Invoice({
    this.id,
    required this.invoiceNumber,
    this.customerId,
    this.customerName,
    required this.totalAmount,
    this.discountAmount = 0,
    required this.finalAmount,
    this.paidAmount = 0,
    this.totalProfit = 0,
    this.paymentMethod = 'cash',
    this.createdBy,
    this.userName,
    this.notes,
    this.createdDate,
    this.saleDate,
    this.items,
  });

  // Convenience getters for UI
  DateTime get createdAt => createdDate ?? DateTime.now();
  double get subtotal => totalAmount;
  double get remainingAmount => finalAmount - paidAmount;
  bool get isFullyPaid => paidAmount >= finalAmount;
  bool get isPartiallyPaid => paidAmount > 0 && paidAmount < finalAmount;
  String get paymentStatus => isFullyPaid ? 'paid' : (isPartiallyPaid ? 'partial' : 'unpaid');

  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['id'] as int?,
      invoiceNumber: map['invoice_number'] as String,
      customerId: map['customer_id'] as int?,
      customerName: map['customer_name'] as String?,
      totalAmount: (map['total_amount'] as num).toDouble(),
      discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0,
      finalAmount: (map['final_amount'] as num).toDouble(),
      paidAmount: (map['paid_amount'] as num?)?.toDouble() ?? 0,
      totalProfit: (map['total_profit'] as num?)?.toDouble() ?? 0,
      paymentMethod: map['payment_method'] as String? ?? 'cash',
      createdBy: map['created_by'] as int?,
      userName: map['user_name'] as String?,
      notes: map['notes'] as String?,
      createdDate: map['created_date'] != null
          ? DateTime.parse(map['created_date'] as String)
          : null,
      saleDate: map['sale_date'] != null
          ? DateTime.parse(map['sale_date'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'invoice_number': invoiceNumber,
      'customer_id': customerId,
      'total_amount': totalAmount,
      'discount_amount': discountAmount,
      'final_amount': finalAmount,
      'paid_amount': paidAmount,
      'total_profit': totalProfit,
      'payment_method': paymentMethod,
      'created_by': createdBy,
    };
  }

  Invoice copyWith({
    int? id,
    String? invoiceNumber,
    int? customerId,
    String? customerName,
    double? totalAmount,
    double? discountAmount,
    double? finalAmount,
    double? paidAmount,
    double? totalProfit,
    String? paymentMethod,
    int? createdBy,
    String? userName,
    String? notes,
    DateTime? createdDate,
    DateTime? saleDate,
    List<SaleItem>? items,
  }) {
    return Invoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      totalAmount: totalAmount ?? this.totalAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      finalAmount: finalAmount ?? this.finalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      totalProfit: totalProfit ?? this.totalProfit,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      createdBy: createdBy ?? this.createdBy,
      userName: userName ?? this.userName,
      notes: notes ?? this.notes,
      createdDate: createdDate ?? this.createdDate,
      saleDate: saleDate ?? this.saleDate,
      items: items ?? this.items,
    );
  }

  @override
  List<Object?> get props => [
        id,
        invoiceNumber,
        customerId,
        totalAmount,
        discountAmount,
        finalAmount,
        paidAmount,
        totalProfit,
        paymentMethod,
        createdBy,
        createdDate,
        saleDate,
        items,
      ];
}
