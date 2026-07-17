import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/localization_service.dart';
import '../../../../core/services/smart_search_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/domain/repositories/product_repository.dart';
import '../../../sales/domain/entities/cart_item.dart';
import '../../../sales/domain/repositories/sales_repository.dart';
import '../../domain/entities/customer.dart';

/// Inline sales panel for recording goods directly on a customer account statement.
/// Uses the same smart search and barcode flow as the sales page.
class CustomerLedgerSalesPanel extends StatefulWidget {
  final Customer customer;
  final VoidCallback onSaved;

  const CustomerLedgerSalesPanel({
    super.key,
    required this.customer,
    required this.onSaved,
  });

  @override
  State<CustomerLedgerSalesPanel> createState() => _CustomerLedgerSalesPanelState();
}

class _CustomerLedgerSalesPanelState extends State<CustomerLedgerSalesPanel> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _discountController = TextEditingController(text: '0');
  final _dateFormat = DateFormat('dd-MM-yyyy');
  final _smartSearch = SmartSearchService();
  final _productRepo = di.sl<ProductRepository>();
  final _salesRepo = di.sl<SalesRepository>();

  Timer? _debounceTimer;
  List<Product> _products = [];
  final List<CartItem> _cart = [];
  bool _isLoadingProducts = true;
  bool _isSaving = false;
  int _quantityToAdd = 1;
  DateTime _saleDate = DateTime.now();
  int _customProductIdCounter = -1;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      final products = await _productRepo.getProductsPaginated(limit: 50, offset: 0);
      if (mounted) {
        setState(() {
          _products = products;
          _isLoadingProducts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    if (value.isEmpty) {
      _loadProducts();
      setState(() {});
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _searchProducts(value);
    });
    setState(() {});
  }

  Future<void> _searchProducts(String query) async {
    try {
      final smartResults = await _smartSearch.smartSearchProducts(query);
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
      if (mounted) setState(() => _products = products);
    } catch (_) {
      try {
        final products = await _productRepo.searchProductsPaginated(query, limit: 50, offset: 0);
        if (mounted) setState(() => _products = products);
      } catch (_) {}
    }
  }

  Future<void> _handleBarcodeInput(String barcode) async {
    _debounceTimer?.cancel();
    final product = await _productRepo.getProductByBarcode(barcode.trim());
    if (!mounted) return;
    final l10n = LocalizationService();
    if (product != null && product.quantity > 0) {
      _addToCart(product);
    } else if (product != null) {
      _showSnack('${l10n.get('productOutOfStock')}\n${product.name}', AppColors.warning);
      _searchController.clear();
      _searchFocusNode.requestFocus();
      setState(() {});
    } else {
      _showSnack('${l10n.get('productNotFound')}\n$barcode', AppColors.error);
      _searchController.clear();
      _searchFocusNode.requestFocus();
      setState(() {});
    }
  }

  void _addToCart(Product product) {
    if (product.quantity <= 0) return;
    setState(() {
      final index = _cart.indexWhere((item) => item.product.id == product.id);
      if (index >= 0) {
        final existing = _cart[index];
        final newQty = existing.quantity + _quantityToAdd;
        if (newQty <= product.quantity) {
          _cart[index] = existing.copyWith(quantity: newQty);
        }
      } else if (_quantityToAdd <= product.quantity) {
        _cart.add(CartItem(product: product, quantity: _quantityToAdd));
      }
      _quantityToAdd = 1;
      _searchController.clear();
    });
    _searchFocusNode.requestFocus();
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  double get _subtotal => _cart.fold(0.0, (sum, item) => sum + item.totalPrice);
  double get _discount => double.tryParse(_discountController.text) ?? 0;
  double get _grandTotal => _subtotal - _discount;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _saleDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _saleDate = picked);
  }

  Future<void> _save() async {
    final l10n = LocalizationService();
    if (_cart.isEmpty) {
      _showSnack(l10n.get('noItemsInInvoice'), AppColors.error);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _salesRepo.addToCustomerAccount(
        items: List<CartItem>.from(_cart),
        customerId: widget.customer.id!,
        customerName: widget.customer.name,
        discountAmount: _discount,
        saleDate: _saleDate,
      );
      if (!mounted) return;
      setState(() {
        _cart.clear();
        _discountController.text = '0';
        _saleDate = DateTime.now();
        _isSaving = false;
      });
      _showSnack(l10n.get('postedToAccountLedger'), AppColors.success);
      widget.onSaved();
      _loadProducts();
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showSnack('${l10n.get('error')}: $e', AppColors.error);
      }
    }
  }

  void _showAddCustomProductDialog() {
    final l10n = LocalizationService();
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final quantityController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.get('addCustomProduct')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: l10n.get('productName')),
            ),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.get('price')),
            ),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.get('quantity')),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.get('cancel'))),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final price = double.tryParse(priceController.text) ?? 0;
              final qty = int.tryParse(quantityController.text) ?? 1;
              if (name.isEmpty || price <= 0 || qty <= 0) return;
              setState(() {
                _cart.add(CartItem(
                  product: Product(
                    id: _customProductIdCounter--,
                    name: name,
                    quantity: 999999,
                    price: price,
                    costPrice: 0,
                    note: 'custom',
                  ),
                  quantity: qty,
                  customPrice: price,
                ));
              });
              Navigator.pop(ctx);
            },
            child: Text(l10n.get('addToCart')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = LocalizationService();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              children: [
                _buildSearchHeader(l10n),
                Expanded(
                  child: _isLoadingProducts
                      ? const Center(child: CircularProgressIndicator())
                      : _products.isEmpty
                          ? Center(child: Text(l10n.get('searchProductsOrScan')))
                          : _buildProductsTable(l10n),
                ),
              ],
            ),
          ),
          Container(width: 1, color: Colors.grey.shade300),
          SizedBox(
            width: 280,
            child: _buildCartSection(l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader(LocalizationService l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.point_of_sale, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.get('registerCustomerGoods'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              _buildQuickQuantitySelector(l10n),
              IconButton(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today, size: 18),
                tooltip: '${l10n.get('voucherDate')}: ${_dateFormat.format(_saleDate)}',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              IconButton(
                onPressed: _loadProducts,
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: l10n.get('refresh'),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            decoration: InputDecoration(
              hintText: l10n.get('searchProductsOrScan'),
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _debounceTimer?.cancel();
                        _searchController.clear();
                        _loadProducts();
                        setState(() {});
                      },
                    ),
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.qr_code_scanner, color: AppColors.primary, size: 20),
                  ),
                ],
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: _onSearchChanged,
            onSubmitted: _handleBarcodeInput,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickQuantitySelector(LocalizationService l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.get('qty'), style: const TextStyle(fontSize: 11)),
          IconButton(
            icon: const Icon(Icons.remove, size: 16),
            onPressed: _quantityToAdd > 1 ? () => setState(() => _quantityToAdd--) : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          Text('$_quantityToAdd', style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.add, size: 16),
            onPressed: () => setState(() => _quantityToAdd++),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsTable(LocalizationService l10n) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppColors.primary.withOpacity(0.08)),
          dataRowMinHeight: 44,
          columns: [
            DataColumn(label: Text(l10n.get('name'), style: const TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text(l10n.get('barcode'), style: const TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text(l10n.get('price'), style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
            DataColumn(label: Text(l10n.get('stock'), style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
            DataColumn(label: Text(l10n.get('actions'), style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _products.map((product) {
            final outOfStock = product.quantity <= 0;
            return DataRow(
              cells: [
                DataCell(Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis)),
                DataCell(Text(product.barcode ?? '-')),
                DataCell(Text(l10n.formatCurrency(product.price))),
                DataCell(Text('${product.quantity}')),
                DataCell(
                  outOfStock
                      ? Text(l10n.get('outOfStock'), style: const TextStyle(color: AppColors.error, fontSize: 12))
                      : FilledButton(
                          onPressed: () => _addToCart(product),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          child: Text(
                            _quantityToAdd > 1 ? '+$_quantityToAdd' : l10n.get('add'),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCartSection(LocalizationService l10n) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.shopping_cart, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${l10n.get('cart')} (${_cart.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: _showAddCustomProductDialog,
                icon: const Icon(Icons.add_circle_outline),
                tooltip: l10n.get('addCustomProduct'),
              ),
              if (_cart.isNotEmpty)
                IconButton(
                  onPressed: () => setState(() => _cart.clear()),
                  icon: const Icon(Icons.delete_sweep, color: AppColors.error),
                ),
            ],
          ),
        ),
        Expanded(
          child: _cart.isEmpty
              ? Center(child: Text(l10n.get('addProductsToLedger'), style: const TextStyle(color: AppColors.textSecondary)))
              : ListView.builder(
                  itemCount: _cart.length,
                  itemBuilder: (_, index) {
                    final item = _cart[index];
                    return ListTile(
                      dense: true,
                      title: Text(item.product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${item.quantity} x ${l10n.formatCurrency(item.unitPrice)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(l10n.formatCurrency(item.totalPrice), style: const TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() => _cart.removeAt(index)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(top: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _discountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l10n.get('discount'),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.get('grandTotal'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(
                    l10n.formatCurrency(_grandTotal),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.error),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save, size: 18),
                  label: Text(l10n.get('saveToLedger')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
