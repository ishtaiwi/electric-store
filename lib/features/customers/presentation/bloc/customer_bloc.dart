import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/services/localization_service.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/customer_payment.dart';
import '../../domain/repositories/customer_repository.dart';

// Events
abstract class CustomerEvent extends Equatable {
  const CustomerEvent();

  @override
  List<Object?> get props => [];
}

class CustomerLoadAll extends CustomerEvent {}

class CustomerLoadMore extends CustomerEvent {}

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

class CustomerRecordPayment extends CustomerEvent {
  final CustomerPayment payment;

  const CustomerRecordPayment(this.payment);

  @override
  List<Object?> get props => [payment];
}

class CustomerUpdatePayment extends CustomerEvent {
  final CustomerPayment payment;

  const CustomerUpdatePayment(this.payment);

  @override
  List<Object?> get props => [payment];
}

class CustomerDeletePayment extends CustomerEvent {
  final int paymentId;
  final int customerId;

  const CustomerDeletePayment({required this.paymentId, required this.customerId});

  @override
  List<Object?> get props => [paymentId, customerId];
}

class CustomerLoadPayments extends CustomerEvent {
  final int customerId;

  const CustomerLoadPayments(this.customerId);

  @override
  List<Object?> get props => [customerId];
}

class CustomerLoadFinancialSummary extends CustomerEvent {
  final int customerId;

  const CustomerLoadFinancialSummary(this.customerId);

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
  final bool hasMore;
  final bool isLoadingMore;
  final String currentSearchQuery;
  final bool debtOnly;

  const CustomerLoaded({
    required this.customers,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.currentSearchQuery = '',
    this.debtOnly = false,
  });

  @override
  List<Object?> get props => [customers, hasMore, isLoadingMore, currentSearchQuery, debtOnly];
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

class CustomerPaymentsLoaded extends CustomerState {
  final List<CustomerPayment> payments;

  const CustomerPaymentsLoaded(this.payments);

  @override
  List<Object?> get props => [payments];
}

class CustomerFinancialSummaryLoaded extends CustomerState {
  final Map<String, dynamic> summary;
  final List<CustomerPayment> payments;

  const CustomerFinancialSummaryLoaded({required this.summary, required this.payments});

  @override
  List<Object?> get props => [summary, payments];
}

// BLoC
class CustomerBloc extends Bloc<CustomerEvent, CustomerState> {
  final CustomerRepository _customerRepository;
  static const int _pageSize = 50;
  
  // Persistent list that survives state transitions (success, error, transactions, etc.)
  List<Customer> _lastKnownCustomers = [];
  bool _hasMore = false;
  String _currentSearchQuery = '';
  bool _debtOnly = false;

  void _emitLoadedList(Emitter<CustomerState> emit) {
    emit(CustomerLoaded(
      customers: List.from(_lastKnownCustomers),
      hasMore: _hasMore,
      currentSearchQuery: _currentSearchQuery,
      debtOnly: _debtOnly,
    ));
  }

  Future<void> _refreshCustomerInList(int customerId) async {
    final updated = await _customerRepository.getCustomerById(customerId);
    if (updated == null) return;
    final idx = _lastKnownCustomers.indexWhere((c) => c.id == customerId);
    if (idx >= 0) {
      _lastKnownCustomers[idx] = updated;
    }
  }

  CustomerBloc(this._customerRepository) : super(CustomerInitial()) {
    on<CustomerLoadAll>(_onLoadAll);
    on<CustomerLoadMore>(_onLoadMore);
    on<CustomerRefresh>(_onRefresh);
    on<CustomerSearch>(_onSearch);
    on<CustomerLoadWithDebt>(_onLoadWithDebt);
    on<CustomerCreate>(_onCreate);
    on<CustomerUpdate>(_onUpdate);
    on<CustomerDelete>(_onDelete);
    on<CustomerLoadTransactions>(_onLoadTransactions);
    on<CustomerRecordPayment>(_onRecordPayment);
    on<CustomerUpdatePayment>(_onUpdatePayment);
    on<CustomerDeletePayment>(_onDeletePayment);
    on<CustomerLoadPayments>(_onLoadPayments);
    on<CustomerLoadFinancialSummary>(_onLoadFinancialSummary);
  }

