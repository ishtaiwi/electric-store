import 'package:equatable/equatable.dart';

/// Aggregated account-statement profit for one customer (registered products only).
class AccountLedgerProfitByCustomer extends Equatable {
  final int customerId;
  final String customerName;
  final int itemCount;
  final double totalSales;
  final double totalProfit;

  const AccountLedgerProfitByCustomer({
    required this.customerId,
    required this.customerName,
    required this.itemCount,
    required this.totalSales,
    required this.totalProfit,
  });

  @override
  List<Object?> get props =>
      [customerId, customerName, itemCount, totalSales, totalProfit];
}

/// One sale line from an account-statement invoice (registered product).
class AccountLedgerProfitLine extends Equatable {
  final int? saleId;
  final int? customerId;
  final String customerName;
  final String productName;
  final int quantity;
  final double salePrice;
  final double totalAmount;
  final double profit;
  final DateTime? saleDate;
  final String? invoiceNumber;

  const AccountLedgerProfitLine({
    this.saleId,
    this.customerId,
    required this.customerName,
    required this.productName,
    required this.quantity,
    required this.salePrice,
    required this.totalAmount,
    required this.profit,
    this.saleDate,
    this.invoiceNumber,
  });

  factory AccountLedgerProfitLine.fromMap(Map<String, dynamic> map) {
    return AccountLedgerProfitLine(
      saleId: map['id'] as int?,
      customerId: map['customer_id'] as int?,
      customerName: (map['customer_name'] as String?) ?? '-',
      productName: (map['product_name'] as String?) ?? '-',
      quantity: (map['quantity'] as int?) ?? 0,
      salePrice: (map['sale_price'] as num?)?.toDouble() ?? 0,
      totalAmount: (map['final_amount'] as num?)?.toDouble() ??
          (map['total_amount'] as num?)?.toDouble() ??
          0,
      profit: (map['profit'] as num?)?.toDouble() ?? 0,
      saleDate: map['sale_date'] != null
          ? DateTime.tryParse(map['sale_date'] as String)
          : null,
      invoiceNumber: map['invoice_number'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        saleId,
        customerId,
        customerName,
        productName,
        quantity,
        salePrice,
        totalAmount,
        profit,
        saleDate,
        invoiceNumber,
      ];
}

class AccountLedgerProfitReport extends Equatable {
  final List<AccountLedgerProfitByCustomer> byCustomer;
  final List<AccountLedgerProfitLine> lines;
  final double totalSales;
  final double totalProfit;
  final int itemCount;

  const AccountLedgerProfitReport({
    required this.byCustomer,
    required this.lines,
    required this.totalSales,
    required this.totalProfit,
    required this.itemCount,
  });

  factory AccountLedgerProfitReport.empty() => const AccountLedgerProfitReport(
        byCustomer: [],
        lines: [],
        totalSales: 0,
        totalProfit: 0,
        itemCount: 0,
      );

  @override
  List<Object?> get props =>
      [byCustomer, lines, totalSales, totalProfit, itemCount];
}
