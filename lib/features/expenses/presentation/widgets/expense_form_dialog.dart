import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/localization_service.dart';
import '../../domain/entities/expense.dart';
import '../bloc/expense_bloc.dart';

class ExpenseFormDialog extends StatefulWidget {
  final Expense? expense;
  final List<String> categories;

  const ExpenseFormDialog({
    super.key,
    this.expense,
    required this.categories,
  });

  @override
  State<ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<ExpenseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late String _selectedCategory;
  late DateTime _selectedDate;
  final _dateFormat = DateFormat('yyyy-MM-dd');
  late List<String> _uniqueCategories;

  bool get isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    // Ensure unique categories
    _uniqueCategories = widget.categories.toSet().toList();
    
    _amountController = TextEditingController(
      text: widget.expense?.amount.toStringAsFixed(2) ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.expense?.description ?? '',
    );
    
    // Ensure selected category exists in the list
    final expenseCategory = widget.expense?.category;
    if (expenseCategory != null && !_uniqueCategories.contains(expenseCategory)) {
      _uniqueCategories.insert(0, expenseCategory);
    }
    _selectedCategory = expenseCategory ?? (_uniqueCategories.isNotEmpty ? _uniqueCategories.first : '');
    _selectedDate = widget.expense?.expenseDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
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

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final expense = Expense(
        id: widget.expense?.id,
        category: _selectedCategory,
        amount: double.parse(_amountController.text),
        description: _descriptionController.text.trim().isEmpty
            ? _selectedCategory
            : _descriptionController.text.trim(),
        expenseDate: _selectedDate,
        userId: widget.expense?.userId ?? 1, // Default user ID
      );

      if (isEditing) {
        context.read<ExpenseBloc>().add(ExpenseUpdate(expense));
      } else {
        context.read<ExpenseBloc>().add(ExpenseCreate(expense));
      }

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isEditing ? LocalizationService().get('editExpense') : LocalizationService().get('addExpense')),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Date picker
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: LocalizationService().get('dateRequired'),
                    prefixIcon: const Icon(Icons.calendar_today),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_dateFormat.format(_selectedDate)),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Category dropdown
              DropdownButtonFormField<String>(
                value: _selectedCategory.isNotEmpty ? _selectedCategory : null,
                decoration: InputDecoration(
                  labelText: LocalizationService().get('categoryRequired'),
                  prefixIcon: const Icon(Icons.category),
                ),
                items: _uniqueCategories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(_formatCategory(category)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCategory = value);
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return LocalizationService().get('selectCategory');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Amount
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: LocalizationService().get('amountRequired'),
                  prefixIcon: const Icon(Icons.attach_money),
                  prefixText: '₪',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return LocalizationService().get('amountIsRequired');
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return LocalizationService().get('validAmount');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: LocalizationService().get('description'),
                  prefixIcon: const Icon(Icons.notes),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(LocalizationService().get('cancel')),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(isEditing ? LocalizationService().get('update') : LocalizationService().get('add')),
        ),
      ],
    );
  }
}
