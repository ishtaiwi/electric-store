import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/services/smart_search_service.dart';
import '../../domain/entities/product.dart';
import '../../domain/exceptions/product_in_use_exception.dart';
import '../../domain/repositories/product_repository.dart';

// Events
abstract class ProductEvent extends Equatable {
  const ProductEvent();

  @override
  List<Object?> get props => [];
}

class ProductLoadAll extends ProductEvent {}

class ProductRefresh extends ProductEvent {}

class ProductLoadMore extends ProductEvent {}

class ProductSearch extends ProductEvent {
  final String query;

  const ProductSearch(this.query);

  @override
  List<Object?> get props => [query];
}

class ProductLoadLowStock extends ProductEvent {}

class ProductCreate extends ProductEvent {
  final Product product;

  const ProductCreate(this.product);

  @override
  List<Object?> get props => [product];
}

class ProductUpdate extends ProductEvent {
  final Product product;

  const ProductUpdate(this.product);

  @override
  List<Object?> get props => [product];
}

class ProductDelete extends ProductEvent {
  final int id;

  const ProductDelete(this.id);

  @override
  List<Object?> get props => [id];
}

class ProductAdjustStock extends ProductEvent {
  final int productId;
  final int adjustment;
  final String type;
  final String? reason;
  final int? userId;

  const ProductAdjustStock({
    required this.productId,
    required this.adjustment,
    required this.type,
    this.reason,
    this.userId,
  });

  @override
  List<Object?> get props => [productId, adjustment, type, reason, userId];
}

/// Fast update: update product quantities after sale (multiple products)
class ProductQuantitiesSold extends ProductEvent {
  final Map<int, int> productQuantities; // productId -> quantity sold

  const ProductQuantitiesSold(this.productQuantities);

  @override
  List<Object?> get props => [productQuantities];
}

// States
abstract class ProductState extends Equatable {
  const ProductState();

  @override
  List<Object?> get props => [];
}

class ProductInitial extends ProductState {}

class ProductLoading extends ProductState {}

class ProductLoaded extends ProductState {
  final List<Product> products;
  final bool hasMore;
  final bool isLoadingMore;
  final String currentSearchQuery;

  const ProductLoaded({
    required this.products,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.currentSearchQuery = '',
  });

  @override
  List<Object?> get props => [products, hasMore, isLoadingMore, currentSearchQuery];
}

class ProductError extends ProductState {
  final String message;

  const ProductError(this.message);

  @override
  List<Object?> get props => [message];
}

class ProductOperationSuccess extends ProductState {
  final String message;

