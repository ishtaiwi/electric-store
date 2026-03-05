import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/services/localization_service.dart';
import '../../domain/entities/customer.dart';
import '../../domain/repositories/customer_repository.dart';

// Events
abstract class CustomerEvent extends Equatable {
  const CustomerEvent();

  @override
  List<Object?> get props => [];
}

class CustomerLoadAll extends CustomerEvent {}

class CustomerRefresh extends CustomerEvent {}

class CustomerSearch extends CustomerEvent {
  final String query;

  const CustomerSearch(this.query);

  @override
  List<Object?> get props => [query];
}

class CustomerLoadWithDebt extends CustomerEvent {}

class CustomerCreate extends CustomerEvent {
  final Customer customer;

  const CustomerCreate(this.customer);

  @override
  List<Object?> get props => [customer];
}

class CustomerUpdate extends CustomerEvent {
  final Customer customer;

  const CustomerUpdate(this.customer);

  @override
  List<Object?> get props => [customer];
}

class CustomerDelete extends CustomerEvent {
  final int id;

  const CustomerDelete(this.id);

  @override
  List<Object?> get props => [id];
}

class CustomerLoadTransactions extends CustomerEvent {
  final int customerId;

  const CustomerLoadTransactions(this.customerId);

  @override
  List<Object?> get props => [customerId];
}

// States
abstract class CustomerState extends Equatable {
  const CustomerState();

  @override
  List<Object?> get props => [];
}

class CustomerInitial extends CustomerState {}

class CustomerLoading extends CustomerState {}

class CustomerLoaded extends CustomerState {
  final List<Customer> customers;

  const CustomerLoaded(this.customers);

  @override
  List<Object?> get props => [customers];
}

class CustomerTransactionsLoaded extends CustomerState {
  final Customer customer;
  final List<Map<String, dynamic>> transactions;

  const CustomerTransactionsLoaded({required this.customer, required this.transactions});

  @override
  List<Object?> get props => [customer, transactions];
}

class CustomerError extends CustomerState {
  final String message;

  const CustomerError(this.message);

  @override
  List<Object?> get props => [message];
}

class CustomerOperationSuccess extends CustomerState {
  final String message;

