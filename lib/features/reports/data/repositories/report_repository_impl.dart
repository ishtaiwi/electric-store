import '../../../../core/database/database_helper.dart';
import '../../../../core/services/cache_service.dart';
import '../../domain/repositories/report_repository.dart';

class ReportRepositoryImpl implements ReportRepository {
  final DatabaseHelper _databaseHelper;
  final CacheService _cache = CacheService();

  ReportRepositoryImpl(this._databaseHelper);

  @override
  Future<Map<String, dynamic>> getDashboardStats() async {
    // Check cache first (short TTL since dashboard needs fresh data)
    final cached = _cache.get<Map<String, dynamic>>(CacheKeys.dashboardStats);
    if (cached != null) return cached;

    final db = await _databaseHelper.database;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final startOfMonth = DateTime(today.year, today.month, 1);

    // Run all queries in parallel for better performance
    final results = await Future.wait([
      // 0: Today's sales revenue
      db.rawQuery('''
        SELECT COALESCE(SUM(final_amount), 0) as total
        FROM invoices WHERE date(created_date) = date(?)
      ''', [startOfDay.toIso8601String()]),

      // 1: Today's profit — registered products only (exclude custom items)
      db.rawQuery('''
        SELECT COALESCE(SUM(profit), 0) as profit
        FROM sales
        WHERE date(sale_date) = date(?)
          AND product_id IS NOT NULL
      ''', [startOfDay.toIso8601String()]),
      
      // 2: Monthly sales
      db.rawQuery('''
        SELECT COALESCE(SUM(final_amount), 0) as total, COALESCE(SUM(total_profit), 0) as profit
        FROM invoices WHERE date(created_date) >= date(?)
      ''', [startOfMonth.toIso8601String()]),
      
      // 3: Product count
      db.rawQuery('SELECT COUNT(*) as count FROM products'),
      
      // 4: Low stock count
      db.rawQuery(
        'SELECT COUNT(*) as count FROM products WHERE quantity <= min_stock AND quantity > 0',
      ),
      
      // 5: Out of stock count
      db.rawQuery(
        'SELECT COUNT(*) as count FROM products WHERE quantity = 0',
      ),
      
      // 6: Customer count
      db.rawQuery('SELECT COUNT(*) as count FROM customers'),
      
      // 7: Today's invoice count
      db.rawQuery('''
        SELECT COUNT(*) as count FROM invoices WHERE date(created_date) = date(?)
      ''', [startOfDay.toIso8601String()]),
      
      // 8: Total inventory value
      db.rawQuery(
        'SELECT COALESCE(SUM(quantity * cost_price), 0) as value FROM products',
      ),
      
      // 9: Customer debts
      db.rawQuery('''
        SELECT COALESCE(SUM(inv_debt), 0) + COALESCE(SUM(adj), 0) as total
        FROM (
          SELECT 
            (SELECT COALESCE(SUM(final_amount - paid_amount), 0) FROM invoices WHERE customer_id = c.id) as inv_debt,
            COALESCE(c.balance_adjustment, 0) as adj
          FROM customers c
        )
      '''),
    ]);

    final todaySales = results[0];
    final todayProfit = results[1];
    final monthlySales = results[2];
    final productCount = results[3];
    final lowStockCount = results[4];
    final outOfStockCount = results[5];
    final customerCount = results[6];
    final invoiceCount = results[7];
    final inventoryValue = results[8];
    final debts = results[9];

    final result = {
      'todaySales': (todaySales.first['total'] as num?)?.toDouble() ?? 0,
      'todayProfit': (todayProfit.first['profit'] as num?)?.toDouble() ?? 0,
      'monthlySales': (monthlySales.first['total'] as num?)?.toDouble() ?? 0,
      'monthlyProfit': (monthlySales.first['profit'] as num?)?.toDouble() ?? 0,
      'productCount': productCount.first['count'] as int? ?? 0,
      'lowStockCount': lowStockCount.first['count'] as int? ?? 0,
      'outOfStockCount': outOfStockCount.first['count'] as int? ?? 0,
      'customerCount': customerCount.first['count'] as int? ?? 0,
      'todayInvoiceCount': invoiceCount.first['count'] as int? ?? 0,
      'inventoryValue': (inventoryValue.first['value'] as num?)?.toDouble() ?? 0,
      'totalDebts': (debts.first['total'] as num?)?.toDouble() ?? 0,
    };

    // Cache for 30 seconds — dashboard is shown frequently
    _cache.set(CacheKeys.dashboardStats, result, duration: const Duration(seconds: 30));
    return result;
  }

  @override
  Future<List<Map<String, dynamic>>> getDailySalesReport(DateTime date) async {
    final db = await _databaseHelper.database;
    return await db.rawQuery('''
      SELECT 
        s.id,
        s.product_name,
        s.quantity,
        s.sale_price,
        s.total_amount,
        s.profit,
        s.sale_date,
        i.invoice_number,
        c.name as customer_name
      FROM sales s
      LEFT JOIN invoices i ON s.invoice_id = i.id
      LEFT JOIN customers c ON s.customer_id = c.id
      WHERE date(s.sale_date) = date(?)
      ORDER BY s.sale_date DESC
    ''', [date.toIso8601String()]);
  }