  const ProductOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class ProductBloc extends Bloc<ProductEvent, ProductState> {
  final ProductRepository _productRepository;
  final SmartSearchService _smartSearchService = SmartSearchService();
  static const int _pageSize = 50;

  ProductBloc(this._productRepository) : super(ProductInitial()) {
    on<ProductLoadAll>(_onLoadAll);
    on<ProductRefresh>(_onRefresh);
    on<ProductLoadMore>(_onLoadMore);
    on<ProductSearch>(_onSearch);
    on<ProductLoadLowStock>(_onLoadLowStock);
    on<ProductCreate>(_onCreate);
    on<ProductUpdate>(_onUpdate);
    on<ProductDelete>(_onDelete);
    on<ProductAdjustStock>(_onAdjustStock);
    on<ProductQuantitiesSold>(_onQuantitiesSold);
  }

  Future<void> _onLoadAll(
    ProductLoadAll event,
    Emitter<ProductState> emit,
  ) async {
    // If we already have the full product list (not from a search), re-emit it
    if (state is ProductLoaded && 
        (state as ProductLoaded).products.isNotEmpty &&
        (state as ProductLoaded).currentSearchQuery.isEmpty) {
      return;
    }
    
    emit(ProductLoading());
    try {
      final products = await _productRepository.getProductsPaginated(limit: _pageSize, offset: 0);
      emit(ProductLoaded(
        products: products,
        hasMore: products.length >= _pageSize,
        currentSearchQuery: '',
      ));
    } catch (e) {
      emit(ProductError(e.toString()));
    }
  }

  Future<void> _onRefresh(
    ProductRefresh event,
    Emitter<ProductState> emit,
  ) async {
    emit(ProductLoading());
    try {
      final products = await _productRepository.getProductsPaginated(limit: _pageSize, offset: 0);
      emit(ProductLoaded(
        products: products,
        hasMore: products.length >= _pageSize,
        currentSearchQuery: '',
      ));
    } catch (e) {
      emit(ProductError(e.toString()));
    }
  }

  Future<void> _onLoadMore(
    ProductLoadMore event,
    Emitter<ProductState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ProductLoaded || currentState.isLoadingMore || !currentState.hasMore) {
      return;
    }

    emit(ProductLoaded(
      products: currentState.products,
      hasMore: currentState.hasMore,
      isLoadingMore: true,
      currentSearchQuery: currentState.currentSearchQuery,
    ));

    try {
      List<Product> moreProducts;
      if (currentState.currentSearchQuery.isEmpty) {
        moreProducts = await _productRepository.getProductsPaginated(
          limit: _pageSize,
          offset: currentState.products.length,
        );
      } else {
        // For search, load all results (already limited in repo)
        moreProducts = [];
      }

      final allProducts = [...currentState.products, ...moreProducts];
      emit(ProductLoaded(
        products: allProducts,
        hasMore: moreProducts.length >= _pageSize,
        isLoadingMore: false,
        currentSearchQuery: currentState.currentSearchQuery,
      ));
    } catch (e) {
      emit(ProductLoaded(
        products: currentState.products,
        hasMore: currentState.hasMore,
        isLoadingMore: false,
        currentSearchQuery: currentState.currentSearchQuery,
      ));
    }
  }

