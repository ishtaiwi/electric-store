import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../../../core/constants/app_strings.dart';
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
  bool _showLowStock = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.confirmDelete),
        content: Text('${LocalizationService().get('confirmDeleteItem')} "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              this.context.read<ProductBloc>().add(ProductDelete(product.id!));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text(AppStrings.delete),
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
                    LocalizationService().get('products'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showProductDialog(),
                    icon: const Icon(Icons.add),
                    label: Text(LocalizationService().get('addProduct')),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Filters
              Row(
                children: [
                  // Search
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: LocalizationService().get('searchProducts'),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  context.read<ProductBloc>().add(ProductLoadAll());
                                },
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        if (value.isEmpty) {
                          context.read<ProductBloc>().add(ProductLoadAll());
                        } else {
                          context.read<ProductBloc>().add(ProductSearch(value));
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),

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
                  const SizedBox(width: 8),

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
                    : Column(
                        children: [
                          Expanded(
                            child: Card(
                        child: DataTable2(
                          columnSpacing: 16,
                          horizontalMargin: 16,
                          minWidth: 800,
                          headingRowColor: WidgetStateProperty.all(
                            AppColors.primary.withOpacity(0.1),
                          ),
                          columns: [
                            DataColumn2(label: Text(LocalizationService().get('name')), size: ColumnSize.L),
                            DataColumn2(label: Text(LocalizationService().get('barcode')), size: ColumnSize.M),
                            DataColumn2(label: Text(LocalizationService().get('notes')), size: ColumnSize.M),
                            DataColumn2(label: Text(LocalizationService().get('price')), numeric: true),
                            DataColumn2(label: Text(LocalizationService().get('cost')), numeric: true),
                            DataColumn2(label: Text(LocalizationService().get('quantity')), numeric: true),
                            DataColumn2(label: Text(LocalizationService().get('status')), size: ColumnSize.S),
                            DataColumn2(label: Text(LocalizationService().get('actions')), size: ColumnSize.L),
                          ],
                          rows: products.map((product) {
                            final isLowStock = product.isLowStock;
                            final isOutOfStock = product.isOutOfStock;

                            return DataRow2(
                              cells: [
                                DataCell(Text(product.name)),
                                DataCell(Text(product.barcode ?? '-')),
                                DataCell(Text(product.note ?? '-')),
                                DataCell(Text('₪${product.price.toStringAsFixed(2)}')),
                                DataCell(Text('₪${product.costPrice.toStringAsFixed(2)}')),
                                DataCell(
                                  Text(
                                    '${product.quantity}',
                                    style: TextStyle(
                                      color: isOutOfStock
                                          ? AppColors.error
                                          : isLowStock
                                              ? AppColors.warning
                                              : null,
                                      fontWeight: isLowStock || isOutOfStock
                                          ? FontWeight.bold
                                          : null,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  _buildStatusChip(product),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.add_box, size: 20),
                                        onPressed: () => _showStockDialog(product),
                                        tooltip: LocalizationService().get('adjustStock'),
                                        color: AppColors.primary,
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 20),
                                        onPressed: () => _showProductDialog(product: product),
                                        tooltip: LocalizationService().get('edit'),
                                        color: AppColors.info,
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, size: 20),
                                        onPressed: () => _confirmDelete(product),
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
                            child: Text(LocalizationService().get('noProductsFound')),
                          ),
                        ),
                            ),
                          ),
                          // Load More Button
                          if (hasMore)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: isLoadingMore
                                  ? const SizedBox(
                                      height: 40,
                                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                    )
                                  : FilledButton.icon(
                                      onPressed: () => context.read<ProductBloc>().add(ProductLoadMore()),
                                      icon: const Icon(Icons.expand_more),
                                      label: Text(LocalizationService().get('loadMore')),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      ),
                                    ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
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
