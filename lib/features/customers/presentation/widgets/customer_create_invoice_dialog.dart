import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/domain/repositories/product_repository.dart';
import '../../../sales/domain/entities/cart_item.dart';
import '../../../sales/domain/repositories/sales_repository.dart';
import '../../domain/entities/customer.dart';

/// Excel-style dialog to register goods taken by a customer.
/// Totals are calculated automatically as rows are added/edited.
class CustomerCreateInvoiceDialog extends StatefulWidget {
  final Customer customer;

  const CustomerCreateInvoiceDialog({super.key, required this.customer});

  @override
  State<CustomerCreateInvoiceDialog> createState() => _CustomerCreateInvoiceDialogState();
}

class _CustomerCreateInvoiceDialogState extends State<CustomerCreateInvoiceDialog> {
  final _items = <_LineItem>[];
  final _searchController = TextEditingController();
  final _discountController = TextEditingController();
  final _dateFormat = DateFormat('dd-MM-yyyy');
  List<Product> _searchResults = [];
  bool _isSearching = false;
  bool _isSaving = false;
  DateTime _saleDate = DateTime.now();

  @override
  void dispose() {
    _searchController.dispose();
    _discountController.dispose();
    for (final item in _items) {
      item.qtyController.dispose();
      item.priceController.dispose();
    }
    super.dispose();
  }

  double get _subtotal => _items.fold(0.0, (s, i) => s + i.totalAmount);
  double get _discount => double.tryParse(_discountController.text) ?? 0;
  double get _grandTotal => _subtotal - _discount;
  int get _totalQty => _items.fold(0, (s, i) => s + i.quantity);

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await di.sl<ProductRepository>().searchProducts(query.trim());
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

  Future<void> _addByBarcode(String code) async {
    if (code.trim().isEmpty) return;
    final results = await di.sl<ProductRepository>().searchProducts(code.trim());
    if (results.isNotEmpty) {
      _addProduct(results.first);
    }
  }

