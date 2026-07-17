import '../entities/cart_item.dart';
import '../entities/sale_record.dart';
import '../entities/account_ledger_profit_report.dart';
import '../entities/daily_customer_sales_report.dart';
import '../../../invoices/domain/entities/invoice.dart';

abstract class SalesRepository {
  Future<Invoice> createSale({
    required List<CartItem> items,
    int? customerId,
    double discountAmount = 0,
    String paymentMethod = 'cash',
    double? paidAmount,
    int? userId,
    DateTime? saleDate,
    String? customerName,
  });

  /// Records goods on the customer account statement (one batch per date).
  Future<Invoice> addToCustomerAccount({
    required List<CartItem> items,
    required int customerId,
    String? customerName,
    double discountAmount = 0,
    DateTime? saleDate,
    int? userId,
    double? paidAmount,
    String paymentMethod = 'cash',
  });
  Future<int> cancelSale(int saleId, String reason, int? userId);
  Future<List<Map<String, dynamic>>> getSalesToday();
  Future<double> getTodaySalesTotal();
  Future<double> getTodayProfit();

  /// Get all individual sale records with customer/invoice info, supports search and pagination.
  Future<List<SaleRecord>> getAllSaleRecords({
    String? searchQuery,
    int limit = 50,
    int offset = 0,
  });

  /// Get total count of sale records matching the search query.
  Future<int> getSaleRecordsCount({String? searchQuery});

  /// Removes one goods line from a customer account batch and restores stock.
  Future<int> deleteAccountSaleLine(int saleId);

  /// Full profit from a customer's account statement (كشف الحساب) sales.
  /// Includes all invoices linked to the customer (same scope as the ledger),
  /// but only registered catalog products (`product_id IS NOT NULL`).
  /// Pass [customerId] to limit to one customer from the customers page.
  Future<AccountLedgerProfitReport> getAccountLedgerProfitReport({
    int? customerId,
  });

  /// Customer-linked sales for a date range, grouped per customer and ordered
  /// like the account statement (chronological by invoice within each customer).
  /// Defaults to today when dates are omitted.
  Future<DailyCustomerSalesReport> getDailyCustomerSalesReport({
    DateTime? fromDate,
    DateTime? toDate,
    int? customerId,
  });
}