  Future<void> _onLoadAll(
    CustomerLoadAll event,
    Emitter<CustomerState> emit,
  ) async {
    if (_lastKnownCustomers.isNotEmpty &&
        _currentSearchQuery.isEmpty &&
        !_debtOnly &&
        state is CustomerLoaded) {
      emit(CustomerLoaded(
        customers: _lastKnownCustomers,
        hasMore: _hasMore,
        currentSearchQuery: '',
        debtOnly: false,
      ));
      return;
    }
    emit(CustomerLoading());
    try {
      final customers = await _customerRepository.getCustomersPaginated(
        limit: _pageSize,
        offset: 0,
      );
      _lastKnownCustomers = customers;
      _hasMore = customers.length >= _pageSize;
      _currentSearchQuery = '';
      _debtOnly = false;
      emit(CustomerLoaded(
        customers: customers,
        hasMore: _hasMore,
        currentSearchQuery: '',
        debtOnly: false,
      ));
    } catch (e) {
      if (_lastKnownCustomers.isNotEmpty) {
        emit(CustomerLoaded(
          customers: _lastKnownCustomers,
          hasMore: _hasMore,
          currentSearchQuery: _currentSearchQuery,
          debtOnly: _debtOnly,
        ));
      }
      emit(CustomerError(e.toString()));
    }
  }

  Future<void> _onLoadMore(
    CustomerLoadMore event,
    Emitter<CustomerState> emit,
  ) async {
    if (state is! CustomerLoaded) return;
    final current = state as CustomerLoaded;
    if (!current.hasMore || current.isLoadingMore || _debtOnly) return;

    emit(CustomerLoaded(
      customers: current.customers,
      hasMore: current.hasMore,
      isLoadingMore: true,
      currentSearchQuery: _currentSearchQuery,
      debtOnly: _debtOnly,
    ));

    try {
      final List<Customer> more;
      if (_currentSearchQuery.isNotEmpty) {
        more = await _customerRepository.searchCustomersPaginated(
          _currentSearchQuery,
          limit: _pageSize,
          offset: current.customers.length,
        );
      } else {
        more = await _customerRepository.getCustomersPaginated(
          limit: _pageSize,
          offset: current.customers.length,
        );
      }

      final merged = [...current.customers, ...more];
      _lastKnownCustomers = merged;
      _hasMore = more.length >= _pageSize;
      emit(CustomerLoaded(
        customers: merged,
        hasMore: _hasMore,
        currentSearchQuery: _currentSearchQuery,
        debtOnly: _debtOnly,
      ));
    } catch (e) {
      emit(CustomerLoaded(
        customers: current.customers,
        hasMore: current.hasMore,
        currentSearchQuery: _currentSearchQuery,
        debtOnly: _debtOnly,
      ));
      emit(CustomerError(e.toString()));
    }
  }

  Future<void> _onRefresh(
    CustomerRefresh event,
    Emitter<CustomerState> emit,
  ) async {
    try {
      if (_debtOnly) {
        final customers = await _customerRepository.getCustomersWithDebt();
        emit(CustomerLoaded(
          customers: customers,
          hasMore: false,
          currentSearchQuery: '',
          debtOnly: true,
        ));
        return;
      }

      if (_currentSearchQuery.isNotEmpty) {
        final customers = await _customerRepository.searchCustomers(_currentSearchQuery);
        emit(CustomerLoaded(
          customers: customers,
          hasMore: false,
          currentSearchQuery: _currentSearchQuery,
          debtOnly: false,
        ));
        return;
      }

      final customers = await _customerRepository.getCustomersPaginated(
        limit: _pageSize,
        offset: 0,
      );
      _lastKnownCustomers = customers;
      _hasMore = customers.length >= _pageSize;
      _currentSearchQuery = '';
      _debtOnly = false;
      emit(CustomerLoaded(
        customers: customers,
        hasMore: _hasMore,
        currentSearchQuery: '',
        debtOnly: false,
      ));
    } catch (e) {
      if (_lastKnownCustomers.isNotEmpty) {
        emit(CustomerLoaded(
          customers: _lastKnownCustomers,
          hasMore: _hasMore,
          currentSearchQuery: _currentSearchQuery,
          debtOnly: _debtOnly,
        ));
      }
      emit(CustomerError(e.toString()));
    }
  }

