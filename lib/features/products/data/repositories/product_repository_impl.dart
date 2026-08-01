import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/services/cache_service.dart';
import '../../../../core/services/audit_logger_service.dart';
import '../../domain/entities/product.dart';
import '../../domain/exceptions/product_in_use_exception.dart';
import '../../domain/repositories/product_repository.dart';

class ProductRepositoryImpl implements ProductRepository {
  final DatabaseHelper _databaseHelper;
  final CacheService _cache = CacheService();
  final AuditLoggerService _auditLogger = AuditLoggerService();

  ProductRepositoryImpl(this._databaseHelper);

  (String? where, List<Object?> args) _buildProductFilter({
    String? query,
    String? brand,
    String? category,
    bool lowStockOnly = false,
  }) {
    final clauses = <String>[];
    final args = <Object?>[];

    final q = query?.trim() ?? '';
    if (q.isNotEmpty) {
      clauses.add(
        '(name LIKE ? OR barcode LIKE ? OR note LIKE ? OR brand LIKE ? OR category LIKE ?)',
      );
      args.addAll(List.filled(5, '%$q%'));
    }

    final brandFilter = brand?.trim();
    if (brandFilter != null && brandFilter.isNotEmpty) {
      clauses.add('brand = ?');
      args.add(brandFilter);
    }

    final categoryFilter = category?.trim();
    if (categoryFilter != null && categoryFilter.isNotEmpty) {
      clauses.add('category = ?');
      args.add(categoryFilter);
    }

    if (lowStockOnly) {
      clauses.add('quantity <= min_stock');
    }

    if (clauses.isEmpty) return (null, const []);
    return (clauses.join(' AND '), args);
  }

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
  Future<List<Product>> getProductsPaginated({
    int limit = 50,
    int offset = 0,
    String? brand,
    String? category,
  }) async {
    final db = await _databaseHelper.database;
    final filter = _buildProductFilter(brand: brand, category: category);
    final result = await db.query(
      'products',
      where: filter.$1,
      whereArgs: filter.$2,
      orderBy: 'name ASC',
      limit: limit,
      offset: offset,
    );
    return result.map((map) => Product.fromMap(map)).toList();
  }

  @override
  Future<int> getProductsCount({String? brand, String? category}) async {
    final db = await _databaseHelper.database;
    final filter = _buildProductFilter(brand: brand, category: category);
    if (filter.$1 == null) {
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM products');
      return result.first['count'] as int;
    }
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM products WHERE ${filter.$1}',
      filter.$2,
    );
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
  Future<List<Product>> searchProducts(
    String query, {
    String? brand,
    String? category,
  }) async {
    final db = await _databaseHelper.database;
    final filter = _buildProductFilter(query: query, brand: brand, category: category);
    final result = await db.query(
      'products',
      where: filter.$1,
      whereArgs: filter.$2,
      orderBy: 'name ASC',
      limit: 100,
    );
    return result.map((map) => Product.fromMap(map)).toList();
  }

  @override
  Future<List<Product>> searchProductsPaginated(
    String query, {
    int limit = 50,
    int offset = 0,
    String? brand,
    String? category,
  }) async {
    final db = await _databaseHelper.database;
    final filter = _buildProductFilter(query: query, brand: brand, category: category);
    final result = await db.query(
      'products',
      where: filter.$1,
      whereArgs: filter.$2,
      orderBy: 'name ASC',
      limit: limit,
      offset: offset,
    );
    return result.map((map) => Product.fromMap(map)).toList();
  }

  @override
  Future<List<String>> getBrands() async {
    final db = await _databaseHelper.database;
    final result = await db.query(
      'product_brands',
      columns: ['name'],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return result.map((row) => row['name'] as String).toList();
  }

  @override
  Future<int> addBrand(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 0;
    final db = await _databaseHelper.database;
    try {
      return await db.insert('product_brands', {'name': trimmed});
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) return 0;
      rethrow;
    }
  }

  @override
  Future<int> deleteBrand(String name) async {
    final db = await _databaseHelper.database;
    return db.delete('product_brands', where: 'name = ?', whereArgs: [name]);
  }

