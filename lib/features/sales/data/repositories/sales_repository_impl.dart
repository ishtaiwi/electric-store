import 'package:uuid/uuid.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/services/cache_service.dart';
import '../../../invoices/domain/entities/invoice.dart';
import '../../../invoices/domain/entities/sale_item.dart';
import '../../../invoices/domain/repositories/invoice_repository.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/entities/sale_record.dart';
import '../../domain/entities/account_ledger_profit_report.dart';
import '../../domain/entities/daily_customer_sales_report.dart';
import '../../domain/repositories/sales_repository.dart';

class SalesRepositoryImpl implements SalesRepository {
  final DatabaseHelper _databaseHelper;
  final InvoiceRepository _invoiceRepository;
  final CacheService _cache = CacheService();
  final _uuid = const Uuid();

  SalesRepositoryImpl(this._databaseHelper, this._invoiceRepository);

  static String _ledgerDocNumber(int id) => 'I${id.toString().padLeft(7, '0')}';

  /// Invalidate all caches affected by sales operations
  void _invalidateSalesCaches() {
    _cache.invalidateSalesRelated();
    _cache.invalidateProductRelated();
    _cache.invalidateCustomerRelated();
  }

  @override
  Future<Invoice> createSale({
    required List<CartItem> items,
    int? customerId,
    double discountAmount = 0,
    String paymentMethod = 'cash',
    double? paidAmount,
    int? userId,
    DateTime? saleDate,
    String? customerName,
  }) async {
    final db = await _databaseHelper.database;
    final recordDate = saleDate ?? DateTime.now();

    // Calculate totals
    double totalAmount = 0;
    double totalProfit = 0;
    
    for (final item in items) {
      totalAmount += item.totalPrice;
      totalProfit += item.profit;
    }

    final finalAmount = totalAmount - discountAmount;
    totalProfit -= discountAmount; // Adjust profit for discount
    
    // Walk-in sales only — customer sales go through addToCustomerAccount.
    if (customerId != null) {
      throw ArgumentError('Customer sales must use addToCustomerAccount');
    }

    // If paidAmount not specified, default to full payment
    final actualPaidAmount = paidAmount ?? finalAmount;

    // Generate invoice number
    final invoiceNumber = 'INV-${DateTime.now().millisecondsSinceEpoch}-${_uuid.v4().substring(0, 4).toUpperCase()}';

    // Use a transaction to ensure all-or-nothing for data integrity
    late final int invoiceId;
    final List<SaleItem> saleItems = [];

    await db.transaction((txn) async {
      invoiceId = await txn.insert('invoices', {
        'invoice_number': invoiceNumber,
        'customer_id': customerId,
        if (customerName != null) 'customer_name': customerName,
        'total_amount': totalAmount,
        'discount_amount': discountAmount,
        'final_amount': finalAmount,
        'paid_amount': actualPaidAmount,
        'total_profit': totalProfit,
        'payment_method': paymentMethod,
        'created_by': userId,
        'created_date': recordDate.toIso8601String(),
        'sale_date': recordDate.toIso8601String(),
      });

      await _insertSaleItems(
        txn: txn,
        items: items,
        invoiceId: invoiceId,
        customerId: customerId,
        discountAmount: discountAmount,
        totalAmount: totalAmount,
        recordDate: recordDate,
        saleItems: saleItems,
      );
    });

    _invalidateSalesCaches();

    return Invoice(
      id: invoiceId,
      invoiceNumber: invoiceNumber,
      customerId: customerId,
      customerName: customerName,
      totalAmount: totalAmount,
      discountAmount: discountAmount,
      finalAmount: finalAmount,
      paidAmount: actualPaidAmount,
      totalProfit: totalProfit,
      paymentMethod: paymentMethod,
      createdBy: userId,
      createdDate: recordDate,
      saleDate: recordDate,
      items: saleItems,
    );
  }

