import '../../../../core/database/database_helper.dart';
import '../../../../core/services/cache_service.dart';
import '../../../../core/services/audit_logger_service.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/customer_ledger.dart';
import '../../domain/entities/customer_ledger_entry.dart';
import '../../domain/entities/customer_ledger_filters.dart';
import '../../domain/entities/customer_payment.dart';
import '../../domain/repositories/customer_repository.dart';
import '../../../invoices/domain/entities/invoice.dart';
import '../../../invoices/domain/entities/sale_item.dart';

class CustomerRepositoryImpl implements CustomerRepository {
  final DatabaseHelper _databaseHelper;
  final CacheService _cache = CacheService();
  final AuditLoggerService _auditLogger = AuditLoggerService();
  static const _customersCacheKey = 'all_customers';

  CustomerRepositoryImpl(this._databaseHelper);

  String _formatInvoiceDoc(int id) => 'I${id.toString().padLeft(7, '0')}';
  String _formatReceiptDoc(int id) => 'R${id.toString().padLeft(7, '0')}';
  String _formatDiscountDoc(int id) => 'D${id.toString().padLeft(7, '0')}';

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool _isBeforeDay(DateTime date, DateTime dayStart) =>
      _dateOnly(date).isBefore(_dateOnly(dayStart));

  static bool _isAfterDay(DateTime date, DateTime dayEnd) =>
      _dateOnly(date).isAfter(_dateOnly(dayEnd));

  static const _balanceJoinFrom = '''
FROM customers c
LEFT JOIN (
  SELECT customer_id, COALESCE(SUM(final_amount), 0) AS invoiced
  FROM invoices
  WHERE customer_id IS NOT NULL
  GROUP BY customer_id
) inv ON inv.customer_id = c.id
LEFT JOIN (
  SELECT customer_id, COALESCE(SUM(amount), 0) AS paid
  FROM customer_payments
  GROUP BY customer_id
) pay ON pay.customer_id = c.id
''';

  static const _balanceExpr =
      'COALESCE(inv.invoiced, 0) - COALESCE(pay.paid, 0) + COALESCE(c.balance_adjustment, 0)';

  Future<Map<int, List<SaleItem>>> _loadInvoiceItemsForCustomer(
    dynamic db,
    int customerId, {
    Iterable<int>? invoiceIds,
  }) async {
    final ids = invoiceIds?.toList();
    if (ids != null && ids.isEmpty) return {};

    final rows = ids == null
        ? await db.query(
            'sales',
            where: 'customer_id = ?',
            whereArgs: [customerId],
            orderBy: 'invoice_id ASC, id ASC',
          )
        : await db.query(
            'sales',
            where: 'invoice_id IN (${List.filled(ids.length, '?').join(',')})',
            whereArgs: ids,
            orderBy: 'invoice_id ASC, id ASC',
          );

    final map = <int, List<SaleItem>>{};
    for (final row in rows) {
      final invoiceId = row['invoice_id'] as int?;
      if (invoiceId == null) continue;
      map.putIfAbsent(invoiceId, () => []).add(SaleItem.fromMap(row));
    }
    return map;
  }

