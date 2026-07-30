import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../core/widgets/list_skeleton.dart';
import '../../data/auth_product_repos.dart';
import '../../data/models.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({
    super.key,
    required this.repository,
    required this.user,
  });

  final ProductRepository repository;
  final AppUser user;

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage>
    with AutomaticKeepAliveClientMixin {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  final _scrollCtrl = ScrollController();
  Timer? _debounce;

  final List<Product> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _lowStockOnly = false;
  String? _error;

  /// Guards against a slow response from an outdated search overwriting
  /// the results of a newer one.
  int _requestId = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final position = _scrollCtrl.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  void _onSearchChanged(String _) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _loadFirstPage();
    });
  }

  Future<void> _loadFirstPage() async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.repository.fetchPage(
        query: _searchCtrl.text,
        lowStockOnly: _lowStockOnly,
      );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _hasMore = page.hasMore;
        _loading = false;
      });
      if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
    } catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || !_hasMore) return;
    final requestId = _requestId;
    setState(() => _loadingMore = true);
    try {
      final page = await widget.repository.fetchPage(
        query: _searchCtrl.text,
        lowStockOnly: _lowStockOnly,
        offset: _items.length,
      );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _items.addAll(page.items);
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _hasMore = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _refresh() {
    widget.repository.invalidateCache();
    return _loadFirstPage();
  }

  Future<void> _openDetails(Product product) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      builder: (_) => ProductDetailsSheet(product: product),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'بحث بالاسم أو الباركود...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _debounce?.cancel();
                          _searchCtrl.clear();
                          _loadFirstPage();
                          _searchFocus.requestFocus();
                        },
                      )
                    : null,
              ),
              onChanged: _onSearchChanged,
              onSubmitted: (_) {
                _debounce?.cancel();
                _loadFirstPage();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('نواقص المخزون'),
                  selected: _lowStockOnly,
                  onSelected: (v) {
                    setState(() => _lowStockOnly = v);
                    _loadFirstPage();
                  },
                ),
                const Spacer(),
                Text(
                  '${_items.length}${_hasMore ? '+' : ''} منتج',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                IconButton(
                    onPressed: _refresh, icon: const Icon(Icons.refresh)),
              ],
            ),
          ),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading && _items.isEmpty) {
      return const ListSkeleton();
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _refresh,
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(
          _searchCtrl.text.trim().isNotEmpty
              ? 'لا توجد نتائج للبحث'
              : 'لا توجد منتجات',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          if (i >= _items.length) return const PageLoadingFooter();
          return _ProductTile(
            product: _items[i],
            onTap: () => _openDetails(_items[i]),
          );
        },
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = product;
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: p.isOutOfStock
              ? AppColors.error
              : p.isLowStock
                  ? AppColors.warning
                  : AppColors.primaryLight,
          child: Icon(
            p.isOutOfStock ? Icons.remove_shopping_cart : Icons.inventory_2,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          p.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          [
            if (p.barcode != null && p.barcode!.isNotEmpty)
              'باركد: ${p.barcode}',
            'كمية: ${p.quantity}',
            if (p.isLowStock) 'ناقص',
          ].join(' · '),
          style: TextStyle(
            color: p.isLowStock ? AppColors.error : AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        trailing: Text(
          Formatters.money(p.price),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}


/// Read-only product details — no create/edit on mobile.
class ProductDetailsSheet extends StatelessWidget {
  const ProductDetailsSheet({super.key, required this.product});

  final Product product;

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? '—' : value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return SafeArea(
      maintainBottomViewPadding: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'تفاصيل المنتج',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _row('اسم المنتج', product.name),
              _row('الباركود', product.barcode ?? ''),
              _row('الكمية', '${product.quantity}'),
              _row('حد التنبيه', '${product.minStock}'),
              _row('سعر البيع', Formatters.money(product.price)),
              _row('سعر التكلفة', Formatters.money(product.costPrice)),
              if (product.supplier != null && product.supplier!.isNotEmpty)
                _row('المورد', product.supplier!),
              _row('ملاحظة', product.note ?? ''),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('إغلاق'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