  @override
  Future<Invoice> addToCustomerAccount({
    required List<CartItem> items,
    required int customerId,
    String? customerName,
    double discountAmount = 0,
    DateTime? saleDate,
    int? userId,
    double? paidAmount,
    String paymentMethod = 'cash',
  }) async {
    final recordDate = saleDate ?? DateTime.now();
    final batchTotal = items.fold(0.0, (sum, item) => sum + item.totalPrice);
    final batchFinal = batchTotal - discountAmount;
    final actualPaid = paidAmount ?? batchFinal;

    final accountId = await _findAccountBatchForDate(customerId, recordDate);
    if (accountId != null) {
      return _appendToAccountInvoice(
        invoiceId: accountId,
        items: items,
        customerId: customerId,
        customerName: customerName,
        discountAmount: discountAmount,
        saleDate: recordDate,
        paidAmount: actualPaid,
        paymentMethod: paymentMethod,
        userId: userId,
      );
    }

    return _createAccountBatch(
      items: items,
      customerId: customerId,
      customerName: customerName,
      discountAmount: discountAmount,
      saleDate: recordDate,
      paidAmount: actualPaid,
      paymentMethod: paymentMethod,
      userId: userId,
    );
  }

  Future<Invoice> _createAccountBatch({
    required List<CartItem> items,
    required int customerId,
    String? customerName,
    double discountAmount = 0,
    required DateTime saleDate,
    double paidAmount = 0,
    String paymentMethod = 'cash',
    int? userId,
  }) async {
    final db = await _databaseHelper.database;

    double totalAmount = 0;
    double totalProfit = 0;
    for (final item in items) {
      totalAmount += item.totalPrice;
      totalProfit += item.profit;
    }
    final finalAmount = totalAmount - discountAmount;
    totalProfit -= discountAmount;

    late final int invoiceId;
    late final String storedInvoiceNumber;
    final List<SaleItem> saleItems = [];
    final tempNumber =
        'INV-${DateTime.now().millisecondsSinceEpoch}-${_uuid.v4().substring(0, 4).toUpperCase()}';

    await db.transaction((txn) async {
      invoiceId = await txn.insert('invoices', {
        'invoice_number': tempNumber,
        'customer_id': customerId,
        if (customerName != null) 'customer_name': customerName,
        'total_amount': totalAmount,
        'discount_amount': discountAmount,
        'final_amount': finalAmount,
        'paid_amount': 0,
        'total_profit': totalProfit,
        'payment_method': 'account',
        'created_by': userId,
        'created_date': saleDate.toIso8601String(),
        'sale_date': saleDate.toIso8601String(),
      });

      storedInvoiceNumber = _ledgerDocNumber(invoiceId);
      await txn.update(
        'invoices',
        {'invoice_number': storedInvoiceNumber},
        where: 'id = ?',
        whereArgs: [invoiceId],
      );

      await _insertSaleItems(
        txn: txn,
        items: items,
        invoiceId: invoiceId,
        customerId: customerId,
        discountAmount: discountAmount,
        totalAmount: totalAmount,
        recordDate: saleDate,
        saleItems: saleItems,
      );

      if (paidAmount > 0) {
        await txn.insert('customer_payments', {
          'invoice_id': invoiceId,
          'customer_id': customerId,
          'amount': paidAmount,
          'payment_date': saleDate.toIso8601String(),
          'payment_method': paymentMethod == 'cheque' ? 'cheque' : 'cash',
          'notes': 'Payment at checkout',
        });
        await _recalculateInvoicePaidAmount(txn, invoiceId);
      }
    });

    _invalidateSalesCaches();
    return (await _invoiceRepository.getInvoiceById(invoiceId))!;
  }

  Future<Invoice> _appendToAccountInvoice({
    required int invoiceId,
    required List<CartItem> items,
    required int customerId,
    String? customerName,
    double discountAmount = 0,
    required DateTime saleDate,
    double paidAmount = 0,
    String paymentMethod = 'cash',
    int? userId,
  }) async {
    final db = await _databaseHelper.database;

    double addedTotal = 0;
    double addedProfit = 0;
    for (final item in items) {
      addedTotal += item.totalPrice;
      addedProfit += item.profit;
    }
    addedProfit -= discountAmount;
    final addedFinal = addedTotal - discountAmount;

    final saleItems = <SaleItem>[];

    await db.transaction((txn) async {
      final invoiceResult =
          await txn.query('invoices', where: 'id = ?', whereArgs: [invoiceId]);
      if (invoiceResult.isEmpty) {
        throw Exception('Account invoice not found');
      }
      final current = invoiceResult.first;

      await _insertSaleItems(
        txn: txn,
        items: items,
        invoiceId: invoiceId,
        customerId: customerId,
        discountAmount: discountAmount,
        totalAmount: addedTotal,
        recordDate: saleDate,
        saleItems: saleItems,
      );

      final updateMap = <String, Object?>{
        'total_amount': (current['total_amount'] as num).toDouble() + addedTotal,
        'discount_amount':
            (current['discount_amount'] as num).toDouble() + discountAmount,
        'final_amount': (current['final_amount'] as num).toDouble() + addedFinal,
        'total_profit': (current['total_profit'] as num).toDouble() + addedProfit,
        'sale_date': saleDate.toIso8601String(),
        'payment_method': 'account',
      };
      if (customerName != null) {
        updateMap['customer_name'] = customerName;
      }

      await txn.update('invoices', updateMap, where: 'id = ?', whereArgs: [invoiceId]);

      if (paidAmount > 0) {
        await txn.insert('customer_payments', {
          'invoice_id': invoiceId,
          'customer_id': customerId,
          'amount': paidAmount,
          'payment_date': saleDate.toIso8601String(),
          'payment_method': paymentMethod == 'cheque' ? 'cheque' : 'cash',
          'notes': 'Payment at checkout',
        });
        await _recalculateInvoicePaidAmount(txn, invoiceId);
      }
    });

    _invalidateSalesCaches();
    return (await _invoiceRepository.getInvoiceById(invoiceId))!;
  }