  Future<double> _computePreviousBalanceBeforeDate(
    dynamic db,
    int customerId,
    Customer customer,
    DateTime fromStart,
  ) async {
    final day = fromStart.toIso8601String();
    final invoiceResult = await db.rawQuery('''
      SELECT COALESCE(SUM(final_amount), 0) AS total
      FROM invoices
      WHERE customer_id = ?
        AND date(COALESCE(sale_date, created_date)) < date(?)
    ''', [customerId, day]);
    final paymentResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM customer_payments
      WHERE customer_id = ?
        AND date(payment_date) < date(?)
    ''', [customerId, day]);

    var balance = ((invoiceResult.first['total'] as num?)?.toDouble() ?? 0) -
        ((paymentResult.first['total'] as num?)?.toDouble() ?? 0);

    if (customer.balanceAdjustment != 0) {
      final adjustmentDate = customer.createdDate ?? DateTime(2000);
      if (_isBeforeDay(adjustmentDate, fromStart)) {
        balance += customer.balanceAdjustment;
      }
    }
    return balance;
  }

  @override
  Future<List<Customer>> getAllCustomers() async {
    // Check cache first
    final cached = _cache.get<List<Customer>>(_customersCacheKey);
    if (cached != null) return cached;
    
    final db = await _databaseHelper.database;
    
    // Get customers with their balance (remaining unpaid amounts + manual adjustment)
    final result = await db.rawQuery('''
      SELECT c.*, $_balanceExpr AS balance
      $_balanceJoinFrom
      ORDER BY c.name ASC
    ''');
    
    final customers = result.map((map) => Customer.fromMap(map)).toList();
    
    // Cache for 1 minute
    _cache.set(_customersCacheKey, customers, duration: const Duration(minutes: 1));
    return customers;
  }
  
  void _invalidateCache() {
    _cache.invalidate(_customersCacheKey);
    _cache.invalidate(CacheKeys.customersWithDebt);
    _cache.invalidate(CacheKeys.dashboardStats);
    _cache.invalidate(CacheKeys.customerDebtsReport);
  }

  @override
  Future<Customer?> getCustomerById(int id) async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT c.*, $_balanceExpr AS balance
      $_balanceJoinFrom
      WHERE c.id = ?
    ''', [id]);
    
