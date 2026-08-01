import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/helpers.dart';
import 'models.dart';
import 'query_utils.dart';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;
  AppUser? currentUser;

  Future<AppUser?> login(String username, String password) async {
    final rows = await _client
        .from('users')
        .select()
        .eq('username', username.trim())
        .limit(1);

    final list = List<Map<String, dynamic>>.from(rows as List);
    if (list.isEmpty) return null;

    final row = list.first;
    final stored = row['password'] as String? ?? '';
    if (!Security.verifyPassword(password, stored)) return null;

    // Upgrade plain-text password if needed
    final hashed = Security.hashPassword(password);
    if (stored == password && stored != hashed) {
      await _client
          .from('users')
          .update({'password': hashed}).eq('id', row['id']);
    }

    currentUser = AppUser.fromMap(row);
    return currentUser;
  }

  void logout() => currentUser = null;
}

class ProductRepository {
  ProductRepository(this._client);

  final SupabaseClient _client;

  static const int pageSize = 40;
  static const String _columns =
      'id,name,barcode,quantity,price,cost_price,note,brand,category,supplier,'
      'supplier_id,min_stock,image_url,last_updated';

  static const String _storageBucket = 'product-images';

  /// Set to false the first time `mobile_products` turns out to be missing,
  /// so we stop paying for a failed round-trip on every search.
  bool _serverSearch = true;

  List<Product>? _legacyCache;
  DateTime? _legacyCachedAt;
  List<String>? _brandsCache;
  List<String>? _categoriesCache;
  DateTime? _taxonomyCachedAt;

  /// Fetches one page of products, filtered and sorted by Postgres.
  Future<PagedResult<Product>> fetchPage({
    String? query,
    bool lowStockOnly = false,
    String? brand,
    String? category,
    int offset = 0,
    int limit = pageSize,
  }) async {
    if (_serverSearch) {
      try {
        return await _fetchPageFromView(
          query: query,
          lowStockOnly: lowStockOnly,
          brand: brand,
          category: category,
          offset: offset,
          limit: limit,
        );
      } catch (e) {
        if (!isMissingRelation(e)) rethrow;
        _serverSearch = false;
      }
    }
    return _fetchPageLegacy(
      query: query,
      lowStockOnly: lowStockOnly,
      brand: brand,
      category: category,
      offset: offset,
      limit: limit,
    );
  }

  Future<PagedResult<Product>> _fetchPageFromView({
    required String? query,
    required bool lowStockOnly,
    required String? brand,
    required String? category,
    required int offset,
    required int limit,
  }) async {
    var filter = _client.from('mobile_products').select(_columns);
    for (final token in searchTokens(query)) {
      filter = filter.ilike('search_text', '%$token%');
    }
    if (lowStockOnly) {
      filter = filter.eq('is_low_stock', true);
    }
    final brandFilter = brand?.trim();
    if (brandFilter != null && brandFilter.isNotEmpty) {
      filter = filter.eq('brand', brandFilter);
    }
    final categoryFilter = category?.trim();
    if (categoryFilter != null && categoryFilter.isNotEmpty) {
      filter = filter.eq('category', categoryFilter);
    }

    // One extra row tells us whether another page exists.
    final rows = await filter.order('name').range(offset, offset + limit);
    final list = List<Map<String, dynamic>>.from(rows as List);
    final hasMore = list.length > limit;
    return PagedResult(
      items: list.take(limit).map(Product.fromMap).toList(),
      hasMore: hasMore,
    );
  }

  /// Used only when `mobile_performance.sql` has not been applied yet:
  /// download once, cache briefly, then page in memory.
  Future<PagedResult<Product>> _fetchPageLegacy({
    required String? query,
    required bool lowStockOnly,
    required String? brand,
    required String? category,
    required int offset,
    required int limit,
  }) async {
    final all = await _legacyAll();
    final tokens = searchTokens(query);
    final brandFilter = brand?.trim();
    final categoryFilter = category?.trim();
    var list = all.where((p) {
      if (lowStockOnly && !p.isLowStock) return false;
      if (brandFilter != null &&
          brandFilter.isNotEmpty &&
          (p.brand ?? '') != brandFilter) {
        return false;
      }
      if (categoryFilter != null &&
          categoryFilter.isNotEmpty &&
          (p.category ?? '') != categoryFilter) {
        return false;
      }
      if (tokens.isEmpty) return true;
      final hay = [
        p.name,
        p.barcode ?? '',
        p.note ?? '',
        p.brand ?? '',
        p.category ?? '',
        p.supplier ?? '',
      ].join(' ').toLowerCase();
      return tokens.every(hay.contains);
    }).toList();

    if (offset >= list.length) return PagedResult.empty<Product>();
    final end = (offset + limit).clamp(0, list.length);
    return PagedResult(
      items: list.sublist(offset, end),
      hasMore: end < list.length,
    );
  }

  Future<List<Product>> _legacyAll() async {
    final cached = _legacyCache;
    final at = _legacyCachedAt;
    if (cached != null &&
        at != null &&
        DateTime.now().difference(at) < const Duration(minutes: 5)) {
      return cached;
    }
    final rows = await _client.from('products').select(_columns).order('name');
    final list =
        List<Map<String, dynamic>>.from(rows as List).map(Product.fromMap).toList();
    _legacyCache = list;
    _legacyCachedAt = DateTime.now();
    return list;
  }

  bool get _taxonomyFresh {
    final at = _taxonomyCachedAt;
    return at != null &&
        DateTime.now().difference(at) < const Duration(minutes: 10);
  }

