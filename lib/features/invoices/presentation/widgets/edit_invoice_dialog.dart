import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../customers/presentation/bloc/customer_bloc.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/domain/repositories/product_repository.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../../customers/domain/repositories/customer_repository.dart';
import '../../../products/presentation/bloc/product_bloc.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/sale_item.dart';
import '../bloc/invoice_bloc.dart';

class EditInvoiceDialog extends StatefulWidget {
  final Invoice invoice;
  final List<SaleItem> items;

  const EditInvoiceDialog({
    super.key,
    required this.invoice,
    required this.items,
  });

  @override
  State<EditInvoiceDialog> createState() => _EditInvoiceDialogState();
}

class _EditInvoiceDialogState extends State<EditInvoiceDialog> {
  late List<_EditableItem> _editableItems;
  late TextEditingController _discountController;
  late TextEditingController _searchController;
  late String _paymentMethod;
  int? _selectedCustomerId;
  String? _selectedCustomerName;
  List<Product> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _editableItems = widget.items
        .map((item) => _EditableItem.fromSaleItem(item))
        .toList();
    _discountController = TextEditingController(
      text: widget.invoice.discountAmount > 0
          ? widget.invoice.discountAmount.toString()
          : '',
    );
    _searchController = TextEditingController();
    _selectedCustomerId = widget.invoice.customerId;
    _selectedCustomerName = widget.invoice.customerName;
    _paymentMethod = widget.invoice.paymentMethod;
  }

  @override
  void dispose() {
    _discountController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  double get _totalAmount =>
      _editableItems.fold(0.0, (sum, item) => sum + item.totalAmount);

  double get _discount =>
      double.tryParse(_discountController.text) ?? 0;

  double get _finalAmount => _totalAmount - _discount;

  Future<void> _searchProducts(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      final repo = di.sl<ProductRepository>();
      final results = await repo.searchProducts(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _addProduct(Product product) {
    // Check if product is already in the list
    final existingIndex = _editableItems.indexWhere(
      (item) => item.productId == product.id,
    );

    setState(() {
      if (existingIndex != -1) {
        _editableItems[existingIndex].quantity++;
      } else {
        _editableItems.add(_EditableItem(
          productId: product.id,
          barcode: product.barcode,
          productName: product.name,
          quantity: 1,
          costPrice: product.costPrice,
          salePrice: product.price,
        ));
      }
      _searchController.clear();
      _searchResults = [];
    });
  }

  void _removeItem(int index) {
    setState(() => _editableItems.removeAt(index));
  }

  void _updateQuantity(int index, int newQty) {
    if (newQty > 0) {
      setState(() => _editableItems[index].quantity = newQty);
    }
  }

  void _updatePrice(int index, double newPrice) {
    if (newPrice >= 0) {
      setState(() => _editableItems[index].salePrice = newPrice);
    }
  }

  void _showAddCustomProductDialog() {
    final l10n = LocalizationService();
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add_box_outlined, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.get('addCustomProduct'),
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                TextFormField(
                  controller: nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l10n.get('productName'),
                    hintText: l10n.get('enterProductName'),
                    prefixIcon: const Icon(Icons.inventory_2_outlined),
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.get('validNameRequired');
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: l10n.get('price'),
                    hintText: l10n.get('enterPrice'),
                    prefixText: '₪ ',
                    prefixIcon: const Icon(Icons.attach_money),
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.get('validPriceRequired');
                    }
                    final price = double.tryParse(value);
                    if (price == null || price <= 0) {
                      return l10n.get('validPriceRequired');
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.get('quantity'),
                    hintText: l10n.get('enterQuantity'),
                    prefixIcon: const Icon(Icons.numbers),
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.get('validQuantityRequired');
                    }
                    final qty = int.tryParse(value);
                    if (qty == null || qty <= 0) {
                      return l10n.get('validQuantityRequired');
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: noteController,
                  decoration: InputDecoration(
                    labelText: '${l10n.get('notes')} (${l10n.get('optional')})',
                    hintText: l10n.get('enterNotes'),
                    prefixIcon: const Icon(Icons.note_outlined),
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  maxLines: 2,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) {
                    if (formKey.currentState!.validate()) {
                      _addCustomProduct(nameController, priceController, quantityController, noteController);
                      Navigator.pop(dialogContext);
                    }
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.get('cancel')),
          ),
          FilledButton.icon(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                _addCustomProduct(nameController, priceController, quantityController, noteController);
                Navigator.pop(dialogContext);
              }
            },
            icon: const Icon(Icons.add_shopping_cart),
            label: Text(l10n.get('addItem')),
          ),
        ],
      ),
    );
  }

  Future<void> _openCustomerPicker() async {
    final repo = di.sl<CustomerRepository>();
    String query = '';

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            Future<List<Customer>> _load() {
              if (query.trim().isEmpty) return repo.getAllCustomers();
              return repo.searchCustomers(query.trim());
            }

            return Dialog(
              child: SizedBox(
                width: 520,
                height: 520,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: TextField(
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: LocalizationService().get('searchCustomers'),
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (v) => setState(() => query = v),
                      ),
                    ),
                    Expanded(
                      child: FutureBuilder<List<Customer>>(
                        future: _load(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final items = snapshot.data ?? [];
                          if (items.isEmpty) {
                            return Center(child: Text(LocalizationService().get('noCustomers')));
                          }
                          return ListView.builder(
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final c = items[index];
                              return ListTile(
                                title: Text(c.name),
                                subtitle: c.phone != null ? Text(c.phone!) : null,
                                onTap: () {
                                  setState(() {
                                    _selectedCustomerId = c.id;
                                    _selectedCustomerName = c.name;
                                  });
                                  Navigator.pop(dialogContext);
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          const Spacer(),
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: Text(LocalizationService().get('close')),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _addCustomProduct(
    TextEditingController nameCtrl,
    TextEditingController priceCtrl,
    TextEditingController qtyCtrl,
    TextEditingController noteCtrl,
  ) {
    final name = nameCtrl.text.trim();
    final price = double.parse(priceCtrl.text);
    final quantity = int.parse(qtyCtrl.text);
    final note = noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim();

    setState(() {
      _editableItems.add(_EditableItem(
        productId: null,
        barcode: null,
        productName: name,
        quantity: quantity,
        costPrice: 0,
        salePrice: price,
        note: note,
      ));
    });
  }

  void _saveInvoice() {
    if (_editableItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocalizationService().get('noItemsInInvoice')),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final updatedSaleItems = _editableItems.map((item) {
      final totalAmount = item.salePrice * item.quantity;
      final profit = (item.salePrice - item.costPrice) * item.quantity;
      return SaleItem(
        productId: item.productId,
        barcode: item.barcode,
        productName: item.productName,
        quantity: item.quantity,
        costPrice: item.costPrice,
        salePrice: item.salePrice,
        totalAmount: totalAmount,
        profit: profit,
        finalAmount: totalAmount,
        invoiceId: widget.invoice.id,
        note: item.note,
      );
    }).toList();

    context.read<InvoiceBloc>().add(InvoiceFullUpdate(
      invoiceId: widget.invoice.id!,
      updatedItems: updatedSaleItems,
      discountAmount: _discount,
      customerName: _selectedCustomerName,
      customerId: _selectedCustomerId,
      paymentMethod: _paymentMethod,
      paidAmount: widget.invoice.paidAmount,
    ));

    // Refresh products and customers to reflect inventory changes
    di.sl<CustomerBloc>().add(CustomerRefresh());
    di.sl<ProductBloc>().add(ProductRefresh());

    Navigator.pop(context);
    // Also close the details dialog
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 30),
      child: Container(
        width: 780,
        constraints: const BoxConstraints(maxHeight: 750),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── Header ───
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primary],
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_document,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${LocalizationService().get('editInvoice')} #${widget.invoice.id}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.invoice.customerName ??
                              LocalizationService().get('walkInCustomer'),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        child: Icon(Icons.close,
                            color: Colors.white.withOpacity(0.8), size: 22),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ─── Body ───
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Customer (select from existing customers) ───
                    InkWell(
                      onTap: _openCustomerPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(10),
                          color: AppColors.surface,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person_outline, size: 20, color: Colors.grey),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedCustomerName ?? LocalizationService().get('selectCustomer'),
                                style: TextStyle(fontSize: 14, color: _selectedCustomerName == null ? AppColors.textHint : AppColors.textPrimary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ─── Product Search ───
                    Row(
                      children: [
                        Icon(Icons.add_shopping_cart,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          LocalizationService().get('addItem'),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const Spacer(),
                        // Add Custom Product button
                        OutlinedButton.icon(
                          onPressed: _showAddCustomProductDialog,
                          icon: const Icon(Icons.add_box_outlined, size: 16),
                          label: Text(LocalizationService().get('addCustomProduct'),
                              style: const TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: BorderSide(color: AppColors.primary.withOpacity(0.4)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: LocalizationService()
                            .get('searchAndAddProducts'),
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child:
                                    SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchResults = []);
                                    },
                                  )
                                : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: _searchProducts,
                    ),

                    // Search results dropdown
                    if (_searchResults.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 160),
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.divider),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final product = _searchResults[index];
                            return ListTile(
                              dense: true,
                              leading: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(Icons.inventory_2_outlined,
                                    size: 18, color: AppColors.primary),
                              ),
                              title: Text(product.name,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500)),
                              subtitle: Text(
                                '₪${product.price.toStringAsFixed(2)} · ${LocalizationService().get('quantity')}: ${product.quantity}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: Icon(Icons.add_circle_outline,
                                  color: AppColors.primary, size: 22),
                              onTap: () => _addProduct(product),
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 16),

                    // ─── Items List ───
                    Row(
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          LocalizationService().get('invoiceItems'),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_editableItems.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Items table
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.divider),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _editableItems.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(32),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.inbox_outlined,
                                        size: 36, color: AppColors.textHint),
                                    const SizedBox(height: 8),
                                    Text(
                                      LocalizationService()
                                          .get('noItemsInInvoice'),
                                      style: const TextStyle(
                                          color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Column(
                              children: [
                                // Table header
                                Container(
                                  color: AppColors.primary.withOpacity(0.07),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 4,
                                        child: Text(
                                          LocalizationService().get('product'),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                            color: AppColors.primary
                                                .withOpacity(0.8),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          LocalizationService()
                                              .get('unitPrice'),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                            color: AppColors.primary
                                                .withOpacity(0.8),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          LocalizationService().get('qty'),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                            color: AppColors.primary
                                                .withOpacity(0.8),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          LocalizationService().get('total'),
                                          textAlign: TextAlign.end,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                            color: AppColors.primary
                                                .withOpacity(0.8),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 40),
                                    ],
                                  ),
                                ),
                                // Table rows
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxHeight: 220),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: _editableItems.length,
                                    itemBuilder: (context, index) {
                                      final item = _editableItems[index];
                                      final isEven = index.isEven;
                                      return Container(
                                        color: isEven
                                            ? Colors.transparent
                                            : AppColors.background
                                                .withOpacity(0.5),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        child: Row(
                                          children: [
                                            // Product name
                                            Expanded(
                                              flex: 4,
                                              child: Text(
                                                item.productName,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 13),
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ),
                                            // Price (editable)
                                            Expanded(
                                              flex: 2,
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                onTap: () => _showEditPriceDialog(
                                                    index, item),
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.info
                                                        .withOpacity(0.08),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                    border: Border.all(
                                                        color: AppColors.info
                                                            .withOpacity(0.2)),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        '₪${item.salePrice.toStringAsFixed(2)}',
                                                        style: const TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w500),
                                                      ),
                                                      const SizedBox(width: 2),
                                                      Icon(
                                                          Icons
                                                              .edit_outlined,
                                                          size: 12,
                                                          color:
                                                              AppColors.info),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            // Quantity controls
                                            Expanded(
                                              flex: 2,
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  _QuantityButton(
                                                    icon: Icons.remove,
                                                    onTap: item.quantity > 1
                                                        ? () =>
                                                            _updateQuantity(
                                                                index,
                                                                item.quantity -
                                                                    1)
                                                        : null,
                                                  ),
                                                  Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8),
                                                    child: Text(
                                                      '${item.quantity}',
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 13),
                                                    ),
                                                  ),
                                                  _QuantityButton(
                                                    icon: Icons.add,
                                                    onTap: () =>
                                                        _updateQuantity(
                                                            index,
                                                            item.quantity + 1),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Total
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                '₪${item.totalAmount.toStringAsFixed(2)}',
                                                textAlign: TextAlign.end,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13),
                                              ),
                                            ),
                                            // Remove button
                                            SizedBox(
                                              width: 40,
                                              child: IconButton(
                                                icon: Icon(
                                                    Icons
                                                        .delete_outline_rounded,
                                                    size: 18,
                                                    color: AppColors.error),
                                                onPressed: () =>
                                                    _removeItem(index),
                                                tooltip: LocalizationService()
                                                    .get('removeItem'),
                                                splashRadius: 18,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                    ),

                    const SizedBox(height: 16),

                    // ─── Discount + Payment Method ───
                    Row(
                      children: [
                        // Discount
                        Expanded(
                          child: TextField(
                            controller: _discountController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                              labelText: LocalizationService()
                                  .get('discountOptional'),
                              prefixText: '₪ ',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Payment method
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _paymentMethod,
                            decoration: InputDecoration(
                              labelText: LocalizationService()
                                  .get('paymentMethod'),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            items: [
                              DropdownMenuItem(
                                  value: 'cash',
                                  child: Text(
                                      LocalizationService().get('cash'))),
                              DropdownMenuItem(
                                  value: 'card',
                                  child: Text(
                                      LocalizationService().get('card'))),
                              DropdownMenuItem(
                                  value: 'credit',
                                  child: Text(
                                      LocalizationService().get('credit'))),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _paymentMethod = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ─── Summary ───
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.04),
                            AppColors.success.withOpacity(0.04),
                          ],
                        ),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        children: [
                          _SummaryRow(
                            label: LocalizationService().get('subtotal'),
                            value: '₪${_totalAmount.toStringAsFixed(2)}',
                          ),
                          if (_discount > 0) ...[
                            const SizedBox(height: 6),
                            _SummaryRow(
                              label: LocalizationService().get('discount'),
                              value:
                                  '-₪${_discount.toStringAsFixed(2)}',
                              valueColor: AppColors.error,
                            ),
                          ],
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child:
                                Divider(color: AppColors.divider, height: 1),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${LocalizationService().get('total')}:',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '₪${_finalAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: AppColors.success,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ─── Bottom Actions ───
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.divider)),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                    ),
                    child: Text(LocalizationService().get('cancel')),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _editableItems.isNotEmpty ? _saveInvoice : null,
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label:
                        Text(LocalizationService().get('updateInvoice')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPriceDialog(int index, _EditableItem item) {
    final controller =
        TextEditingController(text: item.salePrice.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocalizationService().get('editPrice')),
        content: TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            labelText: LocalizationService().get('newPrice'),
            prefixText: '₪ ',
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(LocalizationService().get('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              final newPrice = double.tryParse(controller.text);
              if (newPrice != null && newPrice >= 0) {
                _updatePrice(index, newPrice);
                Navigator.pop(ctx);
              }
            },
            child: Text(LocalizationService().get('update')),
          ),
        ],
      ),
    );
  }
}

// ─── Helper model for editable items ───
class _EditableItem {
  int? productId;
  String? barcode;
  String productName;
  int quantity;
  double costPrice;
  double salePrice;
  String? note;

  _EditableItem({
    this.productId,
    this.barcode,
    required this.productName,
    required this.quantity,
    required this.costPrice,
    required this.salePrice,
    this.note,
  });

  factory _EditableItem.fromSaleItem(SaleItem item) {
    return _EditableItem(
      productId: item.productId,
      barcode: item.barcode,
      productName: item.productName,
      quantity: item.quantity,
      costPrice: item.costPrice,
      salePrice: item.salePrice,
      note: item.note,
    );
  }

  double get totalAmount => salePrice * quantity;
  double get profit => (salePrice - costPrice) * quantity;
}

// ─── Quantity button widget ───
class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _QuantityButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: isEnabled
                ? AppColors.primary.withOpacity(0.1)
                : AppColors.divider.withOpacity(0.5),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isEnabled
                  ? AppColors.primary.withOpacity(0.3)
                  : AppColors.divider,
            ),
          ),
          child: Icon(
            icon,
            size: 14,
            color: isEnabled ? AppColors.primary : AppColors.textHint,
          ),
        ),
      ),
    );
  }
}

// ─── Summary row widget ───
class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 14)),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
