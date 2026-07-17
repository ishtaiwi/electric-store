import 'package:equatable/equatable.dart';

/// One sale line for a customer on the selected date(s).
class DailyCustomerSaleLine extends Equatable {
  final int? saleId;
  final int? customerId;
  final String customerName;
  final String productName;
  final String? barcode;
  final int quantity;
  final double salePrice;
  final double discountAmount;
  final double totalAmount;
  final double finalAmount;
  final DateTime? saleDate;
  final int? invoiceId;
  final String? invoiceNumber;
  final String? note;
  final int? productId;

  const DailyCustomerSaleLine({
    this.saleId,
    this.customerId,
    required this.customerName,
    required this.productName,
    this.barcode,
    required this.quantity,
    required this.salePrice,
    this.discountAmount = 0,
    required this.totalAmount,
    required this.finalAmount,
    this.saleDate,
    this.invoiceId,
    this.invoiceNumber,
    this.note,
    this.productId,
  });

  bool get isCustomProduct => productId == null;

  factory DailyCustomerSaleLine.fromMap(Map<String, dynamic> map) {
    return DailyCustomerSaleLine(
      saleId: map['id'] as int?,
      customerId: map['customer_id'] as int?,
      customerName: (map['customer_name'] as String?) ?? '-',
      productName: (map['product_name'] as String?) ?? '-',
      barcode: map['barcode'] as String?,
      quantity: (map['quantity'] as int?) ?? 0,
      salePrice: (map['sale_price'] as num?)?.toDouble() ?? 0,
      discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0,
      finalAmount: (map['final_amount'] as num?)?.toDouble() ??
          (map['total_amount'] as num?)?.toDouble() ??
          0,
      saleDate: map['sale_date'] != null
          ? DateTime.tryParse(map['sale_date'] as String)
          : null,
      invoiceId: map['invoice_id'] as int?,
      invoiceNumber: map['invoice_number'] as String?,
      note: map['note'] as String?,
      productId: map['product_id'] as int?,
    );
  }

  @override
  List<Object?> get props => [
        saleId,
        customerId,
        customerName,
        productName,
        barcode,
        quantity,
        salePrice,
        discountAmount,
        totalAmount,
        finalAmount,
        saleDate,
        invoiceId,
        invoiceNumber,
        note,
        productId,
      ];
}

/// Aggregated sales for one customer within the selected period.
class DailyCustomerSalesGroup extends Equatable {
  final int customerId;
  final String customerName;
  final int itemCount;
  final double totalAmount;
  final List<DailyCustomerSaleLine> lines;

  const DailyCustomerSalesGroup({
    required this.customerId,
    required this.customerName,
    required this.itemCount,
    required this.totalAmount,
    required this.lines,
  });

  @override
  List<Object?> get props =>
      [customerId, customerName, itemCount, totalAmount, lines];
}

/// Daily (or date-range) customer sales ordered like account statements.
class DailyCustomerSalesReport extends Equatable {
  final List<DailyCustomerSalesGroup> byCustomer;
  final List<DailyCustomerSaleLine> lines;
  final double totalAmount;
  final int itemCount;
  final DateTime fromDate;
  final DateTime toDate;

  const DailyCustomerSalesReport({
    required this.byCustomer,
    required this.lines,
    required this.totalAmount,
    required this.itemCount,
    required this.fromDate,
    required this.toDate,
  });

  factory DailyCustomerSalesReport.empty({
    required DateTime fromDate,
    required DateTime toDate,
  }) =>
      DailyCustomerSalesReport(
        byCustomer: const [],
        lines: const [],
        totalAmount: 0,
        itemCount: 0,
        fromDate: fromDate,
        toDate: toDate,
      );

  @override
  List<Object?> get props =>
      [byCustomer, lines, totalAmount, itemCount, fromDate, toDate];
}