  Future<void> _onSearch(
    ProductSearch event,
    Emitter<ProductState> emit,
  ) async {
    if (event.query.isEmpty) {
      add(ProductLoadAll());
      return;
    }

    emit(ProductLoading());
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
      
      emit(ProductLoaded(
        products: products,
        hasMore: false,
        currentSearchQuery: event.query,
      ));
    } catch (e) {
      // Fallback to regular search on error
      try {
        final products = await _productRepository.searchProducts(event.query);
        emit(ProductLoaded(
          products: products,
          hasMore: false,
          currentSearchQuery: event.query,
        ));
      } catch (fallbackError) {
        emit(ProductError(fallbackError.toString()));
      }
    }
  }

  Future<void> _onLoadLowStock(
    ProductLoadLowStock event,
    Emitter<ProductState> emit,
  ) async {
    emit(ProductLoading());
    try {
      final products = await _productRepository.getLowStockProducts();
      emit(ProductLoaded(products: products));
    } catch (e) {
      emit(ProductError(e.toString()));
    }
  }

  Future<void> _onCreate(
    ProductCreate event,
    Emitter<ProductState> emit,
  ) async {
    final currentState = state;
    List<Product> currentList = [];
    if (currentState is ProductLoaded) {
      currentList = List.from(currentState.products);
    }
    
    try {
      final createdId = await _productRepository.createProduct(event.product);
      final createdProduct = event.product.copyWith(id: createdId);
      
      // Fast update: add to beginning of list
      currentList.insert(0, createdProduct);
      emit(ProductLoaded(
        products: currentList,
        hasMore: currentState is ProductLoaded ? (currentState).hasMore : false,
      ));
      
      emit(ProductOperationSuccess(LocalizationService().get('productCreated')));
      
      // Re-emit list to keep UI showing
      emit(ProductLoaded(
        products: currentList,
        hasMore: currentState is ProductLoaded ? (currentState).hasMore : false,
      ));
    } catch (e) {
      emit(ProductError(e.toString()));
    }
  }

  Future<void> _onUpdate(
    ProductUpdate event,
    Emitter<ProductState> emit,
  ) async {
    final currentState = state;
    List<Product> currentList = [];
    if (currentState is ProductLoaded) {
      currentList = List.from(currentState.products);
    }
    
    try {
      await _productRepository.updateProduct(event.product);
      
      // Fast update: replace in list directly
      final index = currentList.indexWhere((p) => p.id == event.product.id);
      if (index != -1) {
        currentList[index] = event.product;
      }
      
      emit(ProductLoaded(
        products: currentList,
        hasMore: currentState is ProductLoaded ? (currentState).hasMore : false,
      ));
      
      emit(ProductOperationSuccess(LocalizationService().get('productUpdated')));
      
      // Re-emit list to keep UI showing
      emit(ProductLoaded(
        products: currentList,
        hasMore: currentState is ProductLoaded ? (currentState).hasMore : false,
      ));
    } catch (e) {
      emit(ProductError(e.toString()));
    }
  }

  Future<void> _onDelete(
    ProductDelete event,
    Emitter<ProductState> emit,
  ) async {
    final currentState = state;
    List<Product> currentList = [];
    if (currentState is ProductLoaded) {
      currentList = List.from(currentState.products);
    }
    
    try {
      await _productRepository.deleteProduct(event.id);
      
      // Fast update: remove from list directly
      currentList.removeWhere((p) => p.id == event.id);
      
      emit(ProductLoaded(
        products: currentList,
        hasMore: currentState is ProductLoaded ? (currentState).hasMore : false,
      ));
      
      emit(ProductOperationSuccess(LocalizationService().get('productDeleted')));
      
      // Re-emit list to keep UI showing
      emit(ProductLoaded(
        products: currentList,
        hasMore: currentState is ProductLoaded ? (currentState).hasMore : false,
      ));
    } catch (e) {
      if (e is ProductInUseException) {
        emit(ProductError(LocalizationService().get('cannotDeleteProductInUse')));
      } else {
        emit(ProductError(e.toString()));
      }
    }
  }

  Future<void> _onAdjustStock(
    ProductAdjustStock event,
    Emitter<ProductState> emit,
  ) async {
    final currentState = state;
    List<Product> currentList = [];
    if (currentState is ProductLoaded) {
      currentList = List.from(currentState.products);
    }
    
    try {
      await _productRepository.adjustStock(
        event.productId,
        event.adjustment,
        event.type,
        event.reason,
        event.userId,
      );
      
      // Fast update: adjust quantity in list directly
      final index = currentList.indexWhere((p) => p.id == event.productId);
      if (index != -1) {
        final product = currentList[index];
        final newQuantity = event.type == 'sale' 
            ? product.quantity - event.adjustment
            : product.quantity + event.adjustment;
        currentList[index] = product.copyWith(quantity: newQuantity);
      }
      
      emit(ProductLoaded(
        products: currentList,
        hasMore: currentState is ProductLoaded ? (currentState).hasMore : false,
      ));
      
      emit(ProductOperationSuccess(LocalizationService().get('stockAdjusted')));
      
      // Re-emit list to keep UI showing
      emit(ProductLoaded(
        products: currentList,
        hasMore: currentState is ProductLoaded ? (currentState).hasMore : false,
      ));
    } catch (e) {
      emit(ProductError(e.toString()));
    }
  }

  /// Fast update: update product quantities after a sale
  void _onQuantitiesSold(
    ProductQuantitiesSold event,
    Emitter<ProductState> emit,
  ) {
    final currentState = state;
    if (currentState is ProductLoaded) {
      final currentList = List<Product>.from(currentState.products);
      
      for (final entry in event.productQuantities.entries) {
        final productId = entry.key;
        final quantitySold = entry.value;
        final index = currentList.indexWhere((p) => p.id == productId);
        if (index != -1) {
          final product = currentList[index];
          currentList[index] = product.copyWith(quantity: product.quantity - quantitySold);
        }
      }
      
      emit(ProductLoaded(
        products: currentList,
        hasMore: currentState.hasMore,
      ));
    }
  }
}
