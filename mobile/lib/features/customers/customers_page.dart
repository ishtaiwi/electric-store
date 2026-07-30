import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../core/widgets/list_skeleton.dart';
import '../../data/customer_repository.dart';
import '../../data/models.dart';
import 'account_statement_page.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({
    super.key,
    required this.repository,
    required this.user,
  });

  final CustomerRepository repository;
  final AppUser user;

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage>
    with AutomaticKeepAliveClientMixin {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  final _scrollCtrl = ScrollController();
  Timer? _debounce;

  final List<Customer> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _debtOnly = false;
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
        debtOnly: _debtOnly,
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
        debtOnly: _debtOnly,
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

  Future<void> _openStatement(Customer c) async {
    if (c.id == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AccountStatementPage(
          repository: widget.repository,
          customerId: c.id!,
          user: widget.user,
        ),
      ),
    );
    if (mounted) _refresh();
  }

  Color _balanceColor(Customer c) {
    if (c.hasDebt) return AppColors.error;
    if (c.hasCredit) return AppColors.success;
    return AppColors.textSecondary;
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
                hintText: 'بحث بالاسم أو الهاتف...',
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
                  label: const Text('مدينون فقط'),
                  selected: _debtOnly,
                  onSelected: (v) {
                    setState(() => _debtOnly = v);
                    _loadFirstPage();
                  },
                ),
                const Spacer(),
                Text(
                  '${_items.length}${_hasMore ? '+' : ''} عميل',
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
              : 'لا يوجد عملاء',
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
          final c = _items[i];
          return _CustomerTile(
            customer: c,
            balanceColor: _balanceColor(c),
            onTap: () => _openStatement(c),
          );
        },
      ),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({
    required this.customer,
    required this.balanceColor,
    required this.onTap,
  });

  final Customer customer;
  final Color balanceColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = customer;
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary,
          child: Text(
            c.name.isNotEmpty ? c.name.characters.first : '?',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          c.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          [
            if (c.phone != null && c.phone!.isNotEmpty) c.phone!,
            c.code,
          ].join(' · '),
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              Formatters.money(c.balance),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: balanceColor,
              ),
            ),
            const Text(
              'كشف حساب',
              style: TextStyle(fontSize: 11, color: AppColors.primary),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
