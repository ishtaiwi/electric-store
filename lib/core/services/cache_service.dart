/// A high-performance in-memory cache service with TTL, size limits,
/// and cross-feature invalidation support.
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  final Map<String, _CacheEntry> _cache = {};
  
  /// Maximum number of cache entries to prevent unbounded memory growth
  static const int maxEntries = 500;
  
  /// Default cache duration: 5 minutes
  static const Duration defaultDuration = Duration(minutes: 5);
  
  /// Short cache duration: 1 minute
  static const Duration shortDuration = Duration(minutes: 1);
  
  /// Long cache duration: 30 minutes
  static const Duration longDuration = Duration(minutes: 30);

  /// Get a cached value by key
  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    
    if (entry.isExpired) {
      _cache.remove(key);
      return null;
    }
    
    // Update access time for LRU-style eviction
    entry.lastAccessed = DateTime.now();
    return entry.value as T?;
  }

  /// Set a cached value with optional duration
  void set<T>(String key, T value, {Duration? duration}) {
    // Evict oldest entries if cache is full
    if (_cache.length >= maxEntries && !_cache.containsKey(key)) {
      _evictOldest();
    }
    
    _cache[key] = _CacheEntry(
      value: value,
      expiresAt: DateTime.now().add(duration ?? defaultDuration),
    );
  }

  /// Get or compute: returns cached value, or calls [compute] and caches the result
  Future<T> getOrCompute<T>(String key, Future<T> Function() compute, {Duration? duration}) async {
    final cached = get<T>(key);
    if (cached != null) return cached;
    
    final value = await compute();
    set<T>(key, value, duration: duration);
    return value;
  }

  /// Check if a key exists and is not expired
  bool has(String key) {
    final entry = _cache[key];
    if (entry == null) return false;
    
    if (entry.isExpired) {
      _cache.remove(key);
      return false;
    }
    
    return true;
  }

  /// Invalidate a specific key
  void invalidate(String key) {
    _cache.remove(key);
  }

  /// Invalidate all keys matching a pattern
  void invalidatePattern(String pattern) {
    final keysToRemove = _cache.keys
        .where((key) => key.contains(pattern))
        .toList();
    for (final key in keysToRemove) {
      _cache.remove(key);
    }
  }

  /// Invalidate multiple specific keys at once
  void invalidateAll(List<String> keys) {
    for (final key in keys) {
      _cache.remove(key);
    }
  }

  /// Invalidate all sales/invoice/report related caches
  /// Call this after any sale, invoice deletion, or payment update
  void invalidateSalesRelated() {
    invalidateAll([
      CacheKeys.dashboardStats,
      CacheKeys.recentSales,
      CacheKeys.todaySales,
    ]);
    invalidatePattern('invoice');
    invalidatePattern('report');
    invalidatePattern('sales');
  }

  /// Invalidate all product-related caches
  void invalidateProductRelated() {
    invalidateAll([
      CacheKeys.products,
      CacheKeys.lowStockProducts,
      CacheKeys.dashboardStats,
    ]);
    invalidatePattern('product');
  }

  /// Invalidate all customer-related caches
  void invalidateCustomerRelated() {
    invalidateAll([
      CacheKeys.customers,
      CacheKeys.dashboardStats,
    ]);
    invalidatePattern('customer');
  }

  /// Clear all cached data
  void clear() {
    _cache.clear();
  }

  /// Remove expired entries
  void cleanUp() {
    _cache.removeWhere((key, entry) => entry.isExpired);
  }

  /// Evict the least-recently-accessed entries to make room
  void _evictOldest() {
    cleanUp(); // First remove expired
    if (_cache.length < maxEntries) return;
    
    // Sort by last accessed time and remove the oldest 10%
    final entries = _cache.entries.toList()
      ..sort((a, b) => a.value.lastAccessed.compareTo(b.value.lastAccessed));
    final toRemove = (maxEntries * 0.1).ceil();
    for (var i = 0; i < toRemove && i < entries.length; i++) {
      _cache.remove(entries[i].key);
    }
  }

  /// Get cache stats for debugging
  Map<String, dynamic> getStats() {
    cleanUp();
    return {
      'totalEntries': _cache.length,
      'maxEntries': maxEntries,
      'keys': _cache.keys.toList(),
    };
  }
}

class _CacheEntry {
  final dynamic value;
  final DateTime expiresAt;
  DateTime lastAccessed;

  _CacheEntry({
    required this.value,
    required this.expiresAt,
  }) : lastAccessed = DateTime.now();

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Cache keys constants
class CacheKeys {
  // Product keys
  static const String categories = 'categories';
  static const String lowStockProducts = 'low_stock_products';
  static const String products = 'products';
  static const String productsCount = 'products_count';
  
  // Dashboard / Reports
  static const String dashboardStats = 'dashboard_stats';
  static const String recentSales = 'recent_sales';
  static const String todaySales = 'today_sales';
  static const String inventoryReport = 'inventory_report';
  static const String customerDebtsReport = 'customer_debts_report';
  
  // Customers
  static const String customers = 'customers';
  static const String customersWithDebt = 'customers_with_debt';
  
  // Invoices
  static const String invoices = 'all_invoices';
  static const String invoicesCount = 'invoices_count';
  static const String todayInvoices = 'today_invoices';
  
  // Expenses
  static const String expenses = 'all_expenses';
  static const String expenseCategories = 'expense_categories';
  
  // Suppliers
  static const String suppliers = 'all_suppliers';
  
  // Settings
  static const String settings = 'all_settings';
  
  // Price lists
  static const String priceLists = 'all_price_lists';
  
  static String productById(int id) => 'product_$id';
  static String productByBarcode(String barcode) => 'product_barcode_$barcode';
  static String customerById(int id) => 'customer_$id';
  static String invoiceById(int id) => 'invoice_$id';
  static String supplierById(int id) => 'supplier_$id';
  static String supplierInvoices(int supplierId) => 'supplier_invoices_$supplierId';
  static String supplierFinancialSummary(int supplierId) => 'supplier_financial_$supplierId';
  static const String globalSupplierOutstanding = 'global_supplier_outstanding';
  static String expensesByDateRange(String start, String end) => 'expenses_${start}_$end';
  static String reportProfit(String start, String end) => 'report_profit_${start}_$end';
  static String bestSelling(int limit) => 'best_selling_$limit';
}
