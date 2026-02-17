import '../../../../core/database/database_helper.dart';
import '../../../../core/services/cache_service.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/sale_item.dart';
import '../../domain/repositories/invoice_repository.dart';

class InvoiceRepositoryImpl implements InvoiceRepository {
  final DatabaseHelper _databaseHelper;
  final CacheService _cache = CacheService();
  static const _invoicesCacheKey = 'all_invoices';

  InvoiceRepositoryImpl(this._databaseHelper);
  
  void _invalidateCache() {
    _cache.invalidate(_invoicesCacheKey);
  }

  @override
  Future<List<Invoice>> getAllInvoices() async {
    // Check cache first
    final cached = _cache.get<List<Invoice>>(_invoicesCacheKey);
    if (cached != null) return cached;
    
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT i.*, c.name as customer_name
      FROM invoices i
      LEFT JOIN customers c ON i.customer_id = c.id
      ORDER BY i.created_date DESC
    ''');
    final invoices = result.map((map) => Invoice.fromMap(map)).toList();
    
    // Cache for 1 minute
    _cache.set(_invoicesCacheKey, invoices, duration: const Duration(minutes: 1));
    return invoices;
  }

  @override
  Future<Invoice?> getInvoiceById(int id) async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT i.*, c.name as customer_name
      FROM invoices i
      LEFT JOIN customers c ON i.customer_id = c.id
      WHERE i.id = ?
    ''', [id]);

    if (result.isEmpty) return null;

    final invoice = Invoice.fromMap(result.first);

    // Get sale items for this invoice
    final items = await db.query(
      'sales',
      where: 'invoice_id = ?',
      whereArgs: [id],
    );

    return invoice.copyWith(
      items: items.map((map) => SaleItem.fromMap(map)).toList(),
    );
  }

  @override
  Future<Invoice?> getInvoiceByNumber(String invoiceNumber) async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT i.*, c.name as customer_name
      FROM invoices i
      LEFT JOIN customers c ON i.customer_id = c.id
      WHERE i.invoice_number = ?
    ''', [invoiceNumber]);

    if (result.isEmpty) return null;

    final invoice = Invoice.fromMap(result.first);

    // Get sale items for this invoice
    final items = await db.query(
      'sales',
      where: 'invoice_id = ?',
      whereArgs: [invoice.id],
    );

    return invoice.copyWith(
      items: items.map((map) => SaleItem.fromMap(map)).toList(),
    );
  }

  @override
  Future<List<Invoice>> getInvoicesByCustomer(int customerId) async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT i.*, c.name as customer_name
      FROM invoices i
      LEFT JOIN customers c ON i.customer_id = c.id
      WHERE i.customer_id = ?
      ORDER BY i.created_date DESC
    ''', [customerId]);
    return result.map((map) => Invoice.fromMap(map)).toList();
  }

  @override
  Future<List<Invoice>> getInvoicesByDateRange(DateTime start, DateTime end) async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT i.*, c.name as customer_name
      FROM invoices i
      LEFT JOIN customers c ON i.customer_id = c.id
      WHERE date(i.created_date) BETWEEN date(?) AND date(?)
      ORDER BY i.created_date DESC
    ''', [start.toIso8601String(), end.toIso8601String()]);
    return result.map((map) => Invoice.fromMap(map)).toList();
  }

  @override
  Future<List<Invoice>> getInvoicesToday() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return getInvoicesByDateRange(startOfDay, endOfDay);
  }

  @override
  Future<List<SaleItem>> getInvoiceItems(int invoiceId) async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT s.*, p.name as product_name
      FROM sales s
      LEFT JOIN products p ON s.product_id = p.id
      WHERE s.invoice_id = ?
    ''', [invoiceId]);
    return result.map((map) => SaleItem.fromMap(map)).toList();
  }

  @override
  Future<int> deleteInvoice(int id) async {
    final db = await _databaseHelper.database;

    // Get all sales for this invoice to restore quantities
    final sales = await db.query(
      'sales',
      where: 'invoice_id = ?',
      whereArgs: [id],
    );

    // Restore product quantities
    for (final sale in sales) {
      await db.rawUpdate(
        'UPDATE products SET quantity = quantity + ?, last_updated = ? WHERE id = ?',
        [sale['quantity'], DateTime.now().toIso8601String(), sale['product_id']],
      );
    }

    // Delete sales
    await db.delete('sales', where: 'invoice_id = ?', whereArgs: [id]);

    // Delete invoice
    final result = await db.delete('invoices', where: 'id = ?', whereArgs: [id]);
    _invalidateCache();
    return result;
  }

  @override
  Future<int> updateInvoicePaidAmount(int invoiceId, double paidAmount) async {
    final db = await _databaseHelper.database;
    final result = await db.update(
      'invoices',
      {'paid_amount': paidAmount},
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
    _invalidateCache();
    return result;
  }

  @override
  Future<List<Invoice>> getInvoicesPaginated({int limit = 50, int offset = 0}) async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT i.*, c.name as customer_name
      FROM invoices i
      LEFT JOIN customers c ON i.customer_id = c.id
      ORDER BY i.created_date DESC
      LIMIT ? OFFSET ?
    ''', [limit, offset]);
    return result.map((map) => Invoice.fromMap(map)).toList();
  }

  @override
  Future<int> getInvoicesCount() async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM invoices');
    return result.first['count'] as int;
  }
}
