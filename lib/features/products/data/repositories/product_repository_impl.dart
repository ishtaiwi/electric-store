import '../../../../core/database/database_helper.dart';
import '../../../../core/services/cache_service.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';

class ProductRepositoryImpl implements ProductRepository {
  final DatabaseHelper _databaseHelper;
  final CacheService _cache = CacheService();

  ProductRepositoryImpl(this._databaseHelper);

  @override
  Future<List<Product>> getAllProducts() async {
    // Check cache first
    final cached = _cache.get<List<Product>>(CacheKeys.products);
    if (cached != null) return cached;
    
    final db = await _databaseHelper.database;
    final result = await db.query('products', orderBy: 'name ASC');
    final products = result.map((map) => Product.fromMap(map)).toList();
    
    // Cache for 2 minutes
    _cache.set(CacheKeys.products, products, duration: const Duration(minutes: 2));
    return products;
  }

  @override
  Future<List<Product>> getProductsPaginated({int limit = 50, int offset = 0}) async {
    final db = await _databaseHelper.database;
    final result = await db.query(
      'products',
      orderBy: 'name ASC',
      limit: limit,
      offset: offset,
    );
    return result.map((map) => Product.fromMap(map)).toList();
  }

  @override
  Future<int> getProductsCount() async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM products');
    return result.first['count'] as int;
  }

  @override
  Future<Product?> getProductById(int id) async {
    // Check cache first
    final cached = _cache.get<Product>(CacheKeys.productById(id));
    if (cached != null) return cached;
    
    final db = await _databaseHelper.database;
    final result = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    
    final product = Product.fromMap(result.first);
    _cache.set(CacheKeys.productById(id), product, duration: CacheService.shortDuration);
    return product;
  }

  @override
  Future<Product?> getProductByBarcode(String barcode) async {
    // Check cache first
    final cached = _cache.get<Product>(CacheKeys.productByBarcode(barcode));
    if (cached != null) return cached;
    
    final db = await _databaseHelper.database;
    final result = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
    );
    if (result.isEmpty) return null;
    
    final product = Product.fromMap(result.first);
    _cache.set(CacheKeys.productByBarcode(barcode), product, duration: CacheService.shortDuration);
    return product;
  }

  @override
  Future<List<Product>> searchProducts(String query) async {
    final db = await _databaseHelper.database;
    final result = await db.query(
      'products',
      where: 'name LIKE ? OR barcode LIKE ? OR note LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'name ASC',
      limit: 100,
    );
    return result.map((map) => Product.fromMap(map)).toList();
  }

  @override
  Future<List<Product>> searchProductsPaginated(String query, {int limit = 50, int offset = 0}) async {
    final db = await _databaseHelper.database;
    final result = await db.query(
      'products',
      where: 'name LIKE ? OR barcode LIKE ? OR note LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'name ASC',
      limit: limit,
      offset: offset,
    );
    return result.map((map) => Product.fromMap(map)).toList();
  }

  @override
  Future<List<Product>> getLowStockProducts() async {
    // Check cache first
    final cached = _cache.get<List<Product>>(CacheKeys.lowStockProducts);
    if (cached != null) return cached;
    
    final db = await _databaseHelper.database;
    final result = await db.rawQuery(
      'SELECT * FROM products WHERE quantity <= min_stock ORDER BY quantity ASC',
    );
    final products = result.map((map) => Product.fromMap(map)).toList();
    
    // Cache for 2 minutes
    _cache.set(CacheKeys.lowStockProducts, products, duration: const Duration(minutes: 2));
    return products;
  }

  @override
  Future<int> createProduct(Product product) async {
    final db = await _databaseHelper.database;
    final result = await db.insert('products', product.toMap());
    // Invalidate product-related caches
    _cache.invalidate(CacheKeys.products);
    _cache.invalidate(CacheKeys.lowStockProducts);
    return result;
  }

  @override
  Future<int> updateProduct(Product product) async {
    final db = await _databaseHelper.database;
    final result = await db.update(
      'products',
      {...product.toMap(), 'last_updated': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [product.id],
    );
    // Invalidate caches
    _cache.invalidate(CacheKeys.products);
    _cache.invalidate(CacheKeys.productById(product.id!));
    if (product.barcode != null) {
      _cache.invalidate(CacheKeys.productByBarcode(product.barcode!));
    }
    _cache.invalidate(CacheKeys.lowStockProducts);
    return result;
  }

  @override
  Future<int> deleteProduct(int id) async {
    final db = await _databaseHelper.database;
    final result = await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
    // Invalidate caches
    _cache.invalidate(CacheKeys.products);
    _cache.invalidate(CacheKeys.productById(id));
    _cache.invalidate(CacheKeys.lowStockProducts);
    return result;
  }

  @override
  Future<int> updateStock(int productId, int quantity) async {
    final db = await _databaseHelper.database;
    final result = await db.rawUpdate(
      'UPDATE products SET quantity = ?, last_updated = ? WHERE id = ?',
      [quantity, DateTime.now().toIso8601String(), productId],
    );
    // Invalidate stock-related caches
    _cache.invalidate(CacheKeys.products);
    _cache.invalidate(CacheKeys.productById(productId));
    _cache.invalidate(CacheKeys.lowStockProducts);
    return result;
  }

  @override
  Future<int> adjustStock(
    int productId,
    int adjustment,
    String type,
    String? reason,
    int? userId,
  ) async {
    final db = await _databaseHelper.database;

    // Update product quantity
    String operation = type == 'stock_in' ? '+' : '-';
    await db.rawUpdate(
      'UPDATE products SET quantity = quantity $operation ?, last_updated = ? WHERE id = ?',
      [adjustment.abs(), DateTime.now().toIso8601String(), productId],
    );

    // Record adjustment
    final result = await db.insert('inventory_adjustments', {
      'product_id': productId,
      'adjustment_type': type,
      'quantity': adjustment,
      'reason': reason,
      'user_id': userId,
    });
    
    // Invalidate caches
    _cache.invalidate(CacheKeys.products);
    _cache.invalidate(CacheKeys.productById(productId));
    _cache.invalidate(CacheKeys.lowStockProducts);
    
    return result;
  }
}
