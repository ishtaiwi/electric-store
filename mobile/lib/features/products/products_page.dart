import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
  List<String> _brands = [];
  List<String> _categories = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _lowStockOnly = false;
  String? _brandFilter;
  String? _categoryFilter;
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
    _loadTaxonomy();
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

  Future<void> _loadTaxonomy() async {
    try {
      final results = await Future.wait([
        widget.repository.getBrands(),
        widget.repository.getCategories(),
      ]);
      if (!mounted) return;
      setState(() {
        _brands = results[0];
        _categories = results[1];
      });
    } catch (_) {
      // Filters stay empty; products list still works.
    }
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
        brand: _brandFilter,
        category: _categoryFilter,
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
        brand: _brandFilter,
        category: _categoryFilter,
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

  Future<void> _refresh() async {
    widget.repository.invalidateCache();
    await _loadTaxonomy();
    return _loadFirstPage();
  }

  bool get _hasActiveFilters =>
      _lowStockOnly ||
      (_brandFilter != null && _brandFilter!.isNotEmpty) ||
      (_categoryFilter != null && _categoryFilter!.isNotEmpty);

  void _clearFilters() {
    setState(() {
      _lowStockOnly = false;
      _brandFilter = null;
      _categoryFilter = null;
    });
    _loadFirstPage();
  }

  Future<void> _openDetails(Product product) async {
    final updated = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      builder: (_) => ProductDetailsSheet(
        product: product,
        repository: widget.repository,
      ),
    );
    if (updated != null && mounted) {
      final index = _items.indexWhere((p) => p.id == updated.id);
      if (index >= 0) {
        setState(() => _items[index] = updated);
      }
    }
  }

  Widget _filterDropdown({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Expanded(
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            isExpanded: true,
            value: (value != null && options.contains(value)) ? value : null,
            hint: const Text('الكل', style: TextStyle(fontSize: 13)),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('الكل', style: TextStyle(fontSize: 13)),
              ),
              ...options.map(
                (o) => DropdownMenuItem<String?>(
                  value: o,
                  child: Text(o, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                ),
              ),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
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
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                _filterDropdown(
                  label: 'النوع',
                  value: _brandFilter,
                  options: _brands,
                  onChanged: (v) {
                    setState(() => _brandFilter = v);
                    _loadFirstPage();
                  },
                ),
                const SizedBox(width: 8),
                _filterDropdown(
                  label: 'الصنف',
                  value: _categoryFilter,
                  options: _categories,
                  onChanged: (v) {
                    setState(() => _categoryFilter = v);
                    _loadFirstPage();
                  },
                ),
              ],
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
                if (_hasActiveFilters) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _clearFilters,
                    child: const Text('مسح الفلاتر'),
                  ),
                ],
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
          _searchCtrl.text.trim().isNotEmpty || _hasActiveFilters
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
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 72,
            height: 72,
            child: p.hasImage
                ? Image.network(
                    p.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _stockAvatar(p),
                  )
                : _stockAvatar(p),
          ),
        ),
        title: Text(
          p.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
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

  Widget _stockAvatar(Product p) {
    return ColoredBox(
      color: p.isOutOfStock
          ? AppColors.error
          : p.isLowStock
              ? AppColors.warning
              : AppColors.primaryLight,
      child: Icon(
        p.isOutOfStock ? Icons.remove_shopping_cart : Icons.inventory_2,
        color: Colors.white,
        size: 32,
      ),
    );
  }
}


/// Product details with optional photo upload to Supabase Storage.
class ProductDetailsSheet extends StatefulWidget {
  const ProductDetailsSheet({
    super.key,
    required this.product,
    required this.repository,
  });

  final Product product;
  final ProductRepository repository;

  @override
  State<ProductDetailsSheet> createState() => _ProductDetailsSheetState();
}

class _ProductDetailsSheetState extends State<ProductDetailsSheet> {
  late Product _product;
  bool _uploading = false;
  String? _status;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _product = widget.product;
  }

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

  Future<void> _pickAndUpload(ImageSource source) async {
    if (_product.id == null) return;
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 82,
      );
      if (picked == null || !mounted) return;

      setState(() {
        _uploading = true;
        _status = 'جاري رفع الصورة...';
      });

      final updated = await widget.repository.uploadProductImage(
        productId: _product.id!,
        filePath: picked.path,
        mimeType: picked.mimeType,
      );

      if (!mounted) return;
      setState(() {
        _product = updated;
        _uploading = false;
        _status = 'تم حفظ الصورة';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _status = e.toString();
      });
    }
  }

  Future<void> _showImageSourceSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('التقاط صورة'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUpload(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('اختيار من المعرض'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUpload(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeImage() async {
    if (_product.id == null) return;
    setState(() {
      _uploading = true;
      _status = 'جاري حذف الصورة...';
    });
    try {
      final updated = await widget.repository.clearProductImage(_product.id!);
      if (!mounted) return;
      setState(() {
        _product = updated;
        _uploading = false;
        _status = 'تم حذف الصورة';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _status = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;

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
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 180,
                    height: 180,
                    child: _product.hasImage
                        ? Image.network(
                            _product.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const ColoredBox(
                              color: Color(0xFFE8EEF5),
                              child: Icon(Icons.broken_image, size: 48),
                            ),
                          )
                        : const ColoredBox(
                            color: Color(0xFFE8EEF5),
                            child: Icon(
                              Icons.add_a_photo_outlined,
                              size: 48,
                              color: AppColors.textSecondary,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_uploading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_status != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _status!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _status!.startsWith('تم')
                          ? AppColors.success
                          : (_uploading
                              ? AppColors.textSecondary
                              : AppColors.error),
                      fontSize: 13,
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _uploading ? null : _showImageSourceSheet,
                      icon: const Icon(Icons.add_a_photo),
                      label: Text(_product.hasImage ? 'تغيير الصورة' : 'إضافة صورة'),
                    ),
                  ),
                  if (_product.hasImage) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _uploading ? null : _removeImage,
                      tooltip: 'حذف الصورة',
                      icon: const Icon(Icons.delete_outline, color: AppColors.error),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              _row('اسم المنتج', _product.name),
              _row('الباركود', _product.barcode ?? ''),
              _row('النوع', _product.brand ?? ''),
              _row('الصنف', _product.category ?? ''),
              _row('الكمية', '${_product.quantity}'),
              _row('حد التنبيه', '${_product.minStock}'),
              _row('سعر البيع', Formatters.money(_product.price)),
              _row('سعر التكلفة', Formatters.money(_product.costPrice)),
              if (_product.supplier != null && _product.supplier!.isNotEmpty)
                _row('المورد', _product.supplier!),
              _row('ملاحظة', _product.note ?? ''),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(context, _product),
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