  Future<void> _insertSaleItems({
    required dynamic txn,
    required List<CartItem> items,
    required int invoiceId,
    required int? customerId,
    required double discountAmount,
    required double totalAmount,
    required DateTime recordDate,
    required List<SaleItem> saleItems,
  }) async {
    for (final item in items) {
      final itemTotal = item.totalPrice;
      final itemDiscount =
          totalAmount > 0 ? (discountAmount / totalAmount) * itemTotal : 0.0;
      final itemFinal = itemTotal - itemDiscount;
      final itemProfit = item.profit - itemDiscount;
      final isRealProduct = item.product.id != null && item.product.id! > 0;

      final saleId = await txn.insert('sales', {
        'product_id': isRealProduct ? item.product.id : null,
        'barcode': item.product.barcode,
        'product_name': item.product.name,
        'quantity': item.quantity,
        'cost_price': item.product.costPrice,
        'sale_price': item.unitPrice,
        'total_amount': itemTotal,
        'profit': itemProfit,
        'customer_id': customerId,
        'discount_amount': itemDiscount,
        'final_amount': itemFinal,
        'invoice_id': invoiceId,
        'sale_date': recordDate.toIso8601String(),
        if (item.note != null) 'note': item.note,
      });

      if (isRealProduct) {
        await txn.rawUpdate(
          'UPDATE products SET quantity = quantity - ?, last_updated = ? WHERE id = ?',
          [item.quantity, DateTime.now().toIso8601String(), item.product.id],
        );
      }

      saleItems.add(SaleItem(
        id: saleId,
        productId: isRealProduct ? item.product.id : null,
        barcode: item.product.barcode,
        productName: item.product.name,
        quantity: item.quantity,
        costPrice: item.product.costPrice,
        salePrice: item.unitPrice,
        totalAmount: itemTotal,
        profit: itemProfit,
        discountAmount: itemDiscount,
        finalAmount: itemFinal,
        invoiceId: invoiceId,
        saleDate: recordDate,
        note: item.note,
      ));
    }
  }