  @override
  Future<List<String>> getCategories() async {
    final db = await _databaseHelper.database;
    final result = await db.query(
      'product_categories',
      columns: ['name'],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return result.map((row) => row['name'] as String).toList();
  }

  @override
  Future<int> addCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 0;
    final db = await _databaseHelper.database;
    try {
      return await db.insert('product_categories', {'name': trimmed});
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) return 0;
      rethrow;
    }
  }

  @override
  Future<int> deleteCategory(String name) async {
    final db = await _databaseHelper.database;
    return db.delete('product_categories', where: 'name = ?', whereArgs: [name]);
  }

  @override
  Future<List<Product>> getLowStockProducts({String? brand, String? category}) async {
    final hasFilters =
        (brand != null && brand.trim().isNotEmpty) ||
        (category != null && category.trim().isNotEmpty);

    if (!hasFilters) {
      final cached = _cache.get<List<Product>>(CacheKeys.lowStockProducts);
      if (cached != null) return cached;
    }

    final db = await _databaseHelper.database;
    final filter = _buildProductFilter(
      brand: brand,
      category: category,
      lowStockOnly: true,
    );
    final result = await db.query(
      'products',
      where: filter.$1,
      whereArgs: filter.$2,
      orderBy: 'quantity ASC',
    );
    final products = result.map((map) => Product.fromMap(map)).toList();

    if (!hasFilters) {
      _cache.set(CacheKeys.lowStockProducts, products, duration: const Duration(minutes: 2));
    }
    return products;
  }

  @override
  Future<int> createProduct(Product product) async {
    final db = await _databaseHelper.database;
    final result = await db.insert('products', product.toMap());
    
    _auditLogger.log(
      action: AuditAction.productCreated,
      entityType: 'product',
      entityId: result,
      entityName: product.name,
      details: 'Qty: ${product.quantity}, Price: ${product.price}',
    );
    
    // Invalidate product-related caches
    _cache.invalidateProductRelated();
    return result;
  }

  @override
  Future<int> updateProduct(Product product) async {
    final db = await _databaseHelper.database;
    
    // Get old product for audit
    final oldResult = await db.query('products', where: 'id = ?', whereArgs: [product.id]);
    final oldProduct = oldResult.isNotEmpty ? Product.fromMap(oldResult.first) : null;
    
    final result = await db.update(
      'products',
      {...product.toMap(), 'last_updated': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [product.id],
    );
    
    if (result > 0 && oldProduct != null) {
      _auditLogger.log(
        action: AuditAction.productUpdated,
        entityType: 'product',
        entityId: product.id,
        entityName: product.name,
        oldValue: 'Qty: ${oldProduct.quantity}, Price: ${oldProduct.price}',
        newValue: 'Qty: ${product.quantity}, Price: ${product.price}',
      );
    }
    
    // Invalidate caches
    _cache.invalidateProductRelated();
    _cache.invalidate(CacheKeys.productById(product.id!));
    if (product.barcode != null) {
      _cache.invalidate(CacheKeys.productByBarcode(product.barcode!));
    }
    return result;
  }

  @override
  Future<int> deleteProduct(int id) async {
    final db = await _databaseHelper.database;

    final productResult = await db.query('products', where: 'id = ?', whereArgs: [id]);
    if (productResult.isEmpty) return 0;

    final productName = productResult.first['name'] as String?;

    final salesCount = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM sales WHERE product_id = ?',
          [id],
        )) ??
        0;
    final cancelledSalesCount = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM cancelled_sales WHERE product_id = ?',
          [id],
        )) ??
        0;

    if (salesCount > 0 || cancelledSalesCount > 0) {
      throw ProductInUseException(
        salesCount: salesCount,
        cancelledSalesCount: cancelledSalesCount,
      );
    }

    final result = await db.transaction((txn) async {
      await txn.delete(
        'inventory_adjustments',
        where: 'product_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'price_list_items',
        where: 'product_id = ?',
        whereArgs: [id],
      );
      return txn.delete(
        'products',
        where: 'id = ?',
        whereArgs: [id],
      );
    });

    if (result > 0) {
      _auditLogger.log(
        action: AuditAction.productDeleted,
        entityType: 'product',
        entityId: id,
        entityName: productName,
      );
    }

    _cache.invalidateProductRelated();
    _cache.invalidate(CacheKeys.productById(id));
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
    _cache.invalidateProductRelated();
    _cache.invalidate(CacheKeys.productById(productId));
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
    _cache.invalidateProductRelated();
    _cache.invalidate(CacheKeys.productById(productId));
    
    return result;
  }
}
