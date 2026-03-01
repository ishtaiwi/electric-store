import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../../customers/domain/repositories/customer_repository.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/domain/repositories/product_repository.dart';
import '../../domain/entities/price_list.dart';
import '../../domain/entities/price_list_item.dart';
import '../bloc/price_list_bloc.dart';

class PriceListFormDialog extends StatefulWidget {
  final PriceList? priceList;

  const PriceListFormDialog({super.key, this.priceList});

  @override
  State<PriceListFormDialog> createState() => _PriceListFormDialogState();
}

class _PriceListFormDialogState extends State<PriceListFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _productSearchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _debounceTimer;

  Customer? _selectedCustomer;
  List<Customer> _customers = [];
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  List<_EditablePriceListItem> _items = [];
  bool _isLoading = true;
  bool _isEdit = false;
  int _quantityToAdd = 1;

  @override
  void initState() {
    super.initState();
    _isEdit = widget.priceList != null;
    if (_isEdit) {
      _titleController.text = widget.priceList!.title;
      _notesController.text = widget.priceList!.notes ?? '';
    }
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final customerRepo = di.sl<CustomerRepository>();
      final productRepo = di.sl<ProductRepository>();

      final customers = await customerRepo.getAllCustomers();
      final products = await productRepo.getAllProducts();

      setState(() {
        _customers = customers;
        _products = products;
        _filteredProducts = [];
        _isLoading = false;
      });

      if (_isEdit && widget.priceList!.customerId != null) {
        final customer = _customers.where((c) => c.id == widget.priceList!.customerId).firstOrNull;
        if (customer != null) {
          setState(() => _selectedCustomer = customer);
        }
      }

      if (_isEdit) {
        _loadExistingItems();
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _loadExistingItems() {
    final bloc = context.read<PriceListBloc>();
    final state = bloc.state;
    if (state is PriceListDetailsLoaded && state.priceList.id == widget.priceList!.id) {
      _populateItems(state.items);
    } else {
      bloc.stream.listen((state) {
        if (state is PriceListDetailsLoaded && state.priceList.id == widget.priceList!.id && mounted) {
          _populateItems(state.items);
        }
      });
    }
  }

  void _populateItems(List<PriceListItem> items) {
    setState(() {
      _items = items
          .map((item) => _EditablePriceListItem(
                productId: item.productId,
                productName: item.productName,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                notes: item.notes,
              ))
          .toList();
    });
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    if (value.isEmpty) {
      setState(() => _filteredProducts = []);
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        final q = value.toLowerCase();
        setState(() {
          _filteredProducts = _products.where((p) {
            return p.name.toLowerCase().contains(q) ||
                (p.barcode?.toLowerCase().contains(q) ?? false);
          }).toList();
        });
      }
    });
  }

  void _onSearchSubmitted(String value) {
    // Barcode exact match – instant add
    if (value.isNotEmpty) {
      final match = _products.where((p) => p.barcode == value).firstOrNull;
      if (match != null) {
        _addProductItem(match);
        return;
      }
    }
    // Otherwise add the first filtered result
    if (_filteredProducts.isNotEmpty) {
      _addProductItem(_filteredProducts.first);
    }
  }

  void _addProductItem(Product product) {
    // Check if already added – increment quantity instead
    final existing = _items.indexWhere((i) => i.productId == product.id);
    if (existing >= 0) {
      setState(() {
        _items[existing] = _items[existing].copyWith(
          quantity: _items[existing].quantity + _quantityToAdd,
        );
      });
    } else {
      setState(() {
        _items.add(_EditablePriceListItem(
          productId: product.id,
          productName: product.name,
          quantity: _quantityToAdd,
          unitPrice: product.price,
        ));
      });
    }
    _productSearchController.clear();
    _quantityToAdd = 1;
    setState(() => _filteredProducts = []);
    _searchFocusNode.requestFocus();
  }

  void _addCustomItem() {
    showDialog(
      context: context,
      builder: (ctx) => _CustomItemDialog(
        onAdd: (name, quantity, price) {
          setState(() {
            _items.add(_EditablePriceListItem(
              productName: name,
              quantity: quantity,
              unitPrice: price,
            ));
          });
        },
      ),
    );
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  double get _totalAmount {
    return _items.fold(0.0, (sum, item) => sum + (item.quantity * item.unitPrice));
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocalizationService().get('pleaseAddItems')),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final priceList = PriceList(
      id: widget.priceList?.id,
      title: _titleController.text.trim(),
      customerId: _selectedCustomer?.id,
      customerName: _selectedCustomer?.name,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    final items = _items
        .map((item) => PriceListItem(
              productId: item.productId,
              productName: item.productName,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
              totalPrice: item.quantity * item.unitPrice,
              notes: item.notes,
            ))
        .toList();

    if (_isEdit) {
      context.read<PriceListBloc>().add(PriceListUpdate(priceList: priceList, items: items));
    } else {
      context.read<PriceListBloc>().add(PriceListCreate(priceList: priceList, items: items));
    }

    Navigator.pop(context);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _titleController.dispose();
    _notesController.dispose();
    _productSearchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = LocalizationService();

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 950,
        height: MediaQuery.of(context).size.height * 0.9,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: Column(
                  children: [
                    // ── Header ──
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 18, 16, 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.primary.withOpacity(0.85)],
                        ),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _isEdit ? Icons.edit_note : Icons.playlist_add,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isEdit ? l10n.get('editPriceList') : l10n.get('createPriceList'),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  l10n.get('noInventoryImpact'),
                                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
                                ),
                              ],
                            ),
                          ),
                          Material(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => Navigator.pop(context),
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(Icons.close, color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Body ──
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left: Form fields + Product search
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Title & Customer
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: TextFormField(
                                          controller: _titleController,
                                          decoration: InputDecoration(
                                            labelText: '${l10n.get('title')} *',
                                            prefixIcon: const Icon(Icons.title, size: 20),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                            isDense: true,
                                          ),
                                          validator: (v) => v == null || v.trim().isEmpty ? l10n.get('titleRequired') : null,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 2,
                                        child: DropdownButtonFormField<Customer?>(
                                          value: _selectedCustomer,
                                          decoration: InputDecoration(
                                            labelText: l10n.get('customerOptional'),
                                            prefixIcon: const Icon(Icons.person_outline, size: 20),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                            isDense: true,
                                          ),
                                          items: [
                                            DropdownMenuItem<Customer?>(value: null, child: Text(l10n.get('noCustomer'))),
                                            ..._customers.map((c) => DropdownMenuItem(value: c, child: Text(c.name))),
                                          ],
                                          onChanged: (v) => setState(() => _selectedCustomer = v),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Notes
                                  TextFormField(
                                    controller: _notesController,
                                    decoration: InputDecoration(
                                      labelText: l10n.get('notes'),
                                      prefixIcon: const Icon(Icons.notes, size: 20),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      isDense: true,
                                    ),
                                    maxLines: 2,
                                  ),
                                  const SizedBox(height: 18),

                                  // ── Product search section ──
                                  Row(
                                    children: [
                                      Text(
                                        l10n.get('addProducts'),
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      const Spacer(),
                                      // Quick qty selector
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: Colors.grey.shade300),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _QtyButton(
                                              icon: Icons.remove,
                                              onPressed: _quantityToAdd > 1 ? () => setState(() => _quantityToAdd--) : null,
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 10),
                                              child: Text(
                                                '$_quantityToAdd',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                              ),
                                            ),
                                            _QtyButton(
                                              icon: Icons.add,
                                              onPressed: () => setState(() => _quantityToAdd++),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      OutlinedButton.icon(
                                        onPressed: _addCustomItem,
                                        icon: const Icon(Icons.add_circle_outline, size: 18),
                                        label: Text(l10n.get('addCustomProduct')),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Search field
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: TextField(
                                      controller: _productSearchController,
                                      focusNode: _searchFocusNode,
                                      decoration: InputDecoration(
                                        hintText: l10n.get('searchProductsOrScan'),
                                        hintStyle: TextStyle(color: Colors.grey.shade500),
                                        prefixIcon: const Icon(Icons.search, size: 22),
                                        suffixIcon: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (_productSearchController.text.isNotEmpty)
                                              IconButton(
                                                icon: const Icon(Icons.clear, size: 18),
                                                onPressed: () {
                                                  _debounceTimer?.cancel();
                                                  _productSearchController.clear();
                                                  setState(() => _filteredProducts = []);
                                                },
                                              ),
                                            Container(
                                              padding: const EdgeInsets.all(7),
                                              margin: const EdgeInsets.only(right: 8),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Icon(Icons.qr_code_scanner, color: AppColors.primary, size: 18),
                                            ),
                                          ],
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      ),
                                      style: const TextStyle(fontSize: 15),
                                      onChanged: _onSearchChanged,
                                      onSubmitted: _onSearchSubmitted,
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Search results
                                  if (_filteredProducts.isNotEmpty)
                                    Container(
                                      constraints: const BoxConstraints(maxHeight: 180),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey.shade200),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.06),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: ListView.separated(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        shrinkWrap: true,
                                        itemCount: _filteredProducts.length,
                                        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
                                        itemBuilder: (ctx, index) {
                                          final product = _filteredProducts[index];
                                          return InkWell(
                                            onTap: () => _addProductItem(product),
                                            borderRadius: BorderRadius.circular(8),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 36,
                                                    height: 36,
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primary.withOpacity(0.08),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: const Icon(Icons.inventory_2, size: 18, color: AppColors.primary),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                                        const SizedBox(height: 2),
                                                        Row(
                                                          children: [
                                                            if (product.barcode != null && product.barcode!.isNotEmpty) ...[
                                                              Icon(Icons.qr_code, size: 12, color: Colors.grey.shade500),
                                                              const SizedBox(width: 3),
                                                              Text(
                                                                product.barcode!,
                                                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                                              ),
                                                              const SizedBox(width: 10),
                                                            ],
                                                            Icon(Icons.inventory, size: 12, color: product.quantity > 0 ? AppColors.success : AppColors.error),
                                                            const SizedBox(width: 3),
                                                            Text(
                                                              '${product.quantity} ${l10n.get('inStock')}',
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                color: product.quantity > 0 ? AppColors.success : AppColors.error,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.success.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      '${LocalizationService.currencySymbol}${product.price.toStringAsFixed(2)}',
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                                                        color: AppColors.success,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primary.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: const Padding(
                                                      padding: EdgeInsets.all(6),
                                                      child: Icon(Icons.add, size: 18, color: AppColors.primary),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),

                            // Right: Items list
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '${l10n.get('items')} (${_items.length})',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      const Spacer(),
                                      if (_items.isNotEmpty)
                                        TextButton.icon(
                                          onPressed: () => setState(() => _items.clear()),
                                          icon: const Icon(Icons.delete_sweep, size: 18, color: AppColors.error),
                                          label: Text(l10n.get('clear'), style: const TextStyle(color: AppColors.error)),
                                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10)),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: _items.isEmpty
                                        ? Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.shopping_basket_outlined, size: 48, color: Colors.grey.shade300),
                                                const SizedBox(height: 12),
                                                Text(
                                                  l10n.get('pleaseAddItems'),
                                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                                                ),
                                              ],
                                            ),
                                          )
                                        : ListView.builder(
                                            itemCount: _items.length,
                                            itemBuilder: (ctx, index) {
                                              final item = _items[index];
                                              return Container(
                                                margin: const EdgeInsets.only(bottom: 6),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(color: Colors.grey.shade200),
                                                ),
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                  child: Row(
                                                    children: [
                                                      // Index badge
                                                      Container(
                                                        width: 26,
                                                        height: 26,
                                                        alignment: Alignment.center,
                                                        decoration: BoxDecoration(
                                                          color: AppColors.primary.withOpacity(0.1),
                                                          borderRadius: BorderRadius.circular(13),
                                                        ),
                                                        child: Text(
                                                          '${index + 1}',
                                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      // Product info
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                                                            if (item.productId == null)
                                                              Text(
                                                                l10n.get('customProduct'),
                                                                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                      // Quantity
                                                      SizedBox(
                                                        width: 60,
                                                        child: TextFormField(
                                                          initialValue: '${item.quantity}',
                                                          decoration: InputDecoration(
                                                            labelText: l10n.get('qty'),
                                                            isDense: true,
                                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                          ),
                                                          keyboardType: TextInputType.number,
                                                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                                          onChanged: (v) {
                                                            final qty = int.tryParse(v) ?? 1;
                                                            setState(() => _items[index] = item.copyWith(quantity: qty));
                                                          },
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      // Price
                                                      SizedBox(
                                                        width: 85,
                                                        child: TextFormField(
                                                          initialValue: item.unitPrice.toStringAsFixed(2),
                                                          decoration: InputDecoration(
                                                            labelText: l10n.get('price'),
                                                            isDense: true,
                                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                          ),
                                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                          onChanged: (v) {
                                                            final price = double.tryParse(v) ?? 0;
                                                            setState(() => _items[index] = item.copyWith(unitPrice: price));
                                                          },
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      // Line total
                                                      SizedBox(
                                                        width: 75,
                                                        child: Text(
                                                          '${LocalizationService.currencySymbol}${(item.quantity * item.unitPrice).toStringAsFixed(2)}',
                                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                                                          textAlign: TextAlign.end,
                                                        ),
                                                      ),
                                                      // Delete
                                                      IconButton(
                                                        icon: const Icon(Icons.close, color: AppColors.error, size: 18),
                                                        visualDensity: VisualDensity.compact,
                                                        onPressed: () => _removeItem(index),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Footer ──
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                        border: Border(top: BorderSide(color: Colors.grey.shade200)),
                      ),
                      child: Row(
                        children: [
                          // Total
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppColors.success, AppColors.success.withOpacity(0.85)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.receipt_long, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  '${l10n.get('total')}: ${LocalizationService.currencySymbol}${_totalAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            child: Text(l10n.get('cancel')),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _save,
                            icon: const Icon(Icons.save, size: 20),
                            label: Text(_isEdit ? l10n.get('update') : l10n.get('save')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ==================== Qty Button ====================

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _QtyButton({required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 18, color: onPressed != null ? AppColors.primary : Colors.grey),
      ),
    );
  }
}

// ==================== Editable Item Model ====================

class _EditablePriceListItem {
  final int? productId;
  final String productName;
  int quantity;
  double unitPrice;
  final String? notes;

  _EditablePriceListItem({
    this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.notes,
  });

  _EditablePriceListItem copyWith({
    int? productId,
    String? productName,
    int? quantity,
    double? unitPrice,
    String? notes,
  }) {
    return _EditablePriceListItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      notes: notes ?? this.notes,
    );
  }
}

// ==================== Custom Item Dialog ====================

class _CustomItemDialog extends StatefulWidget {
  final Function(String name, int quantity, double price) onAdd;

  const _CustomItemDialog({required this.onAdd});

  @override
  State<_CustomItemDialog> createState() => _CustomItemDialogState();
}

class _CustomItemDialogState extends State<_CustomItemDialog> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = LocalizationService();
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add_box, color: AppColors.secondary),
          ),
          const SizedBox(width: 12),
          Text(l10n.get('addCustomProduct')),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.get('productName'),
                prefixIcon: const Icon(Icons.label_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? l10n.get('validNameRequired') : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantityController,
                    decoration: InputDecoration(
                      labelText: l10n.get('quantity'),
                      prefixIcon: const Icon(Icons.numbers),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      if (v == null || v.isEmpty) return l10n.get('quantityRequired');
                      if (int.tryParse(v) == null || int.parse(v) < 1) return l10n.get('validQuantityRequired');
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    decoration: InputDecoration(
                      labelText: l10n.get('price'),
                      prefixIcon: const Icon(Icons.attach_money),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.isEmpty) return l10n.get('priceRequired');
                      if (double.tryParse(v) == null || double.parse(v) <= 0) return l10n.get('validPriceRequired');
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.get('cancel')),
        ),
        ElevatedButton.icon(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onAdd(
                _nameController.text.trim(),
                int.parse(_quantityController.text),
                double.parse(_priceController.text),
              );
              Navigator.pop(context);
            }
          },
          icon: const Icon(Icons.add),
          label: Text(l10n.get('add')),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }
}
