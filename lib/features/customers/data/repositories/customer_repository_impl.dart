import '../../../../core/database/database_helper.dart';
import '../../../../core/services/cache_service.dart';
import '../../../../core/services/audit_logger_service.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/customer_payment.dart';
import '../../domain/repositories/customer_repository.dart';

class CustomerRepositoryImpl implements CustomerRepository {
  final DatabaseHelper _databaseHelper;
  final CacheService _cache = CacheService();
  final AuditLoggerService _auditLogger = AuditLoggerService();
  static const _customersCacheKey = 'all_customers';

  CustomerRepositoryImpl(this._databaseHelper);

  @override
  Future<List<Customer>> getAllCustomers() async {
    // Check cache first
    final cached = _cache.get<List<Customer>>(_customersCacheKey);
    if (cached != null) return cached;
    
    final db = await _databaseHelper.database;
    
    // Get customers with their balance (remaining unpaid amounts + manual adjustment)
    final result = await db.rawQuery('''
      SELECT c.*, 
        COALESCE(SUM(i.final_amount - i.paid_amount), 0) + COALESCE(c.balance_adjustment, 0) as balance
      FROM customers c
      LEFT JOIN invoices i ON c.id = i.customer_id
      GROUP BY c.id
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
      SELECT c.*, 
        COALESCE(SUM(i.final_amount - i.paid_amount), 0) + COALESCE(c.balance_adjustment, 0) as balance
      FROM customers c
      LEFT JOIN invoices i ON c.id = i.customer_id
      WHERE c.id = ?
      GROUP BY c.id
    ''', [id]);
    
    if (result.isEmpty) return null;
    return Customer.fromMap(result.first);
  }

  @override
  Future<List<Customer>> searchCustomers(String query) async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT c.*, 
        COALESCE(SUM(i.final_amount - i.paid_amount), 0) + COALESCE(c.balance_adjustment, 0) as balance
      FROM customers c
      LEFT JOIN invoices i ON c.id = i.customer_id
      WHERE c.name LIKE ? OR c.phone LIKE ?
      GROUP BY c.id
      ORDER BY c.name ASC
    ''', ['%$query%', '%$query%']);
    
    return result.map((map) => Customer.fromMap(map)).toList();
  }

  @override
  Future<List<Customer>> getCustomersWithDebt() async {
    final cached = _cache.get<List<Customer>>(CacheKeys.customersWithDebt);
    if (cached != null) return cached;

    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT c.*, 
        COALESCE(SUM(i.final_amount - i.paid_amount), 0) + COALESCE(c.balance_adjustment, 0) as balance
      FROM customers c
      LEFT JOIN invoices i ON c.id = i.customer_id
      GROUP BY c.id
      HAVING balance > 0
      ORDER BY balance DESC
    ''');
    
    final customers = result.map((map) => Customer.fromMap(map)).toList();
    _cache.set(CacheKeys.customersWithDebt, customers, duration: const Duration(minutes: 1));
    return customers;
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
        COALESCE(SUM(i.final_amount - i.paid_amount), 0) + COALESCE(c.balance_adjustment, 0) as balance
      FROM customers c
      LEFT JOIN invoices i ON c.id = i.customer_id
      WHERE c.id = ?
      GROUP BY c.id
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

  /// Recalculates paid_amount on the invoice from the sum of all customer_payments
  Future<void> _recalculateInvoicePaidAmount(int invoiceId) async {
    final db = await _databaseHelper.database;
    await db.rawUpdate('''
      UPDATE invoices SET paid_amount = (
        SELECT COALESCE(SUM(amount), 0) FROM customer_payments WHERE invoice_id = ?
      ) WHERE id = ?
    ''', [invoiceId, invoiceId]);
  }
}