  Future<void> _recalculateInvoicePaidAmount(dynamic txn, int invoiceId) async {
    final result = await txn.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM customer_payments
      WHERE invoice_id = ? AND COALESCE(payment_method, 'cash') != 'discount'
      ''',
      [invoiceId],
    );
    final total = (result.first['total'] as num).toDouble();
    await txn.update(
      'invoices',
      {'paid_amount': total},
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
  }

  Future<int?> _findAccountBatchForDate(int customerId, DateTime date) async {
    final db = await _databaseHelper.database;
    final day = DateTime(date.year, date.month, date.day).toIso8601String();
    final result = await db.rawQuery('''
      SELECT id FROM invoices
      WHERE customer_id = ?
        AND payment_method = 'account'
        AND date(COALESCE(sale_date, created_date)) = date(?)
      ORDER BY id DESC
      LIMIT 1
    ''', [customerId, day]);
    if (result.isEmpty) return null;
    return result.first['id'] as int?;
  }

  Future<int?> _findCustomerAccountAnchor(int customerId) async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT id FROM invoices
      WHERE customer_id = ? AND payment_method = 'account'
      ORDER BY id ASC
      LIMIT 1
    ''', [customerId]);
    if (result.isEmpty) return null;
    return result.first['id'] as int?;
  }

  Future<void> _recalculateInvoiceTotals(dynamic txn, int invoiceId) async {
    final sales = await txn.query('sales', where: 'invoice_id = ?', whereArgs: [invoiceId]);
    final invoiceRows =
        await txn.query('invoices', where: 'id = ?', whereArgs: [invoiceId]);
    if (invoiceRows.isEmpty) return;

    final discount = (invoiceRows.first['discount_amount'] as num?)?.toDouble() ?? 0;
    double totalAmount = 0;
    double totalProfit = 0;
    for (final sale in sales) {
      totalAmount += (sale['total_amount'] as num).toDouble();
      totalProfit += (sale['profit'] as num?)?.toDouble() ?? 0;
    }
    final finalAmount = totalAmount - discount;

    await txn.update(
      'invoices',
      {
        'total_amount': totalAmount,
        'final_amount': finalAmount,
        'total_profit': totalProfit - discount,
      },
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
  }

  @override
  Future<int> deleteAccountSaleLine(int saleId) async {
    final db = await _databaseHelper.database;

    final sales = await db.query('sales', where: 'id = ?', whereArgs: [saleId]);
    if (sales.isEmpty) return 0;
    final sale = sales.first;
    final invoiceId = sale['invoice_id'] as int?;

    final result = await db.transaction((txn) async {
      final productId = sale['product_id'];
      final quantity = sale['quantity'] as int? ?? 0;
      if (productId != null) {
        await txn.rawUpdate(
          'UPDATE products SET quantity = quantity + ?, last_updated = ? WHERE id = ?',
          [quantity, DateTime.now().toIso8601String(), productId],
        );
      }

      final deleted = await txn.delete('sales', where: 'id = ?', whereArgs: [saleId]);
      if (deleted > 0 && invoiceId != null) {
        final remaining = await txn.query(
          'sales',
          where: 'invoice_id = ?',
          whereArgs: [invoiceId],
        );
        if (remaining.isEmpty) {
          await txn.delete('customer_payments', where: 'invoice_id = ?', whereArgs: [invoiceId]);
          await txn.delete('invoices', where: 'id = ?', whereArgs: [invoiceId]);
        } else {
          await _recalculateInvoiceTotals(txn, invoiceId);
        }
      }
      return deleted;
    });

    if (result > 0) _invalidateSalesCaches();
    return result;
  }

  @override
  Future<int> cancelSale(int saleId, String reason, int? userId) async {
    final db = await _databaseHelper.database;

    // Get sale details
    final sales = await db.query(
      'sales',
      where: 'id = ?',
      whereArgs: [saleId],
    );

    if (sales.isEmpty) return 0;
    final sale = sales.first;

    final cancelResult = await db.transaction((txn) async {
      // Insert cancelled sale record
      await txn.insert('cancelled_sales', {
        'original_sale_id': saleId,
        'product_id': sale['product_id'],
        'barcode': sale['barcode'],
        'product_name': sale['product_name'],
        'quantity': sale['quantity'],
        'cost_price': sale['cost_price'],
        'sale_price': sale['sale_price'],
        'total_amount': sale['total_amount'],
        'profit': sale['profit'],
        'cancelled_by': userId,
        'reason': reason,
      });

      // Restore product quantity
      final quantity = sale['quantity'] as int? ?? 0;
      final productId = sale['product_id'];
      if (productId != null) {
        await txn.rawUpdate(
          'UPDATE products SET quantity = quantity + ?, last_updated = ? WHERE id = ?',
          [quantity, DateTime.now().toIso8601String(), productId],
        );
      }

      // Delete original sale
      return await txn.delete('sales', where: 'id = ?', whereArgs: [saleId]);
    });

    _invalidateSalesCaches();
    return cancelResult;
  }

  @override
  Future<List<Map<String, dynamic>>> getSalesToday() async {
    final db = await _databaseHelper.database;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    
    return await db.rawQuery('''
      SELECT s.*, p.name as product_name_current
      FROM sales s
      LEFT JOIN products p ON s.product_id = p.id
      WHERE date(s.sale_date) = date(?)
      ORDER BY s.sale_date DESC
    ''', [startOfDay.toIso8601String()]);
  }

  @override
  Future<double> getTodaySalesTotal() async {
    final db = await _databaseHelper.database;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(final_amount), 0) as total
      FROM invoices
      WHERE date(created_date) = date(?)
    ''', [startOfDay.toIso8601String()]);
    
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  @override
  Future<double> getTodayProfit() async {
    final db = await _databaseHelper.database;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    
    // Only registered catalog products — custom sale lines have product_id NULL
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(profit), 0) as profit
      FROM sales
      WHERE date(sale_date) = date(?)
        AND product_id IS NOT NULL
    ''', [startOfDay.toIso8601String()]);
    
    return (result.first['profit'] as num?)?.toDouble() ?? 0;
  }

  @override
  Future<List<SaleRecord>> getAllSaleRecords({
    String? searchQuery,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await _databaseHelper.database;

    final hasSearch = searchQuery != null && searchQuery.trim().isNotEmpty;
    final searchTerm = hasSearch ? '%${searchQuery.trim()}%' : null;

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (hasSearch) {
      whereClause = '''
        WHERE s.product_name LIKE ?
           OR s.barcode LIKE ?
           OR c.name LIKE ?
           OR i.invoice_number LIKE ?
      ''';
      whereArgs = [searchTerm, searchTerm, searchTerm, searchTerm];
    }

    final result = await db.rawQuery('''
      SELECT s.*,
             c.name AS customer_name,
             i.invoice_number AS invoice_number
      FROM sales s
      LEFT JOIN customers c ON s.customer_id = c.id
      LEFT JOIN invoices i ON s.invoice_id = i.id
      $whereClause
      ORDER BY s.sale_date DESC
      LIMIT ? OFFSET ?
    ''', [...whereArgs, limit, offset]);

    return result.map((map) => SaleRecord.fromMap(map)).toList();
  }

  @override
  Future<int> getSaleRecordsCount({String? searchQuery}) async {
    final db = await _databaseHelper.database;

    final hasSearch = searchQuery != null && searchQuery.trim().isNotEmpty;
    final searchTerm = hasSearch ? '%${searchQuery.trim()}%' : null;

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (hasSearch) {
      whereClause = '''
        WHERE s.product_name LIKE ?
           OR s.barcode LIKE ?
           OR c.name LIKE ?
           OR i.invoice_number LIKE ?
      ''';
      whereArgs = [searchTerm, searchTerm, searchTerm, searchTerm];
    }

    final result = await db.rawQuery('''
      SELECT COUNT(*) AS cnt
      FROM sales s
      LEFT JOIN customers c ON s.customer_id = c.id
      LEFT JOIN invoices i ON s.invoice_id = i.id
      $whereClause
    ''', whereArgs);

    return (result.first['cnt'] as int?) ?? 0;
  }

  @override
  Future<AccountLedgerProfitReport> getAccountLedgerProfitReport({
    int? customerId,
  }) async {
    final db = await _databaseHelper.database;

    final args = <dynamic>[];
    // Same scope as كشف الحساب: every invoice linked to a customer
    // (cash/credit/account), not only payment_method = 'account'.
    final where = StringBuffer('''
      i.customer_id IS NOT NULL
      AND s.product_id IS NOT NULL
    ''');
    if (customerId != null) {
      where.write(' AND COALESCE(s.customer_id, i.customer_id) = ?');
      args.add(customerId);
    }

    final rows = await db.rawQuery('''
      SELECT
             s.id,
             s.product_id,
             s.barcode,
             s.product_name,
             s.quantity,
             s.cost_price,
             s.sale_price,
             s.total_amount,
             ROUND(
               (s.sale_price - s.cost_price) * s.quantity
               - COALESCE(s.discount_amount, 0),
               2
             ) AS profit,
             s.discount_amount,
             s.final_amount,
             s.invoice_id,
             s.note,
             COALESCE(i.sale_date, i.created_date, s.sale_date) AS sale_date,
             COALESCE(s.customer_id, i.customer_id) AS customer_id,
             COALESCE(c.name, i.customer_name, '-') AS customer_name,
             i.invoice_number AS invoice_number
      FROM sales s
      INNER JOIN invoices i ON s.invoice_id = i.id
      LEFT JOIN customers c
        ON c.id = COALESCE(s.customer_id, i.customer_id)
      WHERE $where
      ORDER BY customer_name COLLATE NOCASE ASC,
               sale_date DESC
    ''', args);

    if (rows.isEmpty) {
      return AccountLedgerProfitReport.empty();
    }

    final lines = rows.map(AccountLedgerProfitLine.fromMap).toList();

    final byCustomerMap = <int, AccountLedgerProfitByCustomer>{};
    double totalSales = 0;
    double totalProfit = 0;

    for (final line in lines) {
      totalSales += line.totalAmount;
      totalProfit += line.profit;
      final id = line.customerId ?? 0;
      final existing = byCustomerMap[id];
      if (existing == null) {
        byCustomerMap[id] = AccountLedgerProfitByCustomer(
          customerId: id,
          customerName: line.customerName,
          itemCount: 1,
          totalSales: line.totalAmount,
          totalProfit: line.profit,
        );
      } else {
        byCustomerMap[id] = AccountLedgerProfitByCustomer(
          customerId: existing.customerId,
          customerName: existing.customerName,
          itemCount: existing.itemCount + 1,
          totalSales: existing.totalSales + line.totalAmount,
          totalProfit: existing.totalProfit + line.profit,
        );
      }
    }

    final byCustomer = byCustomerMap.values.toList()
      ..sort((a, b) => b.totalProfit.compareTo(a.totalProfit));

    return AccountLedgerProfitReport(
      byCustomer: byCustomer,
      lines: lines,
      totalSales: totalSales,
      totalProfit: totalProfit,
      itemCount: lines.length,
    );
  }

  @override
  Future<DailyCustomerSalesReport> getDailyCustomerSalesReport({
    DateTime? fromDate,
    DateTime? toDate,
    int? customerId,
  }) async {
    final now = DateTime.now();
    final from = fromDate ?? DateTime(now.year, now.month, now.day);
    final to = toDate ?? DateTime(now.year, now.month, now.day);
    final fromStart = DateTime(from.year, from.month, from.day);
    final toEnd = DateTime(to.year, to.month, to.day);

    final db = await _databaseHelper.database;
    final args = <dynamic>[
      fromStart.toIso8601String(),
      toEnd.toIso8601String(),
    ];

    // Same customer scope as كشف الحساب; order matches ledger (date ASC, invoice ASC).
    final where = StringBuffer('''
      i.customer_id IS NOT NULL
      AND date(COALESCE(i.sale_date, i.created_date, s.sale_date)) >= date(?)
      AND date(COALESCE(i.sale_date, i.created_date, s.sale_date)) <= date(?)
    ''');
    if (customerId != null) {
      where.write(' AND COALESCE(s.customer_id, i.customer_id) = ?');
      args.add(customerId);
    }

    final rows = await db.rawQuery('''
      SELECT
             s.id,
             s.product_id,
             s.barcode,
             s.product_name,
             s.quantity,
             s.sale_price,
             s.total_amount,
             s.discount_amount,
             s.final_amount,
             s.invoice_id,
             s.note,
             COALESCE(i.sale_date, i.created_date, s.sale_date) AS sale_date,
             COALESCE(s.customer_id, i.customer_id) AS customer_id,
             COALESCE(c.name, i.customer_name, '-') AS customer_name,
             i.invoice_number AS invoice_number
      FROM sales s
      INNER JOIN invoices i ON s.invoice_id = i.id
      LEFT JOIN customers c
        ON c.id = COALESCE(s.customer_id, i.customer_id)
      WHERE $where
      ORDER BY customer_name COLLATE NOCASE ASC,
               COALESCE(i.sale_date, i.created_date, s.sale_date) ASC,
               i.id ASC,
               s.id ASC
    ''', args);

    if (rows.isEmpty) {
      return DailyCustomerSalesReport.empty(fromDate: fromStart, toDate: toEnd);
    }

    final lines = rows.map(DailyCustomerSaleLine.fromMap).toList();
    final groups = <int, List<DailyCustomerSaleLine>>{};
    final names = <int, String>{};
    double totalAmount = 0;

    for (final line in lines) {
      totalAmount += line.finalAmount;
      final id = line.customerId ?? 0;
      groups.putIfAbsent(id, () => []).add(line);
      names[id] = line.customerName;
    }

    // Preserve ledger-like customer order from the sorted query.
    final byCustomer = <DailyCustomerSalesGroup>[];
    final seen = <int>{};
    for (final line in lines) {
      final id = line.customerId ?? 0;
      if (!seen.add(id)) continue;
      final customerLines = groups[id]!;
      byCustomer.add(DailyCustomerSalesGroup(
        customerId: id,
        customerName: names[id] ?? '-',
        itemCount: customerLines.length,
        totalAmount: customerLines.fold<double>(0, (s, l) => s + l.finalAmount),
        lines: customerLines,
      ));
    }

    return DailyCustomerSalesReport(
      byCustomer: byCustomer,
      lines: lines,
      totalAmount: totalAmount,
      itemCount: lines.length,
      fromDate: fromStart,
      toDate: toEnd,
    );
  }
}
