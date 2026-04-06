import '../../../../core/database/database_helper.dart';
import '../../../../core/services/cache_service.dart';
import '../../../../core/services/audit_logger_service.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/sale_item.dart';
import '../../domain/repositories/invoice_repository.dart';

class InvoiceRepositoryImpl implements InvoiceRepository {
  final DatabaseHelper _databaseHelper;
  final CacheService _cache = CacheService();
  final AuditLoggerService _auditLogger = AuditLoggerService();
  static const _invoicesCacheKey = 'all_invoices';

  InvoiceRepositoryImpl(this._databaseHelper);
  
  void _invalidateCache() {
    _cache.invalidate(_invoicesCacheKey);
    _cache.invalidateSalesRelated();
    _cache.invalidateCustomerRelated();
    _cache.invalidateProductRelated();
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
      SELECT s.*,
        COALESCE(s.product_name, p.name, 'Unknown Product') as product_name
      FROM sales s
      LEFT JOIN products p ON s.product_id = p.id
      WHERE s.invoice_id = ?
    ''', [invoiceId]);
    return result.map((map) => SaleItem.fromMap(map)).toList();
  }

  @override
  Future<int> deleteInvoice(int id) async {
    final db = await _databaseHelper.database;

    // Get invoice info for audit log
    final invoiceResult = await db.query('invoices', where: 'id = ?', whereArgs: [id]);
    final invoiceNumber = invoiceResult.isNotEmpty 
        ? invoiceResult.first['invoice_number'] as String? 
        : null;
    final finalAmount = invoiceResult.isNotEmpty 
        ? invoiceResult.first['final_amount'] 
        : null;

    // Get all sales for this invoice to restore quantities
    final sales = await db.query(
      'sales',
      where: 'invoice_id = ?',
      whereArgs: [id],
    );

    // Restore product quantities (only for real products, not custom items)
    for (final sale in sales) {
      final productId = sale['product_id'];
      if (productId != null) {
        await db.rawUpdate(
          'UPDATE products SET quantity = quantity + ?, last_updated = ? WHERE id = ?',
          [sale['quantity'], DateTime.now().toIso8601String(), productId],
        );
      }
    }

    // Delete sales
    await db.delete('sales', where: 'invoice_id = ?', whereArgs: [id]);

    // Delete invoice
    final result = await db.delete('invoices', where: 'id = ?', whereArgs: [id]);
    
    if (result > 0) {
      _auditLogger.log(
        action: AuditAction.invoiceDeleted,
        entityType: 'invoice',
        entityId: id,
        entityName: invoiceNumber,
        details: 'Amount: $finalAmount, Items restored to inventory',
      );
    }
    
    _invalidateCache();
    return result;
  }

  @override
  Future<Invoice?> updateInvoice({
    required int invoiceId,
    required List<SaleItem> updatedItems,
    double discountAmount = 0,
    String? paymentMethod,
    double? paidAmount,
  }) async {
    final db = await _databaseHelper.database;

    // Get existing invoice
    final invoiceResult = await db.query('invoices', where: 'id = ?', whereArgs: [invoiceId]);
    if (invoiceResult.isEmpty) return null;

    final oldInvoice = Invoice.fromMap(invoiceResult.first);

    // Get existing sale items for this invoice
    final oldSalesResult = await db.query('sales', where: 'invoice_id = ?', whereArgs: [invoiceId]);
    final oldItems = oldSalesResult.map((m) => SaleItem.fromMap(m)).toList();

    // Calculate new totals
    double newTotalAmount = 0;
    double newTotalProfit = 0;
    for (final item in updatedItems) {
      newTotalAmount += item.totalAmount;
      newTotalProfit += item.profit;
    }
    final newFinalAmount = newTotalAmount - discountAmount;
    newTotalProfit -= discountAmount;
    final newPaymentMethod = paymentMethod ?? oldInvoice.paymentMethod;
    final newPaidAmount = paidAmount ?? oldInvoice.paidAmount;

    await db.transaction((txn) async {
      // 1. Restore inventory for ALL old items (return quantities to stock)
      for (final oldItem in oldItems) {
        if (oldItem.productId != null) {
          await txn.rawUpdate(
            'UPDATE products SET quantity = quantity + ?, last_updated = ? WHERE id = ?',
            [oldItem.quantity, DateTime.now().toIso8601String(), oldItem.productId],
          );
        }
      }

      // 2. Delete all old sale records for this invoice
      await txn.delete('sales', where: 'invoice_id = ?', whereArgs: [invoiceId]);

      // 3. Insert new sale records and deduct inventory for new items
      for (final item in updatedItems) {
        final itemTotal = item.totalAmount;
        final itemDiscount = newTotalAmount > 0 ? (discountAmount / newTotalAmount) * itemTotal : 0.0;
        final itemFinal = itemTotal - itemDiscount;
        final itemProfit = item.profit - itemDiscount;

        final isRealProduct = item.productId != null;

        await txn.insert('sales', {
          'product_id': isRealProduct ? item.productId : null,
          'barcode': item.barcode,
          'product_name': item.productName,
          'quantity': item.quantity,
          'cost_price': item.costPrice,
          'sale_price': item.salePrice,
          'total_amount': itemTotal,
          'profit': itemProfit,
          'customer_id': oldInvoice.customerId,
          'discount_amount': itemDiscount,
          'final_amount': itemFinal,
          'invoice_id': invoiceId,
          if (item.note != null) 'note': item.note,
        });

        // Deduct from inventory for real products
        if (isRealProduct) {
          await txn.rawUpdate(
            'UPDATE products SET quantity = quantity - ?, last_updated = ? WHERE id = ?',
            [item.quantity, DateTime.now().toIso8601String(), item.productId],
          );
        }
      }

      // 4. Update the invoice record
      await txn.update('invoices', {
        'total_amount': newTotalAmount,
        'discount_amount': discountAmount,
        'final_amount': newFinalAmount,
        'paid_amount': newPaidAmount,
        'total_profit': newTotalProfit,
        'payment_method': newPaymentMethod,
      }, where: 'id = ?', whereArgs: [invoiceId]);
    });

    _auditLogger.log(
      action: AuditAction.invoiceUpdated,
      entityType: 'invoice',
      entityId: invoiceId,
      entityName: oldInvoice.invoiceNumber,
      oldValue: 'Items: ${oldItems.length}, Total: ${oldInvoice.finalAmount}',
      newValue: 'Items: ${updatedItems.length}, Total: $newFinalAmount',
      details: 'Invoice items updated with inventory adjustment',
    );

    _invalidateCache();

    // Return the updated invoice
    return await getInvoiceById(invoiceId);
  }

  @override
  Future<int> updateInvoicePaidAmount(int invoiceId, double paidAmount) async {
    final db = await _databaseHelper.database;
    
    // Get old paid amount for audit
    final oldInvoice = await db.query('invoices', where: 'id = ?', whereArgs: [invoiceId]);
    final oldPaidAmount = oldInvoice.isNotEmpty 
        ? oldInvoice.first['paid_amount'] 
        : 0;
    final invoiceNumber = oldInvoice.isNotEmpty 
        ? oldInvoice.first['invoice_number'] as String?
        : null;
    
    final result = await db.update(
      'invoices',
      {'paid_amount': paidAmount},
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
    
    if (result > 0) {
      _auditLogger.log(
        action: AuditAction.paymentRecorded,
        entityType: 'invoice',
        entityId: invoiceId,
        entityName: invoiceNumber,
        oldValue: oldPaidAmount.toString(),
        newValue: paidAmount.toString(),
        details: 'Payment amount updated',
      );
    }
    
    _invalidateCache();
    return result;
  }

  @override
  Future<int> updateInvoiceNotes(int invoiceId, String? notes) async {
    final db = await _databaseHelper.database;
    
    final result = await db.update(
      'invoices',
      {'notes': notes},
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
    
    if (result > 0) {
      _auditLogger.log(
        action: AuditAction.invoiceUpdated,
        entityType: 'invoice',
        entityId: invoiceId,
        details: 'Invoice notes updated',
      );
    }
    
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