  /// Brand options for filters (النوع).
  Future<List<String>> getBrands() async {
    if (_brandsCache != null && _taxonomyFresh) return _brandsCache!;
    try {
      final rows = await _client
          .from('product_brands')
          .select('name')
          .order('name');
      final list = List<Map<String, dynamic>>.from(rows as List)
          .map((r) => (r['name'] as String?)?.trim() ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
      _brandsCache = list;
      _taxonomyCachedAt = DateTime.now();
      return list;
    } catch (e) {
      if (!isMissingRelation(e)) rethrow;
      // Fallback: distinct values already used on products
      final all = await _legacyAll();
      final set = <String>{};
      for (final p in all) {
        final b = p.brand?.trim();
        if (b != null && b.isNotEmpty) set.add(b);
      }
      final list = set.toList()..sort((a, b) => a.compareTo(b));
      _brandsCache = list;
      _taxonomyCachedAt = DateTime.now();
      return list;
    }
  }

  /// Category options for filters (الصنف).
  Future<List<String>> getCategories() async {
    if (_categoriesCache != null && _taxonomyFresh) return _categoriesCache!;
    try {
      final rows = await _client
          .from('product_categories')
          .select('name')
          .order('name');
      final list = List<Map<String, dynamic>>.from(rows as List)
          .map((r) => (r['name'] as String?)?.trim() ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
      _categoriesCache = list;
      _taxonomyCachedAt = DateTime.now();
      return list;
    } catch (e) {
      if (!isMissingRelation(e)) rethrow;
      final all = await _legacyAll();
      final set = <String>{};
      for (final p in all) {
        final c = p.category?.trim();
        if (c != null && c.isNotEmpty) set.add(c);
      }
      final list = set.toList()..sort((a, b) => a.compareTo(b));
      _categoriesCache = list;
      _taxonomyCachedAt = DateTime.now();
      return list;
    }
  }

  void invalidateCache() {
    _legacyCache = null;
    _legacyCachedAt = null;
    _brandsCache = null;
    _categoriesCache = null;
    _taxonomyCachedAt = null;
  }

  /// Small result set for the sales screen search box.
  Future<List<Product>> search(String query, {int limit = 25}) async {
    if (searchTokens(query).isEmpty) return const [];
    final page = await fetchPage(query: query, limit: limit);
    return page.items;
  }

  Future<Product?> getById(int id) async {
    final row =
        await _client.from('products').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return Product.fromMap(Map<String, dynamic>.from(row));
  }

  Future<Product> create(Product product) async {
    final row = await _client
        .from('products')
        .insert(product.toMap())
        .select()
        .single();
    invalidateCache();
    return Product.fromMap(Map<String, dynamic>.from(row));
  }

  Future<Product> update(Product product) async {
    if (product.id == null) throw Exception('Product id required');
    final row = await _client
        .from('products')
        .update(product.toMap())
        .eq('id', product.id!)
        .select()
        .single();
    invalidateCache();
    return Product.fromMap(Map<String, dynamic>.from(row));
  }

  /// Upload a local image file to Supabase Storage and save its public URL on the product.
  Future<Product> uploadProductImage({
    required int productId,
    required String filePath,
    String? mimeType,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('ملف الصورة غير موجود');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('ملف الصورة فارغ');
    }
    if (bytes.length > 5 * 1024 * 1024) {
      throw Exception('حجم الصورة كبير (الحد 5MB)');
    }

    final lower = filePath.toLowerCase();
    final ext = lower.endsWith('.png')
        ? 'png'
        : lower.endsWith('.webp')
            ? 'webp'
            : lower.endsWith('.gif')
                ? 'gif'
                : 'jpg';
    final contentType = mimeType ??
        (ext == 'png'
            ? 'image/png'
            : ext == 'webp'
                ? 'image/webp'
                : ext == 'gif'
                    ? 'image/gif'
                    : 'image/jpeg');

    final storagePath =
        'products/$productId/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _client.storage.from(_storageBucket).uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );

    final publicUrl =
        _client.storage.from(_storageBucket).getPublicUrl(storagePath);

    final row = await _client
        .from('products')
        .update({
          'image_url': publicUrl,
          'last_updated': DateTime.now().toIso8601String(),
        })
        .eq('id', productId)
        .select()
        .single();

    invalidateCache();
    return Product.fromMap(Map<String, dynamic>.from(row));
  }

  /// Clear product image URL (does not delete the storage object).
  Future<Product> clearProductImage(int productId) async {
    final row = await _client
        .from('products')
        .update({
          'image_url': null,
          'last_updated': DateTime.now().toIso8601String(),
        })
        .eq('id', productId)
        .select()
        .single();
    invalidateCache();
    return Product.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> delete(int id) async {
    // Block if used in sales
    final used = await _client
        .from('sales')
        .select('id')
        .eq('product_id', id)
        .limit(1);
    if ((used as List).isNotEmpty) {
      throw Exception('لا يمكن حذف المنتج لأنه مستخدم في المبيعات');
    }
    await _client.from('products').delete().eq('id', id);
    invalidateCache();
  }

  Future<void> adjustStock({
    required int productId,
    required String type, // stock_in | stock_out
    required int quantity,
    String? reason,
    int? userId,
  }) async {
    final product = await getById(productId);
    if (product == null) throw Exception('المنتج غير موجود');

    final delta = type == 'stock_out' ? -quantity : quantity;
    final newQty = product.quantity + delta;
    if (newQty < 0) throw Exception('الكمية غير كافية');

    await _client.from('products').update({
      'quantity': newQty,
      'last_updated': DateTime.now().toIso8601String(),
    }).eq('id', productId);

    await _client.from('inventory_adjustments').insert({
      'product_id': productId,
      'adjustment_type': type,
      'quantity': quantity,
      'reason': reason,
      'user_id': userId,
      'adjustment_date': DateTime.now().toIso8601String(),
    });
    invalidateCache();
  }
}
