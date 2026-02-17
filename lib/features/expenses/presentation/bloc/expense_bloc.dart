import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/services/localization_service.dart';
import '../../domain/entities/expense.dart';
import '../../domain/repositories/expense_repository.dart';

// Events
abstract class ExpenseEvent extends Equatable {
  const ExpenseEvent();

  @override
  List<Object?> get props => [];
}

class ExpenseLoadAll extends ExpenseEvent {}

class ExpenseRefresh extends ExpenseEvent {}

class ExpenseLoadByDateRange extends ExpenseEvent {
  final DateTime start;
  final DateTime end;

  const ExpenseLoadByDateRange({required this.start, required this.end});

  @override
  List<Object?> get props => [start, end];
}

class ExpenseLoadByCategory extends ExpenseEvent {
  final String category;

  const ExpenseLoadByCategory(this.category);

  @override
  List<Object?> get props => [category];
}

class ExpenseCreate extends ExpenseEvent {
  final Expense expense;

  const ExpenseCreate(this.expense);

  @override
  List<Object?> get props => [expense];
}

class ExpenseUpdate extends ExpenseEvent {
  final Expense expense;

  const ExpenseUpdate(this.expense);

  @override
  List<Object?> get props => [expense];
}

class ExpenseDelete extends ExpenseEvent {
  final int id;

  const ExpenseDelete(this.id);

  @override
  List<Object?> get props => [id];
}

// States
abstract class ExpenseState extends Equatable {
  const ExpenseState();

  @override
  List<Object?> get props => [];
}

class ExpenseInitial extends ExpenseState {}

class ExpenseLoading extends ExpenseState {}

class ExpenseLoaded extends ExpenseState {
  final List<Expense> expenses;
  final List<String> categories;
  final double totalAmount;

  const ExpenseLoaded({
    required this.expenses,
    this.categories = const [],
    this.totalAmount = 0,
  });

  @override
  List<Object?> get props => [expenses, categories, totalAmount];
}

class ExpenseError extends ExpenseState {
  final String message;

  const ExpenseError(this.message);

  @override
  List<Object?> get props => [message];
}

class ExpenseOperationSuccess extends ExpenseState {
  final String message;

