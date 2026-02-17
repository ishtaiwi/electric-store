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
  bool _hasLoadedOnce = false;

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
    // Skip reload if already loaded (singleton behavior)
    if (_hasLoadedOnce && state is CustomerLoaded) {
      return;
    }
    emit(CustomerLoading());
    try {
      final customers = await _customerRepository.getAllCustomers();
      _hasLoadedOnce = true;
      emit(CustomerLoaded(customers));
    } catch (e) {
      emit(CustomerError(e.toString()));
    }
  }

  Future<void> _onRefresh(
    CustomerRefresh event,
    Emitter<CustomerState> emit,
  ) async {
    emit(CustomerLoading());
    try {
      final customers = await _customerRepository.getAllCustomers();
      _hasLoadedOnce = true;
      emit(CustomerLoaded(customers));
    } catch (e) {
      emit(CustomerError(e.toString()));
    }
  }

  Future<void> _onSearch(
    CustomerSearch event,
    Emitter<CustomerState> emit,
  ) async {
    emit(CustomerLoading());
    try {
      final customers = await _customerRepository.searchCustomers(event.query);
      emit(CustomerLoaded(customers));
    } catch (e) {
      emit(CustomerError(e.toString()));
    }
  }

  Future<void> _onLoadWithDebt(
    CustomerLoadWithDebt event,
    Emitter<CustomerState> emit,
  ) async {
    emit(CustomerLoading());
    try {
      final customers = await _customerRepository.getCustomersWithDebt();
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
      
      // Fast update: Get the new customer and add to list
      final newCustomer = await _customerRepository.getCustomerById(newId);
      if (newCustomer != null && state is CustomerLoaded) {
        final currentCustomers = (state as CustomerLoaded).customers;
        final updatedList = [...currentCustomers, newCustomer]
          ..sort((a, b) => a.name.compareTo(b.name));
        emit(CustomerLoaded(updatedList));
      } else {
        // If no state yet, force reload
        _hasLoadedOnce = false;
        add(CustomerLoadAll());
      }
      
      emit(CustomerOperationSuccess(LocalizationService().get('customerCreated')));
    } catch (e) {
      emit(CustomerError(e.toString()));
    }
  }

  Future<void> _onUpdate(
    CustomerUpdate event,
    Emitter<CustomerState> emit,
  ) async {
    try {
      await _customerRepository.updateCustomer(event.customer);
      
      // Fast update: Get the updated customer and replace in list
      final updatedCustomer = await _customerRepository.getCustomerById(event.customer.id!);
      if (updatedCustomer != null && state is CustomerLoaded) {
        final currentCustomers = (state as CustomerLoaded).customers;
        final updatedList = currentCustomers.map((c) {
          return c.id == event.customer.id ? updatedCustomer : c;
        }).toList();
        emit(CustomerLoaded(updatedList));
      }
      
      emit(CustomerOperationSuccess(LocalizationService().get('customerUpdated')));
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
      
      // Fast update: Remove from list immediately
      if (state is CustomerLoaded) {
        final currentCustomers = (state as CustomerLoaded).customers;
        final updatedList = currentCustomers.where((c) => c.id != event.id).toList();
        emit(CustomerLoaded(updatedList));
      }
      
      emit(CustomerOperationSuccess(LocalizationService().get('customerDeleted')));
    } catch (e) {
      emit(CustomerError(e.toString()));
    }
  }

  Future<void> _onLoadTransactions(
    CustomerLoadTransactions event,
    Emitter<CustomerState> emit,
  ) async {
    emit(CustomerLoading());
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