  const CustomerOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class CustomerBloc extends Bloc<CustomerEvent, CustomerState> {
  final CustomerRepository _customerRepository;
  
  // Persistent list that survives state transitions (success, error, transactions, etc.)
  List<Customer> _lastKnownCustomers = [];

  CustomerBloc(this._customerRepository) : super(CustomerInitial()) {
    on<CustomerLoadAll>(_onLoadAll);
    on<CustomerRefresh>(_onRefresh);
    on<CustomerSearch>(_onSearch);
    on<CustomerLoadWithDebt>(_onLoadWithDebt);
    on<CustomerCreate>(_onCreate);
    on<CustomerUpdate>(_onUpdate);
    on<CustomerDelete>(_onDelete);
    on<CustomerLoadTransactions>(_onLoadTransactions);
  }

  Future<void> _onLoadAll(
    CustomerLoadAll event,
    Emitter<CustomerState> emit,
  ) async {
    // If we already have the full customer list cached, re-emit it immediately
    // without hitting the DB (the repository has its own 1-minute cache too)
    if (_lastKnownCustomers.isNotEmpty) {
      emit(CustomerLoaded(_lastKnownCustomers));
      return;
    }
    emit(CustomerLoading());
    try {
      final customers = await _customerRepository.getAllCustomers();
      _lastKnownCustomers = customers;
      emit(CustomerLoaded(customers));
    } catch (e) {
      // On error, still show the last known list if available
      if (_lastKnownCustomers.isNotEmpty) {
        emit(CustomerLoaded(_lastKnownCustomers));
      }
      emit(CustomerError(e.toString()));
    }
  }

  Future<void> _onRefresh(
    CustomerRefresh event,
    Emitter<CustomerState> emit,
  ) async {
    // Don't emit loading to avoid flicker — keep showing old data
    try {
      final customers = await _customerRepository.getAllCustomers();
      _lastKnownCustomers = customers;
      emit(CustomerLoaded(customers));
    } catch (e) {
      if (_lastKnownCustomers.isNotEmpty) {
        emit(CustomerLoaded(_lastKnownCustomers));
      }
      emit(CustomerError(e.toString()));
    }
  }

  Future<void> _onSearch(
    CustomerSearch event,
    Emitter<CustomerState> emit,
  ) async {
    try {
      final customers = await _customerRepository.searchCustomers(event.query);
      // Don't update _lastKnownCustomers — search is a filtered view
      emit(CustomerLoaded(customers));
    } catch (e) {
      emit(CustomerError(e.toString()));
    }
  }

  Future<void> _onLoadWithDebt(
    CustomerLoadWithDebt event,
    Emitter<CustomerState> emit,
  ) async {
    try {
      final customers = await _customerRepository.getCustomersWithDebt();
      // Don't update _lastKnownCustomers — debt filter is a filtered view
      emit(CustomerLoaded(customers));
    } catch (e) {
      emit(CustomerError(e.toString()));
    }
  }

  Future<void> _onCreate(
    CustomerCreate event,
    Emitter<CustomerState> emit,
  ) async {
    try {
      final newId = await _customerRepository.createCustomer(event.customer);
      
      // Get the new customer with computed balance from DB
      final newCustomer = await _customerRepository.getCustomerById(newId);
      if (newCustomer != null) {
        _lastKnownCustomers = [..._lastKnownCustomers, newCustomer]
          ..sort((a, b) => a.name.compareTo(b.name));
      }
      
      emit(CustomerLoaded(List.from(_lastKnownCustomers)));
      emit(CustomerOperationSuccess(LocalizationService().get('customerCreated')));
      // Re-emit list to keep UI showing after success state
      emit(CustomerLoaded(List.from(_lastKnownCustomers)));
    } catch (e) {
      emit(CustomerError(e.toString()));
    }
  }

  Future<void> _onUpdate(
    CustomerUpdate event,
    Emitter<CustomerState> emit,
  ) async {
    final customerId = event.customer.id;
    if (customerId == null) {
      emit(CustomerError(LocalizationService().get('customerNotFound')));
      return;
    }
    try {
      await _customerRepository.updateCustomer(event.customer);
      
      // Get the updated customer with computed balance from DB
      final updatedCustomer = await _customerRepository.getCustomerById(customerId);
      if (updatedCustomer != null) {
        _lastKnownCustomers = _lastKnownCustomers.map((c) {
          return c.id == customerId ? updatedCustomer : c;
        }).toList();
      }
      
      emit(CustomerLoaded(List.from(_lastKnownCustomers)));
      emit(CustomerOperationSuccess(LocalizationService().get('customerUpdated')));
      // Re-emit list to keep UI showing after success state
      emit(CustomerLoaded(List.from(_lastKnownCustomers)));
    } catch (e) {
      emit(CustomerError(e.toString()));
    }
  }

  Future<void> _onDelete(
    CustomerDelete event,
    Emitter<CustomerState> emit,
  ) async {
    try {
      await _customerRepository.deleteCustomer(event.id);
      
      _lastKnownCustomers = _lastKnownCustomers.where((c) => c.id != event.id).toList();
      
      emit(CustomerLoaded(List.from(_lastKnownCustomers)));
      emit(CustomerOperationSuccess(LocalizationService().get('customerDeleted')));
      // Re-emit list to keep UI showing after success state
      emit(CustomerLoaded(List.from(_lastKnownCustomers)));
    } catch (e) {
      emit(CustomerError(e.toString()));
    }
  }

  Future<void> _onLoadTransactions(
    CustomerLoadTransactions event,
    Emitter<CustomerState> emit,
  ) async {
    try {
      final customer = await _customerRepository.getCustomerById(event.customerId);
      if (customer == null) {
        emit(CustomerError(LocalizationService().get('customerNotFound')));
        return;
      }
      final transactions = await _customerRepository.getCustomerTransactions(event.customerId);
      emit(CustomerTransactionsLoaded(customer: customer, transactions: transactions));
    } catch (e) {
      emit(CustomerError(e.toString()));
    }
  }
}
