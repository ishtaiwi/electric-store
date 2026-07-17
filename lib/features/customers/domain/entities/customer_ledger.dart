import 'package:equatable/equatable.dart';
import '../../../invoices/domain/entities/sale_item.dart';
import 'customer.dart';
import 'customer_ledger_entry.dart';
import 'customer_ledger_filters.dart';

class CustomerLedger extends Equatable {
  final Customer customer;
  final String customerCode;
  final double previousBalance;
  final double openingDebit;
  final double openingCredit;
  final bool showCarriedForward;
  final double currentBalance;
  final double totalSales;
  final double totalPayments;
  final double totalOutstanding;
  final double totalDebit;
  final double totalCredit;
  final double finalBalance;
  final List<CustomerLedgerEntry> entries;
  final Map<int, List<SaleItem>> invoiceItems;
  final CustomerLedgerFilters filters;

  const CustomerLedger({
    required this.customer,
    required this.customerCode,
    required this.previousBalance,
    this.openingDebit = 0,
    this.openingCredit = 0,
    this.showCarriedForward = false,
    required this.currentBalance,
    required this.totalSales,
    required this.totalPayments,
    required this.totalOutstanding,
    required this.totalDebit,
    required this.totalCredit,
    required this.finalBalance,
    required this.entries,
    required this.invoiceItems,
    this.filters = const CustomerLedgerFilters(),
  });

  bool get isDebtor => finalBalance > 0;
  bool get isCreditor => finalBalance < 0;
  bool get isSettled => finalBalance == 0;

  @override
  List<Object?> get props => [
        customer,
        customerCode,
        previousBalance,
        openingDebit,
        openingCredit,
        showCarriedForward,
        currentBalance,
        totalSales,
        totalPayments,
        totalOutstanding,
        totalDebit,
        totalCredit,
        finalBalance,
        entries,
        filters,
      ];
}
