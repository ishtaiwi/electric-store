import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/services/smart_search_service.dart';
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

class SalesAddCustomToCart extends SalesEvent {
  final String name;
  final double price;
  final int quantity;
  final String? note;

  const SalesAddCustomToCart({
    required this.name,
    required this.price,
    this.quantity = 1,
    this.note,
  });

  @override
  List<Object?> get props => [name, price, quantity, note];
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
  final SmartSearchService _smartSearchService = SmartSearchService();
  static const _pageSize = 50;

  SalesBloc(this._salesRepository, this._productRepository, this._invoiceRepository)
      : super(SalesInitial()) {
    on<SalesLoadProducts>(_onLoadProducts);
    on<SalesRefresh>(_onRefresh);
    on<SalesLoadMoreProducts>(_onLoadMoreProducts);
    on<SalesSearchProducts>(_onSearchProducts);
    on<SalesAddToCart>(_onAddToCart);
    on<SalesAddCustomToCart>(_onAddCustomToCart);
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
      // Restore previous state so cart is not lost, then signal error
      emit(currentState);
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
    
    // If empty query, reload all products immediately
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
      // Use smart search for fuzzy matching and natural language understanding
      final smartResults = await _smartSearchService.smartSearchProducts(event.query);
      
      // Convert smart search results to Product entities (safe casts)
      final products = smartResults.map((map) => Product(
        id: map['id'] as int?,
        name: (map['name'] as String?) ?? '',
        barcode: map['barcode'] as String?,
        quantity: (map['quantity'] as int?) ?? 0,
        price: (map['price'] as num?)?.toDouble() ?? 0.0,
        costPrice: (map['cost_price'] as num?)?.toDouble() ?? 0.0,
        note: map['note'] as String?,
        supplier: map['supplier'] as String?,
        minStock: (map['min_stock'] as int?) ?? 5,
        lastUpdated: map['last_updated'] != null
            ? DateTime.tryParse(map['last_updated'].toString())
            : null,
      )).toList();
      
      emit(currentState.copyWith(
        products: products,
        hasMore: false, // Smart search returns all relevant results
        currentSearchQuery: event.query,
      ));
    } catch (e) {
      // Fallback to regular search on error
      try {
        final products = await _productRepository.searchProductsPaginated(
          event.query,
          limit: _pageSize,
          offset: 0,
        );
        emit(currentState.copyWith(
          products: products,
          hasMore: products.length >= _pageSize,
          currentSearchQuery: event.query,
        ));
      } catch (fallbackError) {
        emit(SalesError(fallbackError.toString()));
      }
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

  /// Counter for generating unique negative IDs for custom products
  int _customProductIdCounter = -1;

  void _onAddCustomToCart(
    SalesAddCustomToCart event,
    Emitter<SalesState> emit,
  ) {
    final currentState = _currentState;
    final cart = List<CartItem>.from(currentState.cart);

    // Create a temporary Product with a unique negative ID
    final customProduct = Product(
      id: _customProductIdCounter--,
      name: event.name,
      quantity: 999999, // No stock limit for custom products
      price: event.price,
      costPrice: 0,
      note: 'custom',
    );

    cart.add(CartItem(product: customProduct, quantity: event.quantity, note: event.note));
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
      } else {
        // Custom products (negative IDs) have no stock limit
        final isCustom = event.productId < 0;
        if (isCustom || event.quantity <= cart[index].product.quantity) {
          cart[index] = cart[index].copyWith(quantity: event.quantity);
        }
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
    if (event.customerId == null) {
      emit(currentState.copyWith(clearCustomerId: true));
    } else {
      emit(currentState.copyWith(customerId: event.customerId));
    }
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
      final Invoice invoice;

      if (customerId != null) {
        invoice = await _salesRepository.addToCustomerAccount(
          items: currentState.cart,
          customerId: customerId,
          discountAmount: discount,
          paidAmount: event.paidAmount,
          paymentMethod: paymentMethod,
          userId: event.userId,
        );
      } else {
        invoice = await _salesRepository.createSale(
          items: currentState.cart,
          discountAmount: discount,
          paymentMethod: paymentMethod,
          paidAmount: event.paidAmount,
          userId: event.userId,
        );
      }
      
      emit(SalesCheckoutSuccess(invoice));
      
      // Reset state — use paginated load and wrap in separate try-catch
      // so a refresh failure doesn't mask the successful checkout
      try {
        final products = await _productRepository.getProductsPaginated(limit: _pageSize, offset: 0);
        final todayInvoices = await _invoiceRepository.getInvoicesToday();
        emit(SalesReady(
          products: products,
          todayInvoices: todayInvoices,
          hasMore: products.length >= _pageSize,
        ));
      } catch (_) {
        // Checkout succeeded — just emit an empty ready state so UI is usable
        emit(const SalesReady());
      }
    } catch (e) {
      // Checkout itself failed — restore cart so user doesn't lose data
      emit(currentState);
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
    } catch (_) {
      // Don't emit SalesError — this is a background refresh.
      // Keep current state intact so the cart is preserved.
    }
  }
}