  @override
  Future<Map<String, dynamic>> getProfitReport(DateTime start, DateTime end) async {
    final db = await _databaseHelper.database;

    // Total revenue and profit
    final sales = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(final_amount), 0) as revenue,
        COALESCE(SUM(total_profit), 0) as profit
      FROM invoices
      WHERE date(created_date) BETWEEN date(?) AND date(?)
    ''', [start.toIso8601String(), end.toIso8601String()]);

    // Total expenses
    final expenses = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM expenses
      WHERE date(expense_date) BETWEEN date(?) AND date(?)
    ''', [start.toIso8601String(), end.toIso8601String()]);

    // Cancelled sales
    final cancelled = await db.rawQuery('''
      SELECT COALESCE(SUM(profit), 0) as lost_profit
      FROM cancelled_sales
      WHERE date(cancel_date) BETWEEN date(?) AND date(?)
    ''', [start.toIso8601String(), end.toIso8601String()]);

    final revenue = (sales.first['revenue'] as num?)?.toDouble() ?? 0;
    final grossProfit = (sales.first['profit'] as num?)?.toDouble() ?? 0;
    final totalExpenses = (expenses.first['total'] as num?)?.toDouble() ?? 0;
    final lostProfit = (cancelled.first['lost_profit'] as num?)?.toDouble() ?? 0;
    final netProfit = grossProfit - totalExpenses;

    return {
      'revenue': revenue,
      'grossProfit': grossProfit,
      'expenses': totalExpenses,
      'lostProfit': lostProfit,
      'netProfit': netProfit,
      'profitMargin': revenue > 0 ? (netProfit / revenue) * 100 : 0,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getInventoryReport() async {
    final cached = _cache.get<List<Map<String, dynamic>>>(CacheKeys.inventoryReport);
    if (cached != null) return cached;

    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT 
        id,
        name,
        barcode,
        category,
        quantity,
        min_stock,
        price,
        cost_price,
        (quantity * cost_price) as stock_value,
        CASE 
          WHEN quantity <= 0 THEN 'out_of_stock'
          WHEN quantity <= min_stock THEN 'low_stock'
          ELSE 'in_stock'
        END as status
      FROM products
      ORDER BY 
        CASE 
          WHEN quantity <= 0 THEN 1
          WHEN quantity <= min_stock THEN 2
          ELSE 3
        END,
        name ASC
    ''');

    _cache.set(CacheKeys.inventoryReport, result, duration: const Duration(minutes: 2));
    return result;
  }

  @override
  Future<List<Map<String, dynamic>>> getCustomerDebtsReport() async {
    final cached = _cache.get<List<Map<String, dynamic>>>(CacheKeys.customerDebtsReport);
    if (cached != null) return cached;

    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT 
        c.id,
        c.name,
        c.phone,
        COALESCE(SUM(i.final_amount - i.paid_amount), 0) + COALESCE(c.balance_adjustment, 0) as balance,
        COALESCE(SUM(i.final_amount - i.paid_amount), 0) + COALESCE(c.balance_adjustment, 0) as total_debt,
        COUNT(CASE WHEN (i.final_amount - i.paid_amount) > 0 THEN 1 END) as invoice_count,
        MAX(i.created_date) as last_purchase
      FROM customers c
      LEFT JOIN invoices i ON c.id = i.customer_id
      GROUP BY c.id
      HAVING total_debt > 0
      ORDER BY total_debt DESC
    ''');

    _cache.set(CacheKeys.customerDebtsReport, result, duration: const Duration(minutes: 1));
    return result;
  }

  @override
  Future<List<Map<String, dynamic>>> getBestSellingProducts(int limit) async {
    final cacheKey = CacheKeys.bestSelling(limit);
    final cached = _cache.get<List<Map<String, dynamic>>>(cacheKey);
    if (cached != null) return cached;

    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT 
        p.id,
        p.name,
        p.barcode,
        p.note,
        SUM(s.quantity) as total_sold,
        SUM(s.final_amount) as total_revenue,
        SUM(s.profit) as total_profit
      FROM sales s
      INNER JOIN products p ON s.product_id = p.id
      GROUP BY s.product_id
      ORDER BY total_sold DESC
      LIMIT ?
    ''', [limit]);

    _cache.set(cacheKey, result, duration: const Duration(minutes: 2));
    return result;
  }

  @override
  Future<List<Map<String, dynamic>>> getSalesByCategory(DateTime start, DateTime end) async {
    final db = await _databaseHelper.database;
    return await db.rawQuery('''
      SELECT 
        COALESCE(p.note, 'Uncategorized') as category,
        SUM(s.quantity) as quantity_sold,
        SUM(s.final_amount) as revenue,
        SUM(s.profit) as profit
      FROM sales s
      LEFT JOIN products p ON s.product_id = p.id
      WHERE date(s.sale_date) BETWEEN date(?) AND date(?)
      GROUP BY p.note
      ORDER BY revenue DESC
    ''', [start.toIso8601String(), end.toIso8601String()]);
  }

  @override
  Future<List<Map<String, dynamic>>> getMonthlySalesTrend(int year) async {
    final db = await _databaseHelper.database;
    return await db.rawQuery('''
      SELECT 
        strftime('%m', created_date) as month,
        COALESCE(SUM(final_amount), 0) as revenue,
        COALESCE(SUM(total_profit), 0) as profit,
        COUNT(*) as invoice_count
      FROM invoices
      WHERE strftime('%Y', created_date) = ?
      GROUP BY strftime('%m', created_date)
      ORDER BY month ASC
    ''', [year.toString()]);
  }
}
