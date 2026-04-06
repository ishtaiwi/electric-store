import '../entities/cart_item.dart';
import '../entities/sale_record.dart';
import '../../../invoices/domain/entities/invoice.dart';

abstract class SalesRepository {
  Future<Invoice> createSale({
    required List<CartItem> items,
    int? customerId,
    double discountAmount,
    String paymentMethod,
    double? paidAmount,
    int? userId,
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
}