    if (result.isEmpty) return null;
    return Customer.fromMap(result.first);
  }

  @override
  Future<List<Customer>> searchCustomers(String query) async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT c.*, $_balanceExpr AS balance
      $_balanceJoinFrom
      WHERE c.name LIKE ? OR c.phone LIKE ?
      ORDER BY c.name ASC
      LIMIT 200
    ''', ['%$query%', '%$query%']);
    
    return result.map((map) => Customer.fromMap(map)).toList();
  }

  @override
  Future<List<Customer>> getCustomersWithDebt() async {
    final cached = _cache.get<List<Customer>>(CacheKeys.customersWithDebt);
    if (cached != null) return cached;

    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT c.*, $_balanceExpr AS balance
      $_balanceJoinFrom
      WHERE $_balanceExpr > 0
      ORDER BY balance DESC
      LIMIT 500
    ''');
    
    final customers = result.map((map) => Customer.fromMap(map)).toList();
    _cache.set(CacheKeys.customersWithDebt, customers, duration: const Duration(minutes: 1));
    return customers;
  }

  @override
  Future<List<Customer>> getCustomersPaginated({
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT c.*, $_balanceExpr AS balance
      $_balanceJoinFrom
      ORDER BY c.name ASC
      LIMIT ? OFFSET ?
    ''', [limit, offset]);
    return result.map((map) => Customer.fromMap(map)).toList();
  }

  @override
  Future<int> getCustomersCount() async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) AS count FROM customers');
    return (result.first['count'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<List<Customer>> searchCustomersPaginated(
    String query, {
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT c.*, $_balanceExpr AS balance
      $_balanceJoinFrom
      WHERE c.name LIKE ? OR c.phone LIKE ?
      ORDER BY c.name ASC
      LIMIT ? OFFSET ?
    ''', ['%$query%', '%$query%', limit, offset]);
    return result.map((map) => Customer.fromMap(map)).toList();
  }

  @override
  Future<int> createCustomer(Customer customer) async {
    final db = await _databaseHelper.database;
    final result = await db.insert('customers', customer.toMap());
    
    _auditLogger.log(
      action: AuditAction.customerCreated,
      entityType: 'customer',
      entityId: result,
      entityName: customer.name,
      details: 'Phone: ${customer.phone ?? "N/A"}',
    );
    
    _invalidateCache();
    return result;
  }

  @override
  Future<int> updateCustomer(Customer customer) async {
    final db = await _databaseHelper.database;
    final result = await db.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
    
    if (result > 0) {
      _auditLogger.log(
        action: AuditAction.customerUpdated,
        entityType: 'customer',
        entityId: customer.id,
        entityName: customer.name,
      );
    }
    
    _invalidateCache();
    return result;
  }

  @override
  Future<int> deleteCustomer(int id) async {
    final db = await _databaseHelper.database;
    
    // Get customer info for audit
    final customerResult = await db.query('customers', where: 'id = ?', whereArgs: [id]);
    final customerName = customerResult.isNotEmpty 
        ? customerResult.first['name'] as String? 
        : null;
    
    final result = await db.delete(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (result > 0) {
      _auditLogger.log(
        action: AuditAction.customerDeleted,
        entityType: 'customer',
        entityId: id,
        entityName: customerName,
      );
    }
    
    _invalidateCache();
    return result;
  }

  @override
  Future<double> getCustomerBalance(int customerId) async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT 
        (
          SELECT COALESCE(SUM(i.final_amount), 0) FROM invoices i WHERE i.customer_id = c.id
        ) - (
          SELECT COALESCE(SUM(cp.amount), 0) FROM customer_payments cp WHERE cp.customer_id = c.id
        ) + COALESCE(c.balance_adjustment, 0) as balance
      FROM customers c
      WHERE c.id = ?
    ''', [customerId]);
    
    return (result.first['balance'] as num?)?.toDouble() ?? 0;
  }

  @override
  Future<List<Map<String, dynamic>>> getCustomerTransactions(int customerId) async {
    final db = await _databaseHelper.database;
    return await db.rawQuery('''
      SELECT 
        'invoice' as type,
        invoice_number as reference,
        final_amount as amount,
        payment_method,
        created_date as date
      FROM invoices
      WHERE customer_id = ?
      ORDER BY created_date DESC
    ''', [customerId]);
  }

  @override
  Future<int> recordPayment(CustomerPayment payment) async {
    final db = await _databaseHelper.database;
    
    final result = await db.insert('customer_payments', payment.toMap());
    
    // Update the invoice paid_amount = SUM of all payments for that invoice
    await _recalculateInvoicePaidAmount(payment.invoiceId);
    
    _auditLogger.log(
      action: AuditAction.customerPaymentRecorded,
      entityType: 'customer_payment',
      entityId: result,
      details: 'Amount: ${payment.amount}, Method: ${payment.paymentMethod.name}, Invoice: ${payment.invoiceId}',
    );
    
    _invalidateCache();
    return result;
  }

  @override
  Future<List<CustomerPayment>> getPaymentsByCustomer(int customerId) async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT cp.*, i.invoice_number, c.name as customer_name
      FROM customer_payments cp
      LEFT JOIN invoices i ON cp.invoice_id = i.id
      LEFT JOIN customers c ON cp.customer_id = c.id
      WHERE cp.customer_id = ?
      ORDER BY cp.payment_date DESC, cp.created_date DESC
    ''', [customerId]);
    return result.map((map) => CustomerPayment.fromMap(map)).toList();
  }

  @override
  Future<List<CustomerPayment>> getPaymentsByInvoice(int invoiceId) async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT cp.*, i.invoice_number, c.name as customer_name
      FROM customer_payments cp
      LEFT JOIN invoices i ON cp.invoice_id = i.id
      LEFT JOIN customers c ON cp.customer_id = c.id
      WHERE cp.invoice_id = ?
      ORDER BY cp.payment_date DESC, cp.created_date DESC
    ''', [invoiceId]);
    return result.map((map) => CustomerPayment.fromMap(map)).toList();
  }

  @override
  Future<int> updatePayment(CustomerPayment payment) async {
    if (payment.id == null) return 0;

    final db = await _databaseHelper.database;

    final result = await db.update(
      'customer_payments',
      payment.toMap(),
      where: 'id = ?',
      whereArgs: [payment.id],
    );

    if (result > 0) {
      await _recalculateInvoicePaidAmount(payment.invoiceId);

      _auditLogger.log(
        action: AuditAction.customerPaymentRecorded,
        entityType: 'customer_payment',
        entityId: payment.id,
        details: 'Updated payment: ${payment.amount}, Invoice: ${payment.invoiceId}',
      );

      _invalidateCache();
    }

    return result;
  }

  @override
  Future<int> getOrCreateAccountAnchorInvoice(
    int customerId, {
    String? customerName,
  }) async {
    final db = await _databaseHelper.database;
    final anchor = await db.rawQuery('''
      SELECT id FROM invoices
      WHERE customer_id = ? AND payment_method = 'account'
      ORDER BY id DESC
      LIMIT 1
    ''', [customerId]);
    if (anchor.isNotEmpty) {
      return anchor.first['id'] as int;
    }

    final now = DateTime.now();
    final tempNumber =
        'INV-${now.millisecondsSinceEpoch}-${customerId.toString().padLeft(4, '0')}';

    final invoiceId = await db.insert('invoices', {
      'invoice_number': tempNumber,
      'customer_id': customerId,
      if (customerName != null) 'customer_name': customerName,
      'total_amount': 0,
      'discount_amount': 0,
      'final_amount': 0,
      'paid_amount': 0,
      'total_profit': 0,
      'payment_method': 'account',
      'created_date': now.toIso8601String(),
      'sale_date': now.toIso8601String(),
    });

    final docNumber = _formatInvoiceDoc(invoiceId);
    await db.update(
      'invoices',
      {'invoice_number': docNumber},
      where: 'id = ?',
      whereArgs: [invoiceId],
    );

    _invalidateCache();
    return invoiceId;
  }

  @override
  Future<int> recordAccountDiscount({
    required int customerId,
    required double amount,
    String? notes,
    DateTime? discountDate,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Discount amount must be greater than zero');
    }

    final invoiceId = await getOrCreateAccountAnchorInvoice(customerId);
    return recordPayment(
      CustomerPayment(
        invoiceId: invoiceId,
        customerId: customerId,
        amount: amount,
        paymentDate: discountDate ?? DateTime.now(),
        paymentMethod: CustomerPaymentMethod.discount,
        notes: notes?.trim().isNotEmpty == true ? notes!.trim() : null,
      ),
    );
  }

  @override
  Future<int> deletePayment(int paymentId) async {
    final db = await _databaseHelper.database;
    
    // Get the payment first to know which invoice to recalculate
    final paymentResult = await db.query('customer_payments', where: 'id = ?', whereArgs: [paymentId]);
    if (paymentResult.isEmpty) return 0;
    
    final invoiceId = paymentResult.first['invoice_id'] as int;
    
    final result = await db.delete('customer_payments', where: 'id = ?', whereArgs: [paymentId]);
    
    if (result > 0) {
      // Recalculate invoice paid_amount
      await _recalculateInvoicePaidAmount(invoiceId);
      
      _auditLogger.log(
        action: AuditAction.customerPaymentDeleted,
        entityType: 'customer_payment',
        entityId: paymentId,
        details: 'Deleted payment for invoice $invoiceId',
      );
    }
    
    _invalidateCache();
    return result;
  }

  @override
  Future<Map<String, dynamic>> getCustomerFinancialSummary(int customerId) async {
    final db = await _databaseHelper.database;
    
    // Total invoiced
    final invoiceResult = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_invoices,
        COALESCE(SUM(final_amount), 0) as total_invoiced,
        COALESCE(SUM(paid_amount), 0) as total_paid_on_invoices
      FROM invoices
      WHERE customer_id = ?
    ''', [customerId]);
    
    // Payment breakdown
    final paymentResult = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_payments,
        COALESCE(SUM(amount), 0) as total_paid,
        COALESCE(SUM(CASE WHEN payment_method = 'cash' THEN amount ELSE 0 END), 0) as cash_total,
        COALESCE(SUM(CASE WHEN payment_method = 'cheque' THEN amount ELSE 0 END), 0) as cheque_total
      FROM customer_payments
      WHERE customer_id = ?
    ''', [customerId]);
    
    // Invoice status counts
    final statusResult = await db.rawQuery('''
      SELECT 
        SUM(CASE WHEN paid_amount >= final_amount THEN 1 ELSE 0 END) as paid_count,
        SUM(CASE WHEN paid_amount > 0 AND paid_amount < final_amount THEN 1 ELSE 0 END) as partial_count,
        SUM(CASE WHEN paid_amount = 0 OR paid_amount IS NULL THEN 1 ELSE 0 END) as unpaid_count,
        SUM(CASE WHEN paid_amount > final_amount THEN 1 ELSE 0 END) as overpaid_count
      FROM invoices
      WHERE customer_id = ?
    ''', [customerId]);
    
    final inv = invoiceResult.first;
    final pay = paymentResult.first;
    final stat = statusResult.first;
    
    final totalInvoiced = (inv['total_invoiced'] as num?)?.toDouble() ?? 0;
    final totalPaid = (pay['total_paid'] as num?)?.toDouble() ?? 0;
    
    return {
      'total_invoices': (inv['total_invoices'] as num?)?.toInt() ?? 0,
      'total_invoiced': totalInvoiced,
      'total_paid': totalPaid,
      'outstanding': totalInvoiced - totalPaid,
      'cash_total': (pay['cash_total'] as num?)?.toDouble() ?? 0,
      'cheque_total': (pay['cheque_total'] as num?)?.toDouble() ?? 0,
      'total_payments': (pay['total_payments'] as num?)?.toInt() ?? 0,
      'paid_count': (stat['paid_count'] as num?)?.toInt() ?? 0,
      'partial_count': (stat['partial_count'] as num?)?.toInt() ?? 0,
      'unpaid_count': (stat['unpaid_count'] as num?)?.toInt() ?? 0,
      'overpaid_count': (stat['overpaid_count'] as num?)?.toInt() ?? 0,
    };
  }

  @override
  Future<CustomerLedger> getCustomerLedger(
    int customerId, {
    CustomerLedgerFilters? filters,
  }) async {
    final activeFilters = filters ?? const CustomerLedgerFilters();
    final customer = await getCustomerById(customerId);
    if (customer == null) {
      throw Exception('Customer not found');
    }

    final db = await _databaseHelper.database;

    DateTime? fromStart;
    DateTime? toEnd;
    if (activeFilters.fromDate != null) {
      fromStart = DateTime(
        activeFilters.fromDate!.year,
        activeFilters.fromDate!.month,
        activeFilters.fromDate!.day,
      );
    }
    if (activeFilters.toDate != null) {
      toEnd = DateTime(
        activeFilters.toDate!.year,
        activeFilters.toDate!.month,
        activeFilters.toDate!.day,
        23,
        59,
        59,
        999,
      );
    }

    final previousBalance = fromStart != null
        ? await _computePreviousBalanceBeforeDate(db, customerId, customer, fromStart)
        : 0.0;

    final invoiceWhere = StringBuffer('i.customer_id = ?');
    final invoiceArgs = <dynamic>[customerId];
    if (fromStart != null) {
      invoiceWhere.write(' AND date(COALESCE(i.sale_date, i.created_date)) >= date(?)');
      invoiceArgs.add(fromStart.toIso8601String());
    }
    if (toEnd != null) {
      invoiceWhere.write(' AND date(COALESCE(i.sale_date, i.created_date)) <= date(?)');
      invoiceArgs.add(_dateOnly(toEnd).toIso8601String());
    }

    final invoiceRows = await db.rawQuery('''
      SELECT i.*, c.name as customer_name
      FROM invoices i
      LEFT JOIN customers c ON i.customer_id = c.id
      WHERE $invoiceWhere
      ORDER BY COALESCE(i.sale_date, i.created_date) ASC, i.id ASC
    ''', invoiceArgs);
    final invoices = invoiceRows.map((m) => Invoice.fromMap(m)).toList();

    final paymentWhere = StringBuffer('cp.customer_id = ?');
    final paymentArgs = <dynamic>[customerId];
    if (fromStart != null) {
      paymentWhere.write(' AND date(cp.payment_date) >= date(?)');
      paymentArgs.add(fromStart.toIso8601String());
    }
    if (toEnd != null) {
      paymentWhere.write(' AND date(cp.payment_date) <= date(?)');
      paymentArgs.add(_dateOnly(toEnd).toIso8601String());
    }

    final paymentRows = await db.rawQuery('''
      SELECT cp.*, i.invoice_number, c.name as customer_name
      FROM customer_payments cp
      LEFT JOIN invoices i ON cp.invoice_id = i.id
      LEFT JOIN customers c ON cp.customer_id = c.id
      WHERE $paymentWhere
      ORDER BY cp.payment_date DESC, cp.created_date DESC
    ''', paymentArgs);
    final payments =
        paymentRows.map((map) => CustomerPayment.fromMap(map)).toList();

    final invoiceIds = invoices.where((i) => i.id != null).map((i) => i.id!).toSet();
    final invoiceItems = await _loadInvoiceItemsForCustomer(
      db,
      customerId,
      invoiceIds: fromStart != null || toEnd != null ? invoiceIds : null,
    );

    // Build ledger entries for the loaded period
    final allEntries = <CustomerLedgerEntry>[];

    if (customer.balanceAdjustment != 0) {
      final adjustmentDate = customer.createdDate ?? DateTime(2000);
      final includeAdjustment = fromStart == null || !_isBeforeDay(adjustmentDate, fromStart);
      if (includeAdjustment && (toEnd == null || !_isAfterDay(adjustmentDate, toEnd))) {
        allEntries.add(CustomerLedgerEntry(
          date: adjustmentDate,
          documentType: LedgerDocumentType.manualAdjustment,
          documentNumber: 'ADJ-${customer.id}',
          debit: customer.balanceAdjustment > 0 ? customer.balanceAdjustment : 0,
          credit: customer.balanceAdjustment < 0 ? customer.balanceAdjustment.abs() : 0,
          notes: 'Balance adjustment',
        ));
      }
    }

    for (final invoice in invoices) {
      if (invoice.id == null) continue;

      // Skip empty account anchors created only to hold ledger payments.
      if (invoice.paymentMethod == 'account' && invoice.finalAmount == 0) {
        final anchorItems = invoiceItems[invoice.id!] ?? [];
        if (anchorItems.isEmpty) continue;
      }

      if (invoice.paymentMethod != 'account') {
        allEntries.add(CustomerLedgerEntry(
          invoiceId: invoice.id,
          date: invoice.saleDate ?? invoice.createdDate ?? DateTime.now(),
          documentType: LedgerDocumentType.salesInvoice,
          documentNumber: _formatInvoiceDoc(invoice.id!),
          debit: invoice.finalAmount,
          invoiceNumber: invoice.invoiceNumber,
          notes: invoice.notes,
          lineItems: invoiceItems[invoice.id!],
        ));
        continue;
      }

      final items = invoiceItems[invoice.id!] ?? [];
      allEntries.add(CustomerLedgerEntry(
        invoiceId: invoice.id,
        date: invoice.saleDate ?? invoice.createdDate ?? DateTime.now(),
        documentType: LedgerDocumentType.salesInvoice,
        documentNumber: _formatInvoiceDoc(invoice.id!),
        debit: invoice.finalAmount,
        invoiceNumber: invoice.invoiceNumber,
        notes: invoice.notes,
        lineItems: items,
      ));
    }

    // Payment receipts as credit entries
    for (final payment in payments) {
      if (payment.id == null) continue;
      final isDiscount = payment.isDiscount;
      allEntries.add(CustomerLedgerEntry(
        paymentId: payment.id,
        invoiceId: payment.invoiceId,
        date: payment.paymentDate,
        documentType: isDiscount
            ? LedgerDocumentType.accountDiscount
            : LedgerDocumentType.paymentReceipt,
        documentNumber: isDiscount
            ? _formatDiscountDoc(payment.id!)
            : _formatReceiptDoc(payment.id!),
        credit: payment.amount,
        invoiceNumber: payment.invoiceNumber,
        paymentMethod: payment.paymentMethod,
        chequeNumber: payment.chequeNumber,
        notes: payment.notes ??
            (payment.isCheque
                ? 'شيك: ${payment.chequeNumber ?? '-'}'
                : (isDiscount ? 'خصم على الحساب' : 'نقداً')),
      ));
    }

    // Sort chronologically; invoices before credits on same day
    allEntries.sort((a, b) {
      final dateCmp = a.date.compareTo(b.date);
      if (dateCmp != 0) return dateCmp;
      final aIsSale = a.isSalesInvoice;
      final bIsSale = b.isSalesInvoice;
      if (aIsSale && !bIsSale) return -1;
      if (!aIsSale && bIsSale) return 1;
      if (a.isDiscount && b.isPayment) return -1;
      if (a.isPayment && b.isDiscount) return 1;
      return (a.invoiceId ?? a.paymentId ?? 0).compareTo(b.invoiceId ?? b.paymentId ?? 0);
    });

    final currentBalance = customer.balance;
    final totalSales = invoices.fold<double>(0, (s, i) => s + i.finalAmount);
    final totalPaymentsAmount = payments.fold<double>(0, (s, p) => s + p.amount);

    var filtered = allEntries.where((entry) {
      if (activeFilters.documentType != null &&
          entry.documentType != activeFilters.documentType) {
        return false;
      }
      if (activeFilters.invoiceNumber != null &&
          activeFilters.invoiceNumber!.isNotEmpty) {
        final q = activeFilters.invoiceNumber!.toLowerCase();
        final matches = (entry.invoiceNumber?.toLowerCase().contains(q) ?? false) ||
            entry.documentNumber.toLowerCase().contains(q);
        if (!matches) return false;
      }
      if (activeFilters.receiptNumber != null &&
          activeFilters.receiptNumber!.isNotEmpty) {
        final q = activeFilters.receiptNumber!.toLowerCase();
        if (!entry.documentNumber.toLowerCase().contains(q)) return false;
      }
      return true;
    }).toList();

    // Recalculate running balance within filtered view (starts from prior net balance).
    double runningBalance = previousBalance;
    double totalDebit = 0;
    double totalCredit = 0;
    final displayEntries = <CustomerLedgerEntry>[];

    for (final entry in filtered) {
      runningBalance += entry.debit - entry.credit;
      totalDebit += entry.debit;
      totalCredit += entry.credit;
      displayEntries.add(entry.copyWith(runningBalance: runningBalance));
    }

    final finalBalance = activeFilters.hasActiveFilters
        ? runningBalance
        : currentBalance;

    return CustomerLedger(
      customer: customer,
      customerCode: 'CUST-${customer.id.toString().padLeft(4, '0')}',
      previousBalance: 0,
      openingDebit: 0,
      openingCredit: 0,
      showCarriedForward: false,
      currentBalance: currentBalance,
      totalSales: totalSales,
      totalPayments: totalPaymentsAmount,
      totalOutstanding: currentBalance,
      totalDebit: totalDebit,
      totalCredit: totalCredit,
      finalBalance: finalBalance,
      entries: displayEntries,
      invoiceItems: invoiceItems,
      filters: activeFilters,
    );
  }

  /// Recalculates paid_amount on the invoice from the sum of all customer_payments
  Future<void> _recalculateInvoicePaidAmount(int invoiceId) async {
    final db = await _databaseHelper.database;
    await db.rawUpdate('''
      UPDATE invoices SET paid_amount = (
        SELECT COALESCE(SUM(amount), 0) FROM customer_payments
        WHERE invoice_id = ? AND COALESCE(payment_method, 'cash') != 'discount'
      ) WHERE id = ?
    ''', [invoiceId, invoiceId]);
  }
}
