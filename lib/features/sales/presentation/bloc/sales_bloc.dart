import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'dart:async';
import '../../../../core/services/localization_service.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/domain/repositories/product_repository.dart';
import '../../../invoices/domain/entities/invoice.dart';
import '../../../invoices/domain/repositories/invoice_repository.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/repositories/sales_repository.dart';

// Events
abstract class SalesEvent extends Equatable {
  const SalesEvent();

  @override
  List<Object?> get props => [];
}

class SalesLoadProducts extends SalesEvent {}

class SalesRefresh extends SalesEvent {}

class SalesLoadMoreProducts extends SalesEvent {}

class SalesSearchProducts extends SalesEvent {
  final String query;

  const SalesSearchProducts(this.query);

  @override
  List<Object?> get props => [query];
}

class SalesAddToCart extends SalesEvent {
  final Product product;
  final int quantity;

  const SalesAddToCart({required this.product, this.quantity = 1});

  @override
  List<Object?> get props => [product, quantity];
}

class SalesRemoveFromCart extends SalesEvent {
  final int productId;

  const SalesRemoveFromCart(this.productId);

  @override
  List<Object?> get props => [productId];
}

class SalesUpdateCartQuantity extends SalesEvent {
  final int productId;
  final int quantity;

  const SalesUpdateCartQuantity({required this.productId, required this.quantity});

  @override
  List<Object?> get props => [productId, quantity];
}

class SalesUpdateCartPrice extends SalesEvent {
  final int productId;
  final double price;

  const SalesUpdateCartPrice({required this.productId, required this.price});

  @override
  List<Object?> get props => [productId, price];
}

class SalesClearCart extends SalesEvent {}

class SalesApplyDiscount extends SalesEvent {
  final double discount;

  const SalesApplyDiscount(this.discount);

  @override
  List<Object?> get props => [discount];
}

class SalesSetCustomer extends SalesEvent {
  final int? customerId;

  const SalesSetCustomer(this.customerId);

  @override
  List<Object?> get props => [customerId];
}

class SalesSetPaymentMethod extends SalesEvent {
  final String method;

  const SalesSetPaymentMethod(this.method);

  @override
  List<Object?> get props => [method];
}

class SalesCheckout extends SalesEvent {
  final int? userId;
  final double? paidAmount;
  final double discount;
  final int? customerId;
  final String paymentMethod;

  const SalesCheckout({
    this.userId,
    this.paidAmount,
    this.discount = 0,
    this.customerId,
    this.paymentMethod = 'cash',
  });

  @override
  List<Object?> get props => [userId, paidAmount, discount, customerId, paymentMethod];
}

class SalesLoadTodayInvoices extends SalesEvent {}

// States
abstract class SalesState extends Equatable {
  const SalesState();

  @override
  List<Object?> get props => [];
}

class SalesInitial extends SalesState {}

class SalesLoading extends SalesState {}

class SalesReady extends SalesState {
  final List<Product> products;
  final List<CartItem> cart;
  final double discount;
  final int? customerId;
  final String paymentMethod;
  final List<Invoice> todayInvoices;
  final bool hasMore;
  final bool isLoadingMore;
  final String currentSearchQuery;

  const SalesReady({
    this.products = const [],
    this.cart = const [],
    this.discount = 0,
    this.customerId,
    this.paymentMethod = 'cash',
    this.todayInvoices = const [],
    this.hasMore = true,
    this.isLoadingMore = false,
    this.currentSearchQuery = '',
  });

  double get subtotal => cart.fold(0.0, (sum, item) => sum + item.totalPrice);
  double get total => subtotal - discount;
  double get totalProfit => cart.fold(0.0, (sum, item) => sum + item.profit) - discount;
  int get itemCount => cart.fold(0, (sum, item) => sum + item.quantity);

  SalesReady copyWith({
    List<Product>? products,
    List<CartItem>? cart,
    double? discount,
    int? customerId,
    bool clearCustomerId = false,
    String? paymentMethod,
    List<Invoice>? todayInvoices,
    bool? hasMore,
    bool? isLoadingMore,
    String? currentSearchQuery,
  }) {
    return SalesReady(
      products: products ?? this.products,
      cart: cart ?? this.cart,
      discount: discount ?? this.discount,
      customerId: clearCustomerId ? null : (customerId ?? this.customerId),
      paymentMethod: paymentMethod ?? this.paymentMethod,
      todayInvoices: todayInvoices ?? this.todayInvoices,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      currentSearchQuery: currentSearchQuery ?? this.currentSearchQuery,
    );
  }

  @override
  List<Object?> get props => [products, cart, discount, customerId, paymentMethod, todayInvoices, hasMore, isLoadingMore, currentSearchQuery];
}

class SalesCheckoutSuccess extends SalesState {
  final Invoice invoice;

  const SalesCheckoutSuccess(this.invoice);

  @override
  List<Object?> get props => [invoice];
}

class SalesError extends SalesState {
  final String message;

