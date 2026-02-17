import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../../customers/domain/repositories/customer_repository.dart';
import '../../../invoices/presentation/bloc/invoice_bloc.dart';
import '../../../invoices/domain/repositories/invoice_repository.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/presentation/bloc/product_bloc.dart';
import '../../domain/entities/cart_item.dart';
import '../bloc/sales_bloc.dart';
import '../widgets/checkout_dialog.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  List<Customer> _customers = [];
  int _quantityToAdd = 1;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    // Auto-focus search field for barcode scanning
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  Future<void> _loadCustomers() async {
    final customerRepo = di.sl<CustomerRepository>();
    _customers = await customerRepo.getAllCustomers();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _addToCart(Product product) {
    if (product.quantity <= 0) return;
    context.read<SalesBloc>().add(SalesAddToCart(product: product, quantity: _quantityToAdd));
    _quantityToAdd = 1;
    _searchController.clear();
    _searchFocusNode.requestFocus();
    setState(() {});
  }

  void _showCheckoutDialog() {
    final state = context.read<SalesBloc>().state;
    if (state is SalesReady && state.cart.isNotEmpty) {
      showDialog(
        context: context,
        builder: (dialogContext) => BlocProvider.value(
          value: context.read<SalesBloc>(),
          child: CheckoutDialog(
            customers: _customers,
            onCheckout: _checkout,
          ),
        ),
      );
    }
  }

  void _checkout(int? customerId, String paymentMethod, double discount, double? paidAmount) {
    final authState = context.read<AuthBloc>().state;
    final userId = authState is AuthAuthenticated ? authState.user.id : null;

    // Pass all checkout parameters directly to SalesCheckout event
    // This ensures the discount is correctly saved with the invoice
    context.read<SalesBloc>().add(SalesCheckout(
      userId: userId,
      paidAmount: paidAmount,
      discount: discount,
      customerId: customerId,
      paymentMethod: paymentMethod,
    ));
  }

  void _showEditPriceDialog(CartItem item) {
    final priceController = TextEditingController(
      text: item.unitPrice.toStringAsFixed(2),
    );
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(LocalizationService().get('editPrice'), style: const TextStyle(fontSize: 18)),
                  Text(item.product.name, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.normal)),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(LocalizationService().get('originalPrice'), style: const TextStyle(color: AppColors.textSecondary)),
                  Text('₪${item.product.price.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: LocalizationService().get('newPrice'),
                prefixText: '₪ ',
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              autofocus: true,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          if (item.customPrice != null)
            OutlinedButton.icon(
              onPressed: () {
                context.read<SalesBloc>().add(
                  SalesUpdateCartPrice(productId: item.product.id!, price: item.product.price),
                );
                Navigator.pop(dialogContext);
              },
              icon: const Icon(Icons.refresh),
              label: Text(LocalizationService().get('reset')),
            ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(LocalizationService().get('cancel')),
          ),
          FilledButton.icon(
            onPressed: () {
              final newPrice = double.tryParse(priceController.text);
              if (newPrice != null && newPrice > 0) {
                context.read<SalesBloc>().add(
                  SalesUpdateCartPrice(productId: item.product.id!, price: newPrice),
                );
              }
              Navigator.pop(dialogContext);
            },
            icon: const Icon(Icons.check),
            label: Text(LocalizationService().get('update')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = LocalizationService();
    
    return BlocConsumer<SalesBloc, SalesState>(
      listener: (context, state) async {
        if (state is SalesCheckoutSuccess) {
          // Instantly update Invoice list without DB reload
          di.sl<InvoiceBloc>().add(InvoiceAdded(state.invoice));
          
          // Instantly update Product quantities without DB reload
          if (state.invoice.id != null) {
            final invoiceRepo = di.sl<InvoiceRepository>();
            final items = await invoiceRepo.getInvoiceItems(state.invoice.id!);
            final productQuantities = <int, int>{};
            for (final item in items) {
              if (item.productId != null) {
                productQuantities[item.productId!] = 
                    (productQuantities[item.productId!] ?? 0) + item.quantity;
              }
            }
            di.sl<ProductBloc>().add(ProductQuantitiesSold(productQuantities));
          }
          
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Text('${l10n.get('saleCompletedInvoice')} ${state.invoice.invoiceNumber}'),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        } else if (state is SalesError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(state.message),
                ],
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, state) {
        List<Product> products = [];
        List<CartItem> cart = [];
        double subtotal = 0;
        double discount = 0;
        double total = 0;
        bool hasMore = false;
        bool isLoadingMore = false;

        if (state is SalesReady) {
          products = state.products;
          cart = state.cart;
          subtotal = state.subtotal;
          discount = state.discount;
          total = state.total;
          hasMore = state.hasMore;
          isLoadingMore = state.isLoadingMore;
        }

        return Row(
          children: [
            // Left: Products Section
            Expanded(
              flex: 3,
              child: Container(
                color: Colors.grey[50],
                child: Column(
                  children: [
                    // Search Bar Section
                    Container(
                      padding: const EdgeInsets.all(20),
                      color: Colors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Row
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.point_of_sale, color: Colors.white, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                l10n.get('newSale'),
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              // Quick quantity selector
                              _buildQuickQuantitySelector(),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Search Field
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              decoration: InputDecoration(
                                hintText: l10n.get('searchProductsOrScan'),
                                hintStyle: TextStyle(color: Colors.grey[500]),
                                prefixIcon: const Icon(Icons.search, size: 24),
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_searchController.text.isNotEmpty)
                                      IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _searchController.clear();
                                          context.read<SalesBloc>().add(SalesSearchProducts(''));
                                          setState(() {});
                                        },
                                      ),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.1),
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
                              onChanged: (value) {
                                context.read<SalesBloc>().add(SalesSearchProducts(value));
                                setState(() {});
                              },
                              onSubmitted: (value) {
                                final product = products.firstWhere(
                                  (p) => p.barcode == value,
                                  orElse: () => products.isNotEmpty ? products.first : const Product(name: '', quantity: 0, price: 0, costPrice: 0),
                                );
                                if (product.id != null && product.quantity > 0) {
                                  _addToCart(product);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Products Table
                    Expanded(
                      child: state is SalesLoading
                          ? _buildLoadingSkeleton()
                          : products.isEmpty
                              ? _buildEmptyProductsState(l10n)
                              : _buildProductsTable(products, l10n, hasMore, isLoadingMore),
                    ),
                  ],
                ),
              ),
            ),

            // Right: Cart Section
            Container(
              width: 380,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(-5, 0),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Cart Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.shopping_cart, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.get('cart'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            Text(
                              '${cart.length} ${l10n.get('items')}',
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (cart.isNotEmpty)
                          IconButton(
                            onPressed: () => context.read<SalesBloc>().add(SalesClearCart()),
                            icon: const Icon(Icons.delete_sweep),
                            color: AppColors.error,
                            tooltip: l10n.get('clear'),
                          ),
                      ],
                    ),
                  ),

                  // Cart Items
                  Expanded(
                    child: cart.isEmpty
                        ? _buildEmptyCartState(l10n)
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: cart.length,
                            itemBuilder: (context, index) => _buildCartItem(cart[index], l10n),
                          ),
                  ),

                  // Checkout Section
                  if (cart.isNotEmpty) _buildCheckoutSection(subtotal, discount, total, l10n),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickQuantitySelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            LocalizationService().get('qty'),
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _quantityToAdd > 1 ? () => setState(() => _quantityToAdd--) : null,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _quantityToAdd > 1 ? AppColors.primary : Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.remove, color: Colors.white, size: 18),
            ),
          ),
          Container(
            width: 50,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              '$_quantityToAdd',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          InkWell(
            onTap: () => setState(() => _quantityToAdd++),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsTable(List<Product> products, LocalizationService l10n, bool hasMore, bool isLoadingMore) {
    return Column(
      children: [
        Expanded(
          child: Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppColors.primary.withValues(alpha: 0.1)),
            dataRowMinHeight: 48,
            dataRowMaxHeight: 60,
            columnSpacing: 24,
            horizontalMargin: 16,
            columns: [
              DataColumn(label: Text(l10n.get('name'), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(l10n.get('barcode'), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(l10n.get('price'), style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text(l10n.get('stock'), style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text(l10n.get('notes'), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(l10n.get('actions'), style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: products.map((product) {
              final isOutOfStock = product.quantity <= 0;
              final isLowStock = product.isLowStock && !isOutOfStock;
              
              return DataRow(
                color: WidgetStateProperty.resolveWith((states) {
                  if (isOutOfStock) return Colors.grey[100];
                  if (states.contains(WidgetState.hovered)) {
                    return AppColors.primary.withValues(alpha: 0.05);
                  }
                  return null;
                }),
                cells: [
                  // Name
                  DataCell(
                    SizedBox(
                      width: 150,
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
                  // Stock
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isOutOfStock 
                          ? AppColors.error.withValues(alpha: 0.1)
                          : isLowStock 
                            ? AppColors.warning.withValues(alpha: 0.1)
                            : AppColors.success.withValues(alpha: 0.1),
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
                  // Note
                  DataCell(
                    SizedBox(
                      width: 100,
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
                  // Action
                  DataCell(
                    isOutOfStock
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            l10n.get('outOfStock'),
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      : FilledButton.icon(
                          onPressed: () => _addToCart(product),
                          icon: const Icon(Icons.add_shopping_cart, size: 18),
                          label: Text(_quantityToAdd > 1 ? '+$_quantityToAdd' : l10n.get('add')),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
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
                    onPressed: () => context.read<SalesBloc>().add(SalesLoadMoreProducts()),
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
  }

  Widget _buildCartItem(CartItem item, LocalizationService l10n) {
    final hasCustomPrice = item.customPrice != null;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: hasCustomPrice ? Border.all(color: AppColors.success.withValues(alpha: 0.5)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (hasCustomPrice) ...[
                          Text(
                            '₪${item.product.price.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward, size: 12, color: AppColors.success),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          '₪${item.unitPrice.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: hasCustomPrice ? AppColors.success : Colors.grey[600],
                            fontWeight: hasCustomPrice ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => _showEditPriceDialog(item),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              Icons.edit_outlined,
                              size: 14,
                              color: AppColors.primary.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Delete Button
              IconButton(
                onPressed: () => context.read<SalesBloc>().add(SalesRemoveFromCart(item.product.id!)),
                icon: const Icon(Icons.close, size: 18),
                color: Colors.grey[400],
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Quantity Controls and Total
          Row(
            children: [
              // Quantity Controls
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () {
                        context.read<SalesBloc>().add(
                          SalesUpdateCartQuantity(productId: item.product.id!, quantity: item.quantity - 1),
                        );
                      },
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: const Icon(Icons.remove, size: 18, color: AppColors.primary),
                      ),
                    ),
                    Container(
                      width: 40,
                      alignment: Alignment.center,
                      child: Text(
                        '${item.quantity}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                    InkWell(
                      onTap: item.quantity < item.product.quantity
                          ? () {
                              context.read<SalesBloc>().add(
                                SalesUpdateCartQuantity(productId: item.product.id!, quantity: item.quantity + 1),
                              );
                            }
                          : null,
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Icon(
                          Icons.add,
                          size: 18,
                          color: item.quantity < item.product.quantity ? AppColors.primary : Colors.grey[300],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Item Total
              Text(
                '₪${item.totalPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutSection(double subtotal, double discount, double total, LocalizationService l10n) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Subtotal
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.get('subtotal'), style: TextStyle(color: Colors.grey[600])),
              Text('₪${subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
          // Discount
          if (discount > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.get('discount'), style: const TextStyle(color: AppColors.success)),
                Text('-₪${discount.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
          const SizedBox(height: 12),
          // Total
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.get('total'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  '₪${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Checkout Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _showCheckoutDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.payment, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    l10n.get('checkout'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCartState(LocalizationService l10n) {
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
            child: Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey[400]),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.get('cartEmpty'),
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.get('searchProductsOrScan'),
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
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
          Expanded(
            child: ListView.builder(
              itemCount: 6,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    _buildSkeletonBox(width: 120, height: 20),
                    const SizedBox(width: 16),
                    _buildSkeletonBox(width: 80, height: 20),
                    const SizedBox(width: 16),
                    _buildSkeletonBox(width: 60, height: 20),
                    const SizedBox(width: 16),
                    _buildSkeletonBox(width: 50, height: 20),
                    const Spacer(),
                    _buildSkeletonBox(width: 80, height: 30),
                  ],
                ),
              ),
            ),
          ),
        ],
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

  Widget _buildEmptyProductsState(LocalizationService l10n) {
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
}
