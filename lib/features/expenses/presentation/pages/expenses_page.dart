import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/expense.dart';
import '../bloc/expense_bloc.dart';
import '../widgets/expense_form_dialog.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedCategory;
  final _dateFormat = DateFormat('yyyy-MM-dd');
  
  final List<String> _categories = [
    'utilities',
    'rent',
    'salaries',
    'supplies',
    'maintenance',
    'shipping',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    // Default to current month
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = now;
  }

  void _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(
        start: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
        end: _endDate ?? DateTime.now(),
      ),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadExpenses();
    }
  }

  void _loadExpenses() {
    if (_selectedCategory != null) {
      context.read<ExpenseBloc>().add(ExpenseLoadByCategory(_selectedCategory!));
    } else {
      context.read<ExpenseBloc>().add(ExpenseLoadByDateRange(
        start: _startDate!,
        end: _endDate!,
      ));
    }
  }

  void _showExpenseDialog({Expense? expense}) {
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<ExpenseBloc>(),
        child: ExpenseFormDialog(expense: expense, categories: _categories),
      ),
    );
  }

  void _confirmDelete(Expense expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.confirmDelete),
        content: Text(LocalizationService().get('confirmDeleteExpense')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              this.context.read<ExpenseBloc>().add(ExpenseDelete(expense.id!));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
  }

  String _formatCategory(String category) {
    // Use localization service for category translations
    final translationKey = category.toLowerCase();
    final translation = LocalizationService().get(translationKey);
    // If translation exists (not same as key), return it
    if (translation != translationKey) {
      return translation;
    }
    // Fallback to capitalized version
    return category.split('_').map((word) {
      return word.isNotEmpty
          ? '${word[0].toUpperCase()}${word.substring(1)}'
          : word;
    }).join(' ');
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'utilities':
        return Icons.electrical_services;
      case 'rent':
        return Icons.home;
      case 'salaries':
        return Icons.people;
      case 'supplies':
        return Icons.inventory;
      case 'maintenance':
        return Icons.build;
      case 'shipping':
        return Icons.local_shipping;
      default:
        return Icons.receipt;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExpenseBloc, ExpenseState>(
      listener: (context, state) {
        if (state is ExpenseOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.success,
            ),
          );
        } else if (state is ExpenseError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      builder: (context, state) {
        List<Expense> expenses = [];
        double totalAmount = 0;

        if (state is ExpenseLoaded) {
          expenses = state.expenses;
          totalAmount = expenses.fold(0, (sum, e) => sum + e.amount);
        }

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppStrings.expenses,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showExpenseDialog(),
                    icon: const Icon(Icons.add),
                    label: Text(LocalizationService().get('addExpense')),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Filters
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Date range picker
                  OutlinedButton.icon(
                    onPressed: _selectDateRange,
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _startDate != null && _endDate != null
                          ? '${_dateFormat.format(_startDate!)} - ${_dateFormat.format(_endDate!)}'
                          : LocalizationService().get('selectDateRange'),
                    ),
                  ),

                  // Category filter
                  DropdownButton<String?>(
                    value: _selectedCategory,
                    hint: Text(LocalizationService().get('allCategories')),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(LocalizationService().get('allCategories')),
                      ),
                      ..._categories.map((category) => DropdownMenuItem(
                            value: category,
                            child: Text(_formatCategory(category)),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedCategory = value);
                      _loadExpenses();
                    },
                  ),

                  // Total amount
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.money_off, color: AppColors.error),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              LocalizationService().get('totalExpenses'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              '₪${totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Expense count
              Text(
                '${expenses.length} expenses',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 8),

              // Data Table
              Expanded(
                child: state is ExpenseLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Card(
                        child: DataTable2(
                          columnSpacing: 16,
                          horizontalMargin: 16,
                          minWidth: 700,
                          headingRowColor: WidgetStateProperty.all(
                            AppColors.primary.withOpacity(0.1),
                          ),
                          columns: [
                            DataColumn2(label: Text(LocalizationService().get('date')), size: ColumnSize.S),
                            DataColumn2(label: Text(LocalizationService().get('category')), size: ColumnSize.M),
                            DataColumn2(label: Text(LocalizationService().get('description')), size: ColumnSize.L),
                            DataColumn2(label: Text(LocalizationService().get('amount')), numeric: true),
                            DataColumn2(label: Text(LocalizationService().get('actions')), size: ColumnSize.S),
                          ],
                          rows: expenses.map((expense) {
                            return DataRow2(
                              cells: [
                                DataCell(Text(_dateFormat.format(expense.expenseDate ?? DateTime.now()))),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _getCategoryIcon(expense.category),
                                        size: 16,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(_formatCategory(expense.category)),
                                    ],
                                  ),
                                ),
                                DataCell(Text(expense.description)),
                                DataCell(
                                  Text(
                                    '₪${expense.amount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 20),
                                        onPressed: () => _showExpenseDialog(expense: expense),
                                        tooltip: LocalizationService().get('edit'),
                                        color: AppColors.primary,
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, size: 20),
                                        onPressed: () => _confirmDelete(expense),
                                        tooltip: LocalizationService().get('delete'),
                                        color: AppColors.error,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                          empty: Center(
                            child: Text(LocalizationService().get('noExpensesFound')),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
