import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/product.dart';
import '../bloc/product_bloc.dart';
import '../widgets/product_form_dialog.dart';
import '../widgets/stock_adjustment_dialog.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _debounceTimer;
  bool _showLowStock = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    if (value.isEmpty) {
      context.read<ProductBloc>().add(ProductLoadAll());
      setState(() {});
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        context.read<ProductBloc>().add(ProductSearch(value));
      }
    });
    setState(() {});
  }

  void _showProductDialog({Product? product}) {
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<ProductBloc>(),
        child: ProductFormDialog(product: product),
      ),
    );
  }

  void _showStockDialog(Product product) {
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<ProductBloc>(),
        child: StockAdjustmentDialog(product: product),
      ),
    );
  }

  void _confirmDelete(Product product) {
    final l10n = LocalizationService();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.get('confirmDelete')),
        content: Text('${l10n.get('confirmDeleteItem')} "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.get('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              this.context.read<ProductBloc>().add(ProductDelete(product.id!));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(l10n.get('delete')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProductBloc, ProductState>(
      listener: (context, state) {
        if (state is ProductOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.success,
            ),
          );
        } else if (state is ProductError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      builder: (context, state) {
        List<Product> products = [];
        bool hasMore = false;
        bool isLoadingMore = false;

        if (state is ProductLoaded) {
          products = state.products;
          hasMore = state.hasMore;
          isLoadingMore = state.isLoadingMore;
        }

        return LayoutBuilder(
          builder: (context, outerConstraints) {
            final isNarrow = outerConstraints.maxWidth < 600;

            return Padding(
              padding: EdgeInsets.all(isNarrow ? 12 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          LocalizationService().get('products'),
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: isNarrow ? 20 : null,
                              ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showProductDialog(),
                        icon: const Icon(Icons.add),
                        label: isNarrow ? const SizedBox.shrink() : Text(LocalizationService().get('addProduct')),
                      ),
                    ],
                  ),
                  SizedBox(height: isNarrow ? 12 : 24),

                  // Filters
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Search
                      SizedBox(
                        width: isNarrow ? outerConstraints.maxWidth - 24 : outerConstraints.maxWidth * 0.5,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            decoration: InputDecoration(
                              hintText: LocalizationService().get('searchProducts'),
                              hintStyle: TextStyle(color: Colors.grey[500]),
                              prefixIcon: const Icon(Icons.search, size: 24),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_searchController.text.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _debounceTimer?.cancel();
                                        _searchController.clear();
                                        context.read<ProductBloc>().add(ProductLoadAll());
                                        setState(() {});
                                      },
                                    ),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.qr_code_scanner, color: AppColors.primary),
                                  ),
                                ],
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            ),
                            style: const TextStyle(fontSize: 16),
                            onChanged: _onSearchChanged,
                            onSubmitted: (value) {
                              final state = context.read<ProductBloc>().state;
                              if (state is ProductLoaded && state.products.isNotEmpty) {
                                final product = state.products.firstWhere(
                                  (p) => p.barcode == value,
                                  orElse: () => state.products.first,
                                );
                                _showProductDialog(product: product);
                              }
                            },
                          ),
                        ),
                      ),

                      // Low stock filter
                      FilterChip(
                        label: Text(LocalizationService().get('lowStock')),
                        selected: _showLowStock,
                        onSelected: (selected) {
                          setState(() => _showLowStock = selected);
                          if (selected) {
                            context.read<ProductBloc>().add(ProductLoadLowStock());
                          } else {
                            context.read<ProductBloc>().add(ProductLoadAll());
                          }
                        },
                        selectedColor: AppColors.warning.withOpacity(0.2),
                        checkmarkColor: AppColors.warning,
                      ),

                      // Refresh
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _showLowStock = false;
                          });
                          context.read<ProductBloc>().add(ProductRefresh());
                        },
                        tooltip: LocalizationService().get('refresh'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

              // Products count
              Text(
                '${products.length} products',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 8),

              // Data Table
              Expanded(
                child: state is ProductLoading
                    ? _buildLoadingSkeleton()
                    : products.isEmpty
                        ? _buildEmptyProductsState()
                        : _buildProductsTable(products, hasMore, isLoadingMore),
              ),
            ],
          ),
        );
          },
        );
      },
    );
  }

  Widget _buildProductsTable(List<Product> products, bool hasMore, bool isLoadingMore) {
    final l10n = LocalizationService();
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isCompact = screenWidth < 800;
        final isMedium = screenWidth >= 800 && screenWidth < 1100;

        return Column(
          children: [
            Expanded(
              child: Container(
                margin: EdgeInsets.all(isCompact ? 8 : 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: constraints.maxWidth - (isCompact ? 16 : 32)),
                      child: SingleChildScrollView(
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(AppColors.primary.withOpacity(0.1)),
                          dataRowMinHeight: 48,
                          dataRowMaxHeight: 60,
                          columnSpacing: isCompact ? 12 : isMedium ? 16 : 24,
                          horizontalMargin: isCompact ? 8 : 16,
                          columns: [
                            DataColumn(label: Text(l10n.get('name'), style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l10n.get('barcode'), style: const TextStyle(fontWeight: FontWeight.bold))),
                            if (!isCompact)
                              DataColumn(label: Text(l10n.get('notes'), style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l10n.get('price'), style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                            if (!isCompact)
                              DataColumn(label: Text(l10n.get('cost'), style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                            DataColumn(label: Text(l10n.get('quantity'), style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                            if (!isCompact)
                              DataColumn(label: Text(l10n.get('status'), style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l10n.get('actions'), style: const TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: products.map((product) {
                            final isOutOfStock = product.isOutOfStock;
                            final isLowStock = product.isLowStock && !isOutOfStock;

                            return DataRow(
                              color: WidgetStateProperty.resolveWith((states) {
                                if (isOutOfStock) return Colors.grey[100];
                                if (states.contains(WidgetState.hovered)) {
                                  return AppColors.primary.withOpacity(0.05);
                                }
                                return null;
                              }),
                              cells: [
                                // Name
                                DataCell(
                                  ConstrainedBox(
                                    constraints: BoxConstraints(maxWidth: isCompact ? 100 : isMedium ? 130 : 180),
                                    child: Text(
                                      product.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: isOutOfStock ? Colors.grey : AppColors.textPrimary,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                // Barcode
                                DataCell(
                                  Text(
                                    product.barcode ?? '-',
                                    style: TextStyle(
                                      color: isOutOfStock ? Colors.grey : Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                // Notes (hidden on compact)
                                if (!isCompact)
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: BoxConstraints(maxWidth: isMedium ? 80 : 120),
                                      child: Text(
                                        product.note ?? '-',
                                        style: TextStyle(
                                          color: isOutOfStock ? Colors.grey : Colors.grey[600],
                                          fontSize: 13,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                // Price
                                DataCell(
                                  Text(
                                    '₪${product.price.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isOutOfStock ? Colors.grey : AppColors.primary,
                                    ),
                                  ),
                                ),
                                // Cost (hidden on compact)
                                if (!isCompact)
                                  DataCell(
                                    Text(
                                      '₪${product.costPrice.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: isOutOfStock ? Colors.grey : Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                // Quantity / Stock
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isOutOfStock
                                          ? AppColors.error.withOpacity(0.1)
                                          : isLowStock
                                              ? AppColors.warning.withOpacity(0.1)
                                              : AppColors.success.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${product.quantity}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isOutOfStock
                                            ? AppColors.error
                                            : isLowStock
                                                ? AppColors.warning
                                                : AppColors.success,
                                      ),
                                    ),
                                  ),
                                ),
                                // Status (hidden on compact)
                                if (!isCompact)
                                  DataCell(_buildStatusChip(product)),
                                // Actions
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.add_box, size: isCompact ? 18 : 20),
                                        onPressed: () => _showStockDialog(product),
                                        tooltip: l10n.get('adjustStock'),
                                        color: AppColors.primary,
                                        padding: isCompact ? const EdgeInsets.all(4) : null,
                                        constraints: isCompact ? const BoxConstraints(minWidth: 32, minHeight: 32) : null,
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.edit, size: isCompact ? 18 : 20),
                                        onPressed: () => _showProductDialog(product: product),
                                        tooltip: l10n.get('edit'),
                                        color: AppColors.info,
                                        padding: isCompact ? const EdgeInsets.all(4) : null,
                                        constraints: isCompact ? const BoxConstraints(minWidth: 32, minHeight: 32) : null,
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete, size: isCompact ? 18 : 20),
                                        onPressed: () => _confirmDelete(product),
                                        tooltip: l10n.get('delete'),
                                        color: AppColors.error,
                                        padding: isCompact ? const EdgeInsets.all(4) : null,
                                        constraints: isCompact ? const BoxConstraints(minWidth: 32, minHeight: 32) : null,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Load More Button
            if (hasMore)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: isLoadingMore
                    ? const SizedBox(
                        height: 40,
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : FilledButton.icon(
                        onPressed: () => context.read<ProductBloc>().add(ProductLoadMore()),
                        icon: const Icon(Icons.expand_more),
                        label: Text(l10n.get('loadMore')),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyProductsState() {
    final l10n = LocalizationService();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[400]),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.get('noProductsFound'),
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header skeleton
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 16),
            // Row skeletons
            ...List.generate(8, (index) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  _buildSkeletonBox(width: 150, height: 20),
                  const SizedBox(width: 16),
                  _buildSkeletonBox(width: 100, height: 20),
                  const SizedBox(width: 16),
                  _buildSkeletonBox(width: 80, height: 20),
                  const SizedBox(width: 16),
                  _buildSkeletonBox(width: 60, height: 20),
                  const SizedBox(width: 16),
                  _buildSkeletonBox(width: 60, height: 20),
                  const Spacer(),
                  _buildSkeletonBox(width: 100, height: 30),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonBox({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildStatusChip(Product product) {
    if (product.isOutOfStock) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Out',
          style: TextStyle(
            color: AppColors.error,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    } else if (product.isLowStock) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.warning.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Low',
          style: TextStyle(
            color: AppColors.warning,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'OK',
        style: TextStyle(
          color: AppColors.success,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
