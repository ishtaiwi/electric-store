import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../data/auth_product_repos.dart';
import '../../data/models.dart';
import '../../data/sales_repository.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({
    super.key,
    required this.sales,
    required this.products,
    required this.user,
  });

  final SalesRepository sales;
  final ProductRepository products;
  final AppUser user;

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  final _searchCtrl = TextEditingController();
  final _discountCtrl = TextEditingController(text: '0');
  Timer? _debounce;

  List<Product> _productHits = [];
  List<CartLine> _cart = [];
  bool _searching = false;
  bool _checkingOut = false;
  String? _error;

  /// Guards against a slow response from an outdated search overwriting
  /// the results of a newer one.
  int _searchId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final term = _searchCtrl.text.trim();
    final searchId = ++_searchId;
    if (term.isEmpty) {
      setState(() {
        _productHits = [];
        _searching = false;
      });
      return;
    }

    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final hits = await widget.products.search(term);
      if (!mounted || searchId != _searchId) return;
      setState(() {
        _productHits = hits;
        _searching = false;
      });
    } catch (e) {
      if (!mounted || searchId != _searchId) return;
      setState(() {
        _error = e.toString();
        _searching = false;
      });
    }
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchId++;
    _searchCtrl.clear();
    setState(() {
      _productHits = [];
      _searching = false;
    });
  }

  void _onSearchChanged(String _) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _runSearch();
    });
  }

  void _addProduct(Product p) {
    final idx = p.id == null
        ? -1
        : _cart.indexWhere((c) => c.product.id == p.id);
    if (idx >= 0) {
      _cart[idx] = _cart[idx].copyWith(quantity: _cart[idx].quantity + 1);
    } else {
      _cart = [..._cart, CartLine(product: p, quantity: 1)];
    }
    _clearSearch();
  }

  Future<void> _addCustomProduct({String? initialName}) async {
    final nameCtrl = TextEditingController(text: initialName ?? '');
    final priceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      builder: (ctx) {
        final keyboard = MediaQuery.viewInsetsOf(ctx).bottom;
        return SafeArea(
          maintainBottomViewPadding: true,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + keyboard),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'منتج غير موجود بالمخزون',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'يُضاف للفاتورة التجريبية فقط — لا يُنشأ في المخزون.',
                  style: TextStyle(
                      fontSize: 12.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'اسم المنتج'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: priceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(labelText: 'سعر البيع'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: const InputDecoration(labelText: 'الكمية'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('إضافة للسلة'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (ok != true || !mounted) return;
    final name = nameCtrl.text.trim();
    final price = double.tryParse(priceCtrl.text.trim()) ?? 0;
    final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
    if (name.isEmpty || price < 0 || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أدخل اسمًا وسعرًا وكمية صحيحة'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _cart = [
        ..._cart,
        CartLine(
          product: Product(
            name: name,
            quantity: 0,
            price: price,
            costPrice: 0,
            note: 'منتج مخصص — غير موجود بالمخزون',
          ),
          quantity: qty,
          customPrice: price,
        ),
      ];
    });
    _clearSearch();
  }

  void _setQty(int index, int qty) {
    if (qty <= 0) {
      setState(() => _cart = [..._cart]..removeAt(index));
      return;
    }
    setState(() {
      _cart = [..._cart];
      _cart[index] = _cart[index].copyWith(quantity: qty);
    });
  }

  double get _subtotal =>
      _cart.fold(0.0, (sum, line) => sum + line.totalPrice);

  double get _discount {
    final v = double.tryParse(_discountCtrl.text.trim()) ?? 0;
    if (v < 0) return 0;
    if (v > _subtotal) return _subtotal;
    return v;
  }

  double get _total => _subtotal - _discount;

  Future<void> _checkout() async {
    if (_cart.isEmpty || _checkingOut) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('فاتورة تجريبية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'هذه فاتورة للموبايل فقط — لا تغيّر المخزون ولا أرصدة الزبائن.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Text('عدد الأصناف: ${_cart.length}'),
            Text('الإجمالي: ${Formatters.money(_total)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حفظ تجريبي'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _checkingOut = true);
    try {
      final invoice = await widget.sales.checkout(
        items: List<CartLine>.from(_cart),
        discountAmount: _discount,
        userId: widget.user.id,
      );
      if (!mounted) return;
      setState(() {
        _cart = [];
        _discountCtrl.text = '0';
      });
      _clearSearch();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم حفظ فاتورة تجريبية ${invoice.invoiceNumber}\n'
            '${Formatters.money(invoice.finalAmount)}',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showHits = _searchCtrl.text.trim().isNotEmpty;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Column(
      children: [
        if (!keyboardOpen)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.warning),
            ),
            child: const Text(
              'فواتير تجريبية — لا تؤثر على المخزون أو أرصدة الديسكتوب.',
              style: TextStyle(fontSize: 12, height: 1.3),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'ابحث عن منتج...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _clearSearch,
                          )
                        : null,
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'منتج غير موجود',
                onPressed: () => _addCustomProduct(
                  initialName: _searchCtrl.text.trim().isEmpty
                      ? null
                      : _searchCtrl.text.trim(),
                ),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Text(_error!,
                style: const TextStyle(color: AppColors.error, fontSize: 12)),
          ),
        Expanded(
          child: showHits ? _buildProductHits() : _buildCart(),
        ),
        _buildCheckoutBar(compact: keyboardOpen),
      ],
    );
  }

  Widget _buildProductHits() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      children: [
        if (_searching)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_productHits.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'لا يوجد منتج بهذا الاسم في المخزون',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ..._productHits.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Card(
              child: ListTile(
                dense: true,
                title:
                    Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  'كمية: ${p.quantity} · ${Formatters.money(p.price)}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.add_circle,
                    color: AppColors.primary),
                onTap: () => _addProduct(p),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: () => _addCustomProduct(
            initialName: _searchCtrl.text.trim(),
          ),
          icon: const Icon(Icons.post_add),
          label: const Text('إضافة كمنتج غير موجود بالمخزون'),
        ),
      ],
    );
  }

  Widget _buildCart() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: Row(
            children: [
              const Text(
                'السلة',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Spacer(),
              Text(
                '${_cart.length} صنف',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
              if (_cart.isNotEmpty)
                IconButton(
                  tooltip: 'تفريغ السلة',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _cart = []),
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.error),
                ),
            ],
          ),
        ),
        Expanded(
          child: _cart.isEmpty
              ? const Center(
                  child: Text(
                    'ابحث عن منتج أو أضف منتجًا غير موجود',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  itemCount: _cart.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final line = _cart[i];
                    final isCustom = line.product.id == null;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    line.product.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    [
                                      Formatters.money(line.unitPrice),
                                      if (isCustom) 'غير موجود',
                                    ].join(' · '),
                                    style: TextStyle(
                                      color: isCustom
                                          ? AppColors.warning
                                          : AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () =>
                                  _setQty(i, line.quantity - 1),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text(
                              '${line.quantity}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () =>
                                  _setQty(i, line.quantity + 1),
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                            SizedBox(
                              width: 68,
                              child: Text(
                                Formatters.money(line.totalPrice),
                                textAlign: TextAlign.end,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  fontSize: 13,
                                ),
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
    );
  }

  Widget _buildCheckoutBar({required bool compact}) {
    return Material(
      elevation: 8,
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding:
              EdgeInsets.fromLTRB(12, compact ? 6 : 8, 12, compact ? 6 : 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: _discountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'خصم',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'المجموع: ${Formatters.money(_subtotal)}',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 11),
                        ),
                        Text(
                          Formatters.money(_total),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed:
                      _cart.isEmpty || _checkingOut ? null : _checkout,
                  icon: _checkingOut
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.receipt_long),
                  label: const Text('حفظ فاتورة تجريبية'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
