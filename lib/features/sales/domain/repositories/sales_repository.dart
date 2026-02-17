import '../entities/cart_item.dart';
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
}
