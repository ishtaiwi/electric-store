import '../../../../core/database/database_helper.dart';
import '../../../../core/services/cache_service.dart';
import '../../../../core/services/audit_logger_service.dart';
import '../../domain/entities/expense.dart';
import '../../domain/repositories/expense_repository.dart';

class ExpenseRepositoryImpl implements ExpenseRepository {
  final DatabaseHelper _databaseHelper;
  final CacheService _cache = CacheService();
  final AuditLoggerService _auditLogger = AuditLoggerService();

  ExpenseRepositoryImpl(this._databaseHelper);

  void _invalidateCache() {
    _cache.invalidate(CacheKeys.expenses);
    _cache.invalidate(CacheKeys.expenseCategories);
    _cache.invalidate(CacheKeys.dashboardStats);
    _cache.invalidatePattern('expenses_');
    _cache.invalidatePattern('report_profit');
  }

  @override
  Future<List<Expense>> getAllExpenses() async {
    final cached = _cache.get<List<Expense>>(CacheKeys.expenses);
    if (cached != null) return cached;

    final db = await _databaseHelper.database;
    final result = await db.query('expenses', orderBy: 'expense_date DESC');
    final expenses = result.map((map) => Expense.fromMap(map)).toList();

    _cache.set(CacheKeys.expenses, expenses, duration: const Duration(minutes: 2));
    return expenses;
  }

  @override
  Future<Expense?> getExpenseById(int id) async {
    final db = await _databaseHelper.database;
    final result = await db.query(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    return Expense.fromMap(result.first);
  }

  @override
  Future<List<Expense>> getExpensesByDateRange(DateTime start, DateTime end) async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT * FROM expenses
      WHERE date(expense_date) BETWEEN date(?) AND date(?)
      ORDER BY expense_date DESC
    ''', [start.toIso8601String(), end.toIso8601String()]);
    return result.map((map) => Expense.fromMap(map)).toList();
  }

  @override
  Future<List<Expense>> getExpensesByCategory(String category) async {
    final db = await _databaseHelper.database;
    final result = await db.query(
      'expenses',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'expense_date DESC',
    );
    return result.map((map) => Expense.fromMap(map)).toList();
  }

  @override
  Future<List<String>> getAllCategories() async {
    final cached = _cache.get<List<String>>(CacheKeys.expenseCategories);
    if (cached != null) return cached;

    final db = await _databaseHelper.database;
    final result = await db.rawQuery(
      'SELECT DISTINCT category FROM expenses WHERE category IS NOT NULL ORDER BY category ASC',
    );
    final categories = result.map((map) => map['category'] as String).toList();

    _cache.set(CacheKeys.expenseCategories, categories, duration: CacheService.longDuration);
    return categories;
  }

  @override
  Future<double> getTotalExpenses(DateTime? start, DateTime? end) async {
    final db = await _databaseHelper.database;
    
    String query = 'SELECT COALESCE(SUM(amount), 0) as total FROM expenses';
    List<dynamic> args = [];
    
    if (start != null && end != null) {
      query += ' WHERE date(expense_date) BETWEEN date(?) AND date(?)';
      args = [start.toIso8601String(), end.toIso8601String()];
    }
    
    final result = await db.rawQuery(query, args);
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  @override
  Future<int> createExpense(Expense expense) async {
    final db = await _databaseHelper.database;
    final id = await db.insert('expenses', expense.toMap());
    
    await _auditLogger.log(
      action: AuditAction.expenseCreated,
      entityType: 'expense',
      entityId: id,
      details: 'Created expense: ${expense.description.isNotEmpty ? expense.description : expense.category} - Amount: ${expense.amount}',
    );
    
    _invalidateCache();
    return id;
  }

  @override
  Future<int> updateExpense(Expense expense) async {
    final db = await _databaseHelper.database;
    
    // Get old expense for audit
    final oldResult = await db.query('expenses', where: 'id = ?', whereArgs: [expense.id]);
    final oldExpense = oldResult.isNotEmpty ? Expense.fromMap(oldResult.first) : null;
    
    final result = await db.update(
      'expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
    
    if (result > 0 && oldExpense != null) {
      await _auditLogger.log(
        action: AuditAction.expenseUpdated,
        entityType: 'expense',
        entityId: expense.id,
        details: 'Updated expense ID ${expense.id}: Amount ${oldExpense.amount} -> ${expense.amount}',
      );
    }
    
    _invalidateCache();
    return result;
  }

  @override
  Future<int> deleteExpense(int id) async {
    final db = await _databaseHelper.database;
    
    // Get expense details for audit before deleting
    final result = await db.query('expenses', where: 'id = ?', whereArgs: [id]);
    final expense = result.isNotEmpty ? Expense.fromMap(result.first) : null;
    
    final deleteResult = await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (deleteResult > 0 && expense != null) {
      await _auditLogger.log(
        action: AuditAction.expenseDeleted,
        entityType: 'expense',
        entityId: id,
        details: 'Deleted expense: ${expense.description.isNotEmpty ? expense.description : expense.category} - Amount: ${expense.amount}',
      );
    }
    
    _invalidateCache();
    return deleteResult;
  }
}
