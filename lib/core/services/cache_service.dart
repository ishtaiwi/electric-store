/// A simple in-memory cache service for performance optimization
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  final Map<String, _CacheEntry> _cache = {};
  
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
    
    return entry.value as T?;
  }

  /// Set a cached value with optional duration
  void set<T>(String key, T value, {Duration? duration}) {
    _cache[key] = _CacheEntry(
      value: value,
      expiresAt: DateTime.now().add(duration ?? defaultDuration),
    );
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

  /// Clear all cached data
  void clear() {
    _cache.clear();
  }

  /// Remove expired entries
  void cleanUp() {
    _cache.removeWhere((key, entry) => entry.isExpired);
  }

  /// Get cache stats for debugging
  Map<String, dynamic> getStats() {
    cleanUp();
    return {
      'totalEntries': _cache.length,
      'keys': _cache.keys.toList(),
    };
  }
}

class _CacheEntry {
  final dynamic value;
  final DateTime expiresAt;

  _CacheEntry({
    required this.value,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Cache keys constants
class CacheKeys {
  static const String categories = 'categories';
  static const String lowStockProducts = 'low_stock_products';
  static const String dashboardStats = 'dashboard_stats';
  static const String recentSales = 'recent_sales';
  static const String todaySales = 'today_sales';
  static const String products = 'products';
  static const String customers = 'customers';
  
  static String productById(int id) => 'product_$id';
  static String productByBarcode(String barcode) => 'product_barcode_$barcode';
  static String customerById(int id) => 'customer_$id';
  static String invoiceById(int id) => 'invoice_$id';
}
