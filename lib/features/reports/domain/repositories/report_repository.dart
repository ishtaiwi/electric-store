abstract class ReportRepository {
  Future<Map<String, dynamic>> getDashboardStats();
  Future<List<Map<String, dynamic>>> getDailySalesReport(DateTime date);
  Future<Map<String, dynamic>> getProfitReport(DateTime start, DateTime end);
  Future<List<Map<String, dynamic>>> getInventoryReport();
  Future<List<Map<String, dynamic>>> getCustomerDebtsReport();
  Future<List<Map<String, dynamic>>> getBestSellingProducts(int limit);
  Future<List<Map<String, dynamic>>> getSalesByCategory(DateTime start, DateTime end);
  Future<List<Map<String, dynamic>>> getMonthlySalesTrend(int year);
}