  const SalesError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class SalesBloc extends Bloc<SalesEvent, SalesState> {
  final SalesRepository _salesRepository;
  final ProductRepository _productRepository;
  final InvoiceRepository _invoiceRepository;
  Timer? _searchDebounce;
  static const _pageSize = 50;

  SalesBloc(this._salesRepository, this._productRepository, this._invoiceRepository)
      : super(SalesInitial()) {
    on<SalesLoadProducts>(_onLoadProducts);
    on<SalesRefresh>(_onRefresh);
    on<SalesLoadMoreProducts>(_onLoadMoreProducts);
    on<SalesSearchProducts>(_onSearchProducts);
    on<SalesAddToCart>(_onAddToCart);
    on<SalesRemoveFromCart>(_onRemoveFromCart);
    on<SalesUpdateCartQuantity>(_onUpdateCartQuantity);
    on<SalesUpdateCartPrice>(_onUpdateCartPrice);
    on<SalesClearCart>(_onClearCart);
    on<SalesApplyDiscount>(_onApplyDiscount);
    on<SalesSetCustomer>(_onSetCustomer);
    on<SalesSetPaymentMethod>(_onSetPaymentMethod);
    on<SalesCheckout>(_onCheckout);
    on<SalesLoadTodayInvoices>(_onLoadTodayInvoices);
  }

  @override
  Future<void> close() {
    _searchDebounce?.cancel();
    return super.close();
  }

  SalesReady get _currentState {
    if (state is SalesReady) {
      return state as SalesReady;
    }
    return const SalesReady();
  }

  Future<void> _onLoadProducts(
    SalesLoadProducts event,
    Emitter<SalesState> emit,
  ) async {
    final currentState = _currentState;
    
    // If products are already loaded, don't reload (skip loading state)
    if (currentState.products.isNotEmpty && state is SalesReady) {
      // Just refresh today's invoices without showing loading
      try {
        final todayInvoices = await _invoiceRepository.getInvoicesToday();
        emit(currentState.copyWith(todayInvoices: todayInvoices));
      } catch (_) {
        // Ignore errors on silent refresh
      }
      return;
    }
    
    emit(SalesLoading());
    try {
      // Use pagination - load first 50 products for faster initial load
      final products = await _productRepository.getProductsPaginated(limit: _pageSize, offset: 0);
      final todayInvoices = await _invoiceRepository.getInvoicesToday();
      emit(currentState.copyWith(
        products: products, 
        todayInvoices: todayInvoices,
        hasMore: products.length >= _pageSize,
        currentSearchQuery: '',
      ));
    } catch (e) {
      emit(SalesError(e.toString()));
    }
  }

  Future<void> _onRefresh(
    SalesRefresh event,
    Emitter<SalesState> emit,
  ) async {
    final currentState = _currentState;
    emit(SalesLoading());
    try {
      final products = await _productRepository.getProductsPaginated(limit: _pageSize, offset: 0);
      final todayInvoices = await _invoiceRepository.getInvoicesToday();
      emit(currentState.copyWith(
        products: products, 
        todayInvoices: todayInvoices,
        hasMore: products.length >= _pageSize,
        currentSearchQuery: '',
      ));
    } catch (e) {
      emit(SalesError(e.toString()));
    }
  }

  Future<void> _onLoadMoreProducts(
    SalesLoadMoreProducts event,
    Emitter<SalesState> emit,
  ) async {
    final currentState = _currentState;
    if (currentState.isLoadingMore || !currentState.hasMore) return;
    
    emit(currentState.copyWith(isLoadingMore: true));
    try {
      List<Product> moreProducts;
      if (currentState.currentSearchQuery.isEmpty) {
        moreProducts = await _productRepository.getProductsPaginated(
          limit: _pageSize, 
          offset: currentState.products.length,
        );
      } else {
        moreProducts = await _productRepository.searchProductsPaginated(
          currentState.currentSearchQuery,
          limit: _pageSize,
          offset: currentState.products.length,
        );
      }
      
      final allProducts = [...currentState.products, ...moreProducts];
      emit(currentState.copyWith(
        products: allProducts,
        hasMore: moreProducts.length >= _pageSize,
        isLoadingMore: false,
      ));
    } catch (e) {
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onSearchProducts(
    SalesSearchProducts event,
    Emitter<SalesState> emit,
  ) async {
    final currentState = _currentState;
    
    // If empty query, reload all products
    if (event.query.isEmpty) {
      try {
        final products = await _productRepository.getProductsPaginated(limit: _pageSize, offset: 0);
        emit(currentState.copyWith(
          products: products,
          hasMore: products.length >= _pageSize,
          currentSearchQuery: '',
        ));
      } catch (e) {
        emit(SalesError(e.toString()));
      }
      return;
    }
    
    try {
      final products = await _productRepository.searchProducts(event.query);
      emit(currentState.copyWith(
        products: products,
        hasMore: products.length >= 100,
        currentSearchQuery: event.query,
      ));
    } catch (e) {
      emit(SalesError(e.toString()));
    }
  }

  void _onAddToCart(
    SalesAddToCart event,
    Emitter<SalesState> emit,
  ) {
    final currentState = _currentState;
    final cart = List<CartItem>.from(currentState.cart);

    // Check if product already in cart
    final existingIndex = cart.indexWhere((item) => item.product.id == event.product.id);

    if (existingIndex >= 0) {
      // Update quantity
      final existing = cart[existingIndex];
      final newQuantity = existing.quantity + event.quantity;
      
      // Check stock
      if (newQuantity <= event.product.quantity) {
        cart[existingIndex] = existing.copyWith(quantity: newQuantity);
      }
    } else {
      // Add new item
      if (event.quantity <= event.product.quantity) {
        cart.add(CartItem(product: event.product, quantity: event.quantity));
      }
    }

    emit(currentState.copyWith(cart: cart));
  }

  void _onRemoveFromCart(
    SalesRemoveFromCart event,
    Emitter<SalesState> emit,
  ) {
    final currentState = _currentState;
    final cart = currentState.cart.where((item) => item.product.id != event.productId).toList();
    emit(currentState.copyWith(cart: cart));
  }

  void _onUpdateCartQuantity(
    SalesUpdateCartQuantity event,
    Emitter<SalesState> emit,
  ) {
    final currentState = _currentState;
    final cart = List<CartItem>.from(currentState.cart);

    final index = cart.indexWhere((item) => item.product.id == event.productId);
    if (index >= 0) {
      if (event.quantity <= 0) {
        cart.removeAt(index);
      } else if (event.quantity <= cart[index].product.quantity) {
        cart[index] = cart[index].copyWith(quantity: event.quantity);
      }
    }

    emit(currentState.copyWith(cart: cart));
  }

  void _onUpdateCartPrice(
    SalesUpdateCartPrice event,
    Emitter<SalesState> emit,
  ) {
    final currentState = _currentState;
    final cart = List<CartItem>.from(currentState.cart);

    final index = cart.indexWhere((item) => item.product.id == event.productId);
    if (index >= 0) {
      cart[index] = cart[index].copyWith(customPrice: event.price);
    }

    emit(currentState.copyWith(cart: cart));
  }

  void _onClearCart(
    SalesClearCart event,
    Emitter<SalesState> emit,
  ) {
    final currentState = _currentState;
    emit(currentState.copyWith(cart: [], discount: 0, clearCustomerId: true));
  }

  void _onApplyDiscount(
    SalesApplyDiscount event,
    Emitter<SalesState> emit,
  ) {
    final currentState = _currentState;
    emit(currentState.copyWith(discount: event.discount));
  }

  void _onSetCustomer(
    SalesSetCustomer event,
    Emitter<SalesState> emit,
  ) {
    final currentState = _currentState;
    emit(SalesReady(
      products: currentState.products,
      cart: currentState.cart,
      discount: currentState.discount,
      customerId: event.customerId,
      paymentMethod: currentState.paymentMethod,
      todayInvoices: currentState.todayInvoices,
    ));
  }

  void _onSetPaymentMethod(
    SalesSetPaymentMethod event,
    Emitter<SalesState> emit,
  ) {
    final currentState = _currentState;
    emit(currentState.copyWith(paymentMethod: event.method));
  }

  Future<void> _onCheckout(
    SalesCheckout event,
    Emitter<SalesState> emit,
  ) async {
    final currentState = _currentState;
    
    if (currentState.cart.isEmpty) {
      emit(SalesError(LocalizationService().get('cartEmpty')));
      return;
    }

    // Use discount from event parameter (passed directly from checkout dialog)
    final discount = event.discount;
    final customerId = event.customerId ?? currentState.customerId;
    final paymentMethod = event.paymentMethod.isNotEmpty ? event.paymentMethod : currentState.paymentMethod;

    emit(SalesLoading());
    try {
      final invoice = await _salesRepository.createSale(
        items: currentState.cart,
        customerId: customerId,
        discountAmount: discount,
        paymentMethod: paymentMethod,
        paidAmount: event.paidAmount,
        userId: event.userId,
      );
      
      emit(SalesCheckoutSuccess(invoice));
      
      // Reset state
      final products = await _productRepository.getAllProducts();
      final todayInvoices = await _invoiceRepository.getInvoicesToday();
      emit(SalesReady(products: products, todayInvoices: todayInvoices));
    } catch (e) {
      emit(SalesError(e.toString()));
    }
  }

  Future<void> _onLoadTodayInvoices(
    SalesLoadTodayInvoices event,
    Emitter<SalesState> emit,
  ) async {
    final currentState = _currentState;
    try {
      final todayInvoices = await _invoiceRepository.getInvoicesToday();
      emit(currentState.copyWith(todayInvoices: todayInvoices));
    } catch (e) {
      emit(SalesError(e.toString()));
    }
  }
}
