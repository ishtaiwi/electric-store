import '../entities/expense.dart';

abstract class ExpenseRepository {
  Future<List<Expense>> getAllExpenses();
  Future<Expense?> getExpenseById(int id);
  Future<List<Expense>> getExpensesByDateRange(DateTime start, DateTime end);
  Future<List<Expense>> getExpensesByCategory(String category);
  Future<List<String>> getAllCategories();
  Future<double> getTotalExpenses(DateTime? start, DateTime? end);
  Future<int> createExpense(Expense expense);
  Future<int> updateExpense(Expense expense);
  Future<int> deleteExpense(int id);
}