  const ExpenseOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class ExpenseBloc extends Bloc<ExpenseEvent, ExpenseState> {
  final ExpenseRepository _expenseRepository;
  bool _hasLoadedOnce = false;

  ExpenseBloc(this._expenseRepository) : super(ExpenseInitial()) {
    on<ExpenseLoadAll>(_onLoadAll);
    on<ExpenseRefresh>(_onRefresh);
    on<ExpenseLoadByDateRange>(_onLoadByDateRange);
    on<ExpenseLoadByCategory>(_onLoadByCategory);
    on<ExpenseCreate>(_onCreate);
    on<ExpenseUpdate>(_onUpdate);
    on<ExpenseDelete>(_onDelete);
  }

  Future<void> _onLoadAll(
    ExpenseLoadAll event,
    Emitter<ExpenseState> emit,
  ) async {
    // Skip reload if already loaded (singleton behavior)
    if (_hasLoadedOnce && state is ExpenseLoaded) {
      return;
    }
    emit(ExpenseLoading());
    try {
      final expenses = await _expenseRepository.getAllExpenses();
      final categories = await _expenseRepository.getAllCategories();
      final total = await _expenseRepository.getTotalExpenses(null, null);
      _hasLoadedOnce = true;
      emit(ExpenseLoaded(
        expenses: expenses,
        categories: categories,
        totalAmount: total,
      ));
    } catch (e) {
      emit(ExpenseError(e.toString()));
    }
  }

  Future<void> _onRefresh(
    ExpenseRefresh event,
    Emitter<ExpenseState> emit,
  ) async {
    emit(ExpenseLoading());
    try {
      final expenses = await _expenseRepository.getAllExpenses();
      final categories = await _expenseRepository.getAllCategories();
      final total = await _expenseRepository.getTotalExpenses(null, null);
      _hasLoadedOnce = true;
      emit(ExpenseLoaded(
        expenses: expenses,
        categories: categories,
        totalAmount: total,
      ));
    } catch (e) {
      emit(ExpenseError(e.toString()));
    }
  }

  Future<void> _onLoadByDateRange(
    ExpenseLoadByDateRange event,
    Emitter<ExpenseState> emit,
  ) async {
    emit(ExpenseLoading());
    try {
      final expenses = await _expenseRepository.getExpensesByDateRange(event.start, event.end);
      final categories = await _expenseRepository.getAllCategories();
      final total = await _expenseRepository.getTotalExpenses(event.start, event.end);
      emit(ExpenseLoaded(
        expenses: expenses,
        categories: categories,
        totalAmount: total,
      ));
    } catch (e) {
      emit(ExpenseError(e.toString()));
    }
  }

  Future<void> _onLoadByCategory(
    ExpenseLoadByCategory event,
    Emitter<ExpenseState> emit,
  ) async {
    emit(ExpenseLoading());
    try {
      final expenses = await _expenseRepository.getExpensesByCategory(event.category);
      final categories = await _expenseRepository.getAllCategories();
      final total = expenses.fold<double>(0, (sum, e) => sum + e.amount);
      emit(ExpenseLoaded(
        expenses: expenses,
        categories: categories,
        totalAmount: total,
      ));
    } catch (e) {
      emit(ExpenseError(e.toString()));
    }
  }

  Future<void> _onCreate(
    ExpenseCreate event,
    Emitter<ExpenseState> emit,
  ) async {
    final currentState = state;
    List<Expense> currentList = [];
    List<String> categories = [];
    double totalAmount = 0;
    
    if (currentState is ExpenseLoaded) {
      currentList = List<Expense>.from(currentState.expenses);
      categories = List.from(currentState.categories);
      totalAmount = currentState.totalAmount;
    }
    
    try {
      final createdId = await _expenseRepository.createExpense(event.expense);
      final createdExpense = event.expense.copyWith(id: createdId);
      
      // Fast update: add to beginning of list
      currentList.insert(0, createdExpense);
      totalAmount += event.expense.amount;
      
      // Add category if new
      if (!categories.contains(event.expense.category)) {
        categories.add(event.expense.category);
      }
      
      emit(ExpenseLoaded(
        expenses: currentList,
        categories: categories,
        totalAmount: totalAmount,
      ));
      
      emit(ExpenseOperationSuccess(LocalizationService().get('expenseCreated')));
      
      // Re-emit list to keep UI showing
      emit(ExpenseLoaded(
        expenses: currentList,
        categories: categories,
        totalAmount: totalAmount,
      ));
    } catch (e) {
      emit(ExpenseError(e.toString()));
    }
  }

  Future<void> _onUpdate(
    ExpenseUpdate event,
    Emitter<ExpenseState> emit,
  ) async {
    final currentState = state;
    List<Expense> currentList = [];
    List<String> categories = [];
    double totalAmount = 0;
    
    if (currentState is ExpenseLoaded) {
      currentList = List<Expense>.from(currentState.expenses);
      categories = List.from(currentState.categories);
      totalAmount = currentState.totalAmount;
    }
    
    try {
      // Find old expense to adjust total
      final oldExpenseIndex = currentList.indexWhere((e) => e.id == event.expense.id);
      double oldAmount = 0;
      if (oldExpenseIndex != -1) {
        oldAmount = currentList[oldExpenseIndex].amount;
      }
      
      await _expenseRepository.updateExpense(event.expense);
      
      // Fast update: replace in list directly
      if (oldExpenseIndex != -1) {
        currentList[oldExpenseIndex] = event.expense;
        totalAmount = totalAmount - oldAmount + event.expense.amount;
      }
      
      emit(ExpenseLoaded(
        expenses: currentList,
        categories: categories,
        totalAmount: totalAmount,
      ));
      
      emit(ExpenseOperationSuccess(LocalizationService().get('expenseUpdated')));
      
      // Re-emit list to keep UI showing
      emit(ExpenseLoaded(
        expenses: currentList,
        categories: categories,
        totalAmount: totalAmount,
      ));
    } catch (e) {
      emit(ExpenseError(e.toString()));
    }
  }

  Future<void> _onDelete(
    ExpenseDelete event,
    Emitter<ExpenseState> emit,
  ) async {
    final currentState = state;
    List<Expense> currentList = [];
    List<String> categories = [];
    double totalAmount = 0;
    
    if (currentState is ExpenseLoaded) {
      currentList = List<Expense>.from(currentState.expenses);
      categories = List.from(currentState.categories);
      totalAmount = currentState.totalAmount;
    }
    
    try {
      // Find expense to get amount for total adjustment
      final expenseIndex = currentList.indexWhere((e) => e.id == event.id);
      double amountToRemove = 0;
      if (expenseIndex != -1) {
        amountToRemove = currentList[expenseIndex].amount;
      }
      
      await _expenseRepository.deleteExpense(event.id);
      
      // Fast update: remove from list directly
      currentList.removeWhere((e) => e.id == event.id);
      totalAmount -= amountToRemove;
      
      emit(ExpenseLoaded(
        expenses: currentList,
        categories: categories,
        totalAmount: totalAmount,
      ));
      
      emit(ExpenseOperationSuccess(LocalizationService().get('expenseDeleted')));
      
      // Re-emit list to keep UI showing
      emit(ExpenseLoaded(
        expenses: currentList,
        categories: categories,
        totalAmount: totalAmount,
      ));
    } catch (e) {
      emit(ExpenseError(e.toString()));
    }
  }
}