  Future<void> _onSearch(
    CustomerSearch event,
    Emitter<CustomerState> emit,
  ) async {
    try {
      _currentSearchQuery = event.query;
      _debtOnly = false;
      final customers = await _customerRepository.searchCustomers(event.query);
      emit(CustomerLoaded(
        customers: customers,
        hasMore: false,
        currentSearchQuery: _currentSearchQuery,
        debtOnly: false,
      ));
    } catch (e) {
      emit(CustomerError(e.toString()));
    }
  }

  Future<void> _onLoadWithDebt(
    CustomerLoadWithDebt event,
    Emitter<CustomerState> emit,
  ) async {
    try {
      _debtOnly = true;
      _currentSearchQuery = '';
      final customers = await _customerRepository.getCustomersWithDebt();
      emit(CustomerLoaded(
        customers: customers,
        hasMore: false,
        currentSearchQuery: '',
        debtOnly: true,
      ));
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
      
      _emitLoadedList(emit);
      emit(CustomerOperationSuccess(LocalizationService().get('customerCreated')));
      _emitLoadedList(emit);
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
      
      _emitLoadedList(emit);
      emit(CustomerOperationSuccess(LocalizationService().get('customerUpdated')));
      _emitLoadedList(emit);
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
      
      _emitLoadedList(emit);
      emit(CustomerOperationSuccess(LocalizationService().get('customerDeleted')));
      _emitLoadedList(emit);
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

  Future<void> _onRecordPayment(
    CustomerRecordPayment event,
    Emitter<CustomerState> emit,
  ) async {
    try {
      await _customerRepository.recordPayment(event.payment);
      await _refreshCustomerInList(event.payment.customerId);
      _emitLoadedList(emit);
      emit(CustomerOperationSuccess(LocalizationService().get('paymentRecorded')));
      _emitLoadedList(emit);
    } catch (e) {
      emit(CustomerError(e.toString()));
    }
  }

  Future<void> _onUpdatePayment(
    CustomerUpdatePayment event,
    Emitter<CustomerState> emit,
  ) async {
    try {
      await _customerRepository.updatePayment(event.payment);
      await _refreshCustomerInList(event.payment.customerId);
      _emitLoadedList(emit);
      emit(CustomerOperationSuccess(LocalizationService().get('paymentUpdated')));
      _emitLoadedList(emit);
    } catch (e) {
      emit(CustomerError(e.toString()));
    }
  }

  Future<void> _onDeletePayment(
    CustomerDeletePayment event,
    Emitter<CustomerState> emit,
  ) async {
    try {
      await _customerRepository.deletePayment(event.paymentId);
      await _refreshCustomerInList(event.customerId);
      _emitLoadedList(emit);
      emit(CustomerOperationSuccess(LocalizationService().get('paymentDeleted')));
      _emitLoadedList(emit);
    } catch (e) {
      emit(CustomerError(e.toString()));
    }
  }

  Future<void> _onLoadPayments(
    CustomerLoadPayments event,
    Emitter<CustomerState> emit,
  ) async {
    try {
      final payments = await _customerRepository.getPaymentsByCustomer(event.customerId);
      emit(CustomerPaymentsLoaded(payments));
    } catch (e) {
      emit(CustomerError(e.toString()));
    }
  }

  Future<void> _onLoadFinancialSummary(
    CustomerLoadFinancialSummary event,
    Emitter<CustomerState> emit,
  ) async {
    try {
      final summary = await _customerRepository.getCustomerFinancialSummary(event.customerId);
      final payments = await _customerRepository.getPaymentsByCustomer(event.customerId);
      emit(CustomerFinancialSummaryLoaded(summary: summary, payments: payments));
    } catch (e) {
      emit(CustomerError(e.toString()));
    }
  }
}
