import '../../../../core/database/database_helper.dart';
import '../../../../core/services/cache_service.dart';
import '../../domain/entities/customer.dart';
import '../../domain/repositories/customer_repository.dart';

class CustomerRepositoryImpl implements CustomerRepository {
  final DatabaseHelper _databaseHelper;
  final CacheService _cache = CacheService();
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
    
    return result.map((map) => Customer.fromMap(map)).toList();
  }

  @override
  Future<int> createCustomer(Customer customer) async {
    final db = await _databaseHelper.database;
    final result = await db.insert('customers', customer.toMap());
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
    _invalidateCache();
    return result;
  }

  @override
  Future<int> deleteCustomer(int id) async {
    final db = await _databaseHelper.database;
    final result = await db.delete(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
    );
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
}