  void _addProduct(Product product) {
    final idx = _items.indexWhere((i) => i.productId == product.id);
    setState(() {
      if (idx >= 0) {
        _items[idx].quantity++;
        _items[idx].qtyController.text = '${_items[idx].quantity}';
      } else {
        _items.add(_LineItem(
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

  void _addCustomRow() {
    setState(() {
      _items.add(_LineItem(
        productId: null,
        barcode: null,
        productName: LocalizationService().get('customProduct'),
        quantity: 1,
        costPrice: 0,
        salePrice: 0,
      ));
    });
  }

  void _removeRow(int index) {
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

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
    final loc = LocalizationService();
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.get('noItemsInInvoice')), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final cartItems = _items.map((item) {
        return CartItem(
          product: Product(
            id: item.productId,
            name: item.productName,
            barcode: item.barcode,
            quantity: 0,
            price: item.salePrice,
            costPrice: item.costPrice,
          ),
          quantity: item.quantity,
          customPrice: item.salePrice,
        );
      }).toList();

      await di.sl<SalesRepository>().createSale(
        items: cartItems,
        customerId: widget.customer.id,
        customerName: widget.customer.name,
        discountAmount: _discount,
        paymentMethod: 'cash',
        paidAmount: 0,
        saleDate: _saleDate,
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc.get('error')}: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = LocalizationService();
    final border = TableBorder.all(color: Colors.grey.shade400);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1050, maxHeight: 780),
        child: Column(
          children: [
            _buildHeader(loc),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: loc.get('searchOrBarcode'),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : null,
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: _search,
                      onSubmitted: _addByBarcode,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _addCustomRow,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(loc.get('addRow')),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text('${loc.get('voucherDate')}: ${_dateFormat.format(_saleDate)}'),
                  ),
                ],
              ),
            ),
            if (_searchResults.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (_, i) {
                    final p = _searchResults[i];
                    return ListTile(
                      dense: true,
                      title: Text(p.name),
                      subtitle: Text('${p.barcode ?? '-'} | ${loc.formatCurrency(p.price)}'),
                      onTap: () => _addProduct(p),
                    );
                  },
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.table_chart, size: 56, color: AppColors.textHint),
                            const SizedBox(height: 12),
                            Text(loc.get('addProductsToLedger'), style: const TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        child: Table(
                          border: border,
                          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                          columnWidths: const {
                            0: FixedColumnWidth(36),
                            1: FixedColumnWidth(100),
                            2: FlexColumnWidth(3),
                            3: FixedColumnWidth(80),
                            4: FixedColumnWidth(100),
                            5: FixedColumnWidth(110),
                            6: FixedColumnWidth(44),
                          },
                          children: [
                            TableRow(
                              decoration: BoxDecoration(color: AppColors.primaryDark.withOpacity(0.1)),
                              children: [
                                _hdr('#'),
                                _hdr(loc.get('itemSku')),
                                _hdr(loc.get('productName')),
                                _hdr(loc.get('quantity')),
                                _hdr(loc.get('itemPrice')),
                                _hdr(loc.get('lineTotal')),
                                _hdr(''),
                              ],
                            ),
                            ..._items.asMap().entries.map((e) => _dataRow(e.key, e.value, loc)),
                            TableRow(
                              decoration: BoxDecoration(color: Colors.grey.shade100),
                              children: [
                                _cell(''),
                                _cell(''),
                                _cell(loc.get('subtotal'), bold: true),
                                _cell('$_totalQty', bold: true),
                                _cell(''),
                                _cell(loc.formatCurrency(_subtotal), bold: true, color: AppColors.primary),
                                _cell(''),
                              ],
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            _buildFooter(loc),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(LocalizationService loc) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.primaryDark, AppColors.primary]),
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.table_chart, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.get('registerCustomerGoods'),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.customer.name,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(LocalizationService loc) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: TextField(
              controller: _discountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: loc.get('discount'),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const Spacer(),
          _totalBox(loc.get('subtotal'), loc.formatCurrency(_subtotal), AppColors.info),
          const SizedBox(width: 16),
          _totalBox(loc.get('grandTotal'), loc.formatCurrency(_grandTotal), AppColors.error, large: true),
          const SizedBox(width: 24),
          TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.get('cancel'))),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save),
            label: Text(loc.get('saveInvoice')),
          ),
        ],
      ),
    );
  }

  Widget _totalBox(String label, String value, Color color, {bool large = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: color)),
        Text(
          value,
          style: TextStyle(
            fontSize: large ? 20 : 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  TableRow _dataRow(int index, _LineItem item, LocalizationService loc) {
    return TableRow(
      decoration: BoxDecoration(color: index.isEven ? Colors.white : Colors.grey.shade50),
      children: [
        _cell('${index + 1}'),
        _cell(item.barcode ?? '-'),
        _cell(item.productName),
        Padding(
          padding: const EdgeInsets.all(4),
          child: TextField(
            controller: item.qtyController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
            onChanged: (v) {
              final q = int.tryParse(v) ?? 1;
              setState(() => item.quantity = q > 0 ? q : 1);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(4),
          child: TextField(
            controller: item.priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
            onChanged: (v) => setState(() => item.salePrice = double.tryParse(v) ?? 0),
          ),
        ),
        _cell(loc.formatCurrency(item.totalAmount), bold: true),
        Padding(
          padding: const EdgeInsets.all(4),
          child: IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
            onPressed: () => _removeRow(index),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ),
      ],
    );
  }

  Widget _hdr(String t) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
      );

  Widget _cell(String t, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Text(t, style: TextStyle(fontSize: 11, fontWeight: bold ? FontWeight.bold : null, color: color)),
      );
}

class _LineItem {
  final int? productId;
  final String? barcode;
  String productName;
  int quantity;
  final double costPrice;
  double salePrice;
  late final TextEditingController qtyController;
  late final TextEditingController priceController;

  _LineItem({
    required this.productId,
    this.barcode,
    required this.productName,
    required this.quantity,
    required this.costPrice,
    required this.salePrice,
  }) {
    qtyController = TextEditingController(text: '$quantity');
    priceController = TextEditingController(text: salePrice.toStringAsFixed(2));
  }

  double get totalAmount => salePrice * quantity;

  void dispose() {
    qtyController.dispose();
    priceController.dispose();
  }
}
