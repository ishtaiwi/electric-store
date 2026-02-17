import 'package:equatable/equatable.dart';

class Expense extends Equatable {
  final int? id;
  final String category;
  final String description;
  final double amount;
  final DateTime? expenseDate;
  final String paymentMethod;
  final String? receiptNumber;
  final String? supplier;
  final String? notes;
  final int? userId;

  const Expense({
    this.id,
    required this.category,
    required this.description,
    required this.amount,
    this.expenseDate,
    this.paymentMethod = 'cash',
    this.receiptNumber,
    this.supplier,
    this.notes,
    this.userId,
  });

  // Convenience getters for UI
  DateTime get date => expenseDate ?? DateTime.now();
  int? get createdBy => userId;

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      category: map['category'] as String,
      description: map['description'] as String,
      amount: (map['amount'] as num).toDouble(),
      expenseDate: map['expense_date'] != null
          ? DateTime.parse(map['expense_date'] as String)
          : null,
      paymentMethod: map['payment_method'] as String? ?? 'cash',
      receiptNumber: map['receipt_number'] as String?,
      supplier: map['supplier'] as String?,
      notes: map['notes'] as String?,
      userId: map['user_id'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'category': category,
      'description': description,
      'amount': amount,
      'payment_method': paymentMethod,
      'receipt_number': receiptNumber,
      'supplier': supplier,
      'notes': notes,
      'user_id': userId,
    };
  }

  Expense copyWith({
    int? id,
    String? category,
    String? description,
    double? amount,
    DateTime? expenseDate,
    String? paymentMethod,
    String? receiptNumber,
    String? supplier,
    String? notes,
    int? userId,
  }) {
    return Expense(
      id: id ?? this.id,
      category: category ?? this.category,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      expenseDate: expenseDate ?? this.expenseDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      supplier: supplier ?? this.supplier,
      notes: notes ?? this.notes,
      userId: userId ?? this.userId,
    );
  }

  @override
  List<Object?> get props => [
        id,
        category,
        description,
        amount,
        expenseDate,
        paymentMethod,
        receiptNumber,
        supplier,
        notes,
        userId,
      ];
}
