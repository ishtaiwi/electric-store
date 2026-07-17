import 'package:equatable/equatable.dart';

enum CustomerPaymentMethod {
  cash,
  cheque,
  discount,
}

class CustomerPayment extends Equatable {
  final int? id;
  final int invoiceId;
  final int customerId;
  final double amount;
  final DateTime paymentDate;
  final CustomerPaymentMethod paymentMethod;
  final String? chequeNumber;
  final String? notes;
  final DateTime? createdDate;

  // Join fields (from query)
  final String? invoiceNumber;
  final String? customerName;

  const CustomerPayment({
    this.id,
    required this.invoiceId,
    required this.customerId,
    required this.amount,
    required this.paymentDate,
    this.paymentMethod = CustomerPaymentMethod.cash,
    this.chequeNumber,
    this.notes,
    this.createdDate,
    this.invoiceNumber,
    this.customerName,
  });

  bool get isCash => paymentMethod == CustomerPaymentMethod.cash;
  bool get isCheque => paymentMethod == CustomerPaymentMethod.cheque;
  bool get isDiscount => paymentMethod == CustomerPaymentMethod.discount;

  factory CustomerPayment.fromMap(Map<String, dynamic> map) {
    return CustomerPayment(
      id: map['id'] as int?,
      invoiceId: map['invoice_id'] as int,
      customerId: map['customer_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      paymentDate: DateTime.parse(map['payment_date'] as String),
      paymentMethod: switch (map['payment_method'] as String?) {
        'cheque' => CustomerPaymentMethod.cheque,
        'discount' => CustomerPaymentMethod.discount,
        _ => CustomerPaymentMethod.cash,
      },
      chequeNumber: map['cheque_number'] as String?,
      notes: map['notes'] as String?,
      createdDate: map['created_date'] != null
          ? DateTime.parse(map['created_date'] as String)
          : null,
      invoiceNumber: map['invoice_number'] as String?,
      customerName: map['customer_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'invoice_id': invoiceId,
      'customer_id': customerId,
      'amount': amount,
      'payment_date': paymentDate.toIso8601String(),
      'payment_method': switch (paymentMethod) {
        CustomerPaymentMethod.cheque => 'cheque',
        CustomerPaymentMethod.discount => 'discount',
        CustomerPaymentMethod.cash => 'cash',
      },
      'cheque_number': chequeNumber,
      'notes': notes,
    };
  }

  CustomerPayment copyWith({
    int? id,
    int? invoiceId,
    int? customerId,
    double? amount,
    DateTime? paymentDate,
    CustomerPaymentMethod? paymentMethod,
    String? chequeNumber,
    String? notes,
    DateTime? createdDate,
    String? invoiceNumber,
    String? customerName,
  }) {
    return CustomerPayment(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      customerId: customerId ?? this.customerId,
      amount: amount ?? this.amount,
      paymentDate: paymentDate ?? this.paymentDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      chequeNumber: chequeNumber ?? this.chequeNumber,
      notes: notes ?? this.notes,
      createdDate: createdDate ?? this.createdDate,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      customerName: customerName ?? this.customerName,
    );
  }

  @override
  List<Object?> get props => [id, invoiceId, customerId, amount, paymentDate, paymentMethod, chequeNumber, notes, createdDate];
}
