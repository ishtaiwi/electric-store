import '../../../../core/database/database_helper.dart';
import '../../../../core/services/cache_service.dart';
import '../../domain/entities/price_list.dart';
import '../../domain/entities/price_list_item.dart';
import '../../domain/repositories/price_list_repository.dart';

class PriceListRepositoryImpl implements PriceListRepository {
  final DatabaseHelper _databaseHelper;
  final CacheService _cache = CacheService();
  static const _priceListsCacheKey = 'all_price_lists';

  PriceListRepositoryImpl(this._databaseHelper);

  void _invalidateCache() {
    _cache.invalidate(_priceListsCacheKey);
  }

  @override
  Future<List<PriceList>> getAllPriceLists() async {
    final cached = _cache.get<List<PriceList>>(_priceListsCacheKey);
    if (cached != null) return cached;

    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT pl.*, c.name as customer_name,
        (SELECT COUNT(*) FROM price_list_items WHERE price_list_id = pl.id) as item_count
      FROM price_lists pl
      LEFT JOIN customers c ON pl.customer_id = c.id
      ORDER BY pl.created_date DESC
    ''');

    final priceLists = result.map((map) => PriceList.fromMap(map)).toList();

    _cache.set(_priceListsCacheKey, priceLists, duration: const Duration(minutes: 1));
    return priceLists;
  }

  @override
  Future<PriceList?> getPriceListById(int id) async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT pl.*, c.name as customer_name
      FROM price_lists pl
      LEFT JOIN customers c ON pl.customer_id = c.id
      WHERE pl.id = ?
    ''', [id]);

    if (result.isEmpty) return null;

    final priceList = PriceList.fromMap(result.first);
    final items = await getPriceListItems(id);

    return priceList.copyWith(items: items);
  }

  @override
  Future<List<PriceList>> getPriceListsByCustomer(int customerId) async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT pl.*, c.name as customer_name
      FROM price_lists pl
      LEFT JOIN customers c ON pl.customer_id = c.id
      WHERE pl.customer_id = ?
      ORDER BY pl.created_date DESC
    ''', [customerId]);
    return result.map((map) => PriceList.fromMap(map)).toList();
  }

  @override
  Future<List<PriceListItem>> getPriceListItems(int priceListId) async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT pli.*,
        COALESCE(pli.product_name, p.name, 'Unknown Product') as product_name
      FROM price_list_items pli
      LEFT JOIN products p ON pli.product_id = p.id
      WHERE pli.price_list_id = ?
      ORDER BY pli.id ASC
    ''', [priceListId]);
    return result.map((map) => PriceListItem.fromMap(map)).toList();
  }

  @override
  Future<int> createPriceList(PriceList priceList, List<PriceListItem> items) async {
    final db = await _databaseHelper.database;

    // No inventory changes - this is just a price quotation
    final now = DateTime.now().toIso8601String();
    final priceListId = await db.insert('price_lists', {
      'title': priceList.title,
      'customer_id': priceList.customerId,
      'notes': priceList.notes,
      'created_date': now,
      'updated_date': now,
    });

    // Insert items
    for (final item in items) {
      await db.insert('price_list_items', {
        'price_list_id': priceListId,
        'product_id': item.productId,
        'product_name': item.productName,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
        'total_price': item.totalPrice,
        'notes': item.notes,
      });
    }

    _invalidateCache();
    return priceListId;
  }

  @override
  Future<int> updatePriceList(PriceList priceList, List<PriceListItem> items) async {
    final db = await _databaseHelper.database;

    // Update price list metadata
    await db.update(
      'price_lists',
      {
        'title': priceList.title,
        'customer_id': priceList.customerId,
        'notes': priceList.notes,
        'updated_date': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [priceList.id],
    );

    // Delete old items and re-insert (simpler than tracking changes)
    await db.delete('price_list_items',
        where: 'price_list_id = ?', whereArgs: [priceList.id]);

    for (final item in items) {
      await db.insert('price_list_items', {
        'price_list_id': priceList.id,
        'product_id': item.productId,
        'product_name': item.productName,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
        'total_price': item.totalPrice,
        'notes': item.notes,
      });
    }

    _invalidateCache();
    return priceList.id!;
  }

  @override
  Future<int> deletePriceList(int id) async {
    final db = await _databaseHelper.database;

    // Delete items first
    await db.delete('price_list_items',
        where: 'price_list_id = ?', whereArgs: [id]);

    // Delete price list - NO inventory restoration needed
    final result = await db.delete('price_lists', where: 'id = ?', whereArgs: [id]);
    _invalidateCache();
    return result;
  }

  @override
  Future<List<PriceList>> searchPriceLists(String query) async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT pl.*, c.name as customer_name
      FROM price_lists pl
      LEFT JOIN customers c ON pl.customer_id = c.id
      WHERE pl.title LIKE ? OR c.name LIKE ?
      ORDER BY pl.created_date DESC
    ''', ['%$query%', '%$query%']);
    return result.map((map) => PriceList.fromMap(map)).toList();
  }
}
