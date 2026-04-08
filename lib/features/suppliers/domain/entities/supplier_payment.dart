import 'package:equatable/equatable.dart';

class SupplierPayment extends Equatable {
  final int? id;
  final int supplierInvoiceId;
  final double amount;
  final DateTime paymentDate;
  final String? notes;
  final DateTime? createdDate;

  const SupplierPayment({
    this.id,
    required this.supplierInvoiceId,
    required this.amount,
    required this.paymentDate,
    this.notes,
    this.createdDate,
  });

  factory SupplierPayment.fromMap(Map<String, dynamic> map) {
    return SupplierPayment(
      id: map['id'] as int?,
      supplierInvoiceId: map['supplier_invoice_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      paymentDate: DateTime.parse(map['payment_date'] as String),
      notes: map['notes'] as String?,
      createdDate: map['created_date'] != null
          ? DateTime.parse(map['created_date'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'supplier_invoice_id': supplierInvoiceId,
      'amount': amount,
      'payment_date': paymentDate.toIso8601String(),
      'notes': notes,
    };
  }

  SupplierPayment copyWith({
    int? id,
    int? supplierInvoiceId,
    double? amount,
    DateTime? paymentDate,
    String? notes,
    DateTime? createdDate,
  }) {
    return SupplierPayment(
      id: id ?? this.id,
      supplierInvoiceId: supplierInvoiceId ?? this.supplierInvoiceId,
      amount: amount ?? this.amount,
      paymentDate: paymentDate ?? this.paymentDate,
      notes: notes ?? this.notes,
      createdDate: createdDate ?? this.createdDate,
    );
  }

  @override
  List<Object?> get props => [id, supplierInvoiceId, amount, paymentDate, notes, createdDate];
}
