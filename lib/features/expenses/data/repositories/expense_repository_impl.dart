import '../../../../core/database/database_helper.dart';
import '../../domain/entities/expense.dart';
import '../../domain/repositories/expense_repository.dart';

class ExpenseRepositoryImpl implements ExpenseRepository {
  final DatabaseHelper _databaseHelper;

  ExpenseRepositoryImpl(this._databaseHelper);

  @override
  Future<List<Expense>> getAllExpenses() async {
    final db = await _databaseHelper.database;
    final result = await db.query('expenses', orderBy: 'expense_date DESC');
    return result.map((map) => Expense.fromMap(map)).toList();
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
    final db = await _databaseHelper.database;
    final result = await db.rawQuery(
      'SELECT DISTINCT category FROM expenses WHERE category IS NOT NULL ORDER BY category ASC',
    );
    return result.map((map) => map['category'] as String).toList();
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
    return await db.insert('expenses', expense.toMap());
  }

  @override
  Future<int> updateExpense(Expense expense) async {
    final db = await _databaseHelper.database;
    return await db.update(
      'expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  @override
  Future<int> deleteExpense(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
