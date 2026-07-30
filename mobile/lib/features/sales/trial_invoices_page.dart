import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../data/models.dart';
import '../../data/sales_repository.dart';

class TrialInvoicesPage extends StatefulWidget {
  const TrialInvoicesPage({super.key, required this.sales});

  final SalesRepository sales;

  @override
  State<TrialInvoicesPage> createState() => _TrialInvoicesPageState();
}

class _TrialInvoicesPageState extends State<TrialInvoicesPage> {
  List<CreatedInvoice> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.sales.listTrialInvoices();
      if (!mounted) return;
      setState(() => _items = list);
    } catch (e) {
      if (mounted) {
        setState(
            () => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _confirmDelete({
    required String title,
    required String message,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _deleteOne(CreatedInvoice inv) async {
    final ok = await _confirmDelete(
      title: 'حذف الفاتورة',
      message: 'هل تريد حذف الفاتورة التجريبية؟\n${inv.invoiceNumber}',
    );
    if (!ok) return;
    try {
      await widget.sales.deleteTrialInvoice(inv.id);
      if (!mounted) return;
      setState(() => _items = _items.where((e) => e.id != inv.id).toList());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف الفاتورة'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _deleteAll() async {
    if (_items.isEmpty) return;
    final ok = await _confirmDelete(
      title: 'حذف الكل',
      message: 'هل تريد حذف جميع الفواتير التجريبية (${_items.length})؟',
    );
    if (!ok) return;
    try {
      await widget.sales.deleteAllTrialInvoices();
      if (!mounted) return;
      setState(() => _items = []);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف جميع الفواتير التجريبية'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _openDetails(CreatedInvoice inv) async {
    final deleted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      builder: (_) => _TrialInvoiceDetailsSheet(
        sales: widget.sales,
        invoice: inv,
      ),
    );
    if (deleted == true && mounted) {
      setState(() => _items = _items.where((e) => e.id != inv.id).toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الفواتير التجريبية'),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              tooltip: 'حذف الكل',
              onPressed: _deleteAll,
              icon: const Icon(Icons.delete_sweep),
            ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                )
              : _items.isEmpty
                  ? const Center(
                      child: Text(
                        'لا توجد فواتير تجريبية محفوظة بعد',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final inv = _items[i];
                          return Dismissible(
                            key: ValueKey('trial-${inv.id}'),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (_) => _confirmDelete(
                              title: 'حذف الفاتورة',
                              message:
                                  'هل تريد حذف الفاتورة التجريبية؟\n${inv.invoiceNumber}',
                            ),
                            onDismissed: (_) async {
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                await widget.sales.deleteTrialInvoice(inv.id);
                                if (!mounted) return;
                                setState(() => _items =
                                    _items.where((e) => e.id != inv.id).toList());
                              } catch (e) {
                                if (!mounted) return;
                                _load();
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(e
                                        .toString()
                                        .replaceFirst('Exception: ', '')),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            },
                            background: Container(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.delete,
                                  color: Colors.white),
                            ),
                            child: Card(
                              child: ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: AppColors.primary,
                                  child: Icon(Icons.receipt_long,
                                      color: Colors.white, size: 20),
                                ),
                                title: Text(
                                  inv.invoiceNumber,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                ),
                                subtitle: Text(
                                  [
                                    if (inv.saleDate != null)
                                      Formatters.dateTime(inv.saleDate!),
                                    if (inv.customerName != null &&
                                        inv.customerName!.isNotEmpty)
                                      inv.customerName!,
                                  ].join(' · '),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      Formatters.money(inv.finalAmount),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'حذف',
                                      icon: const Icon(Icons.delete_outline,
                                          color: AppColors.error),
                                      onPressed: () => _deleteOne(inv),
                                    ),
                                  ],
                                ),
                                onTap: () => _openDetails(inv),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _TrialInvoiceDetailsSheet extends StatefulWidget {
  const _TrialInvoiceDetailsSheet({
    required this.sales,
    required this.invoice,
  });

  final SalesRepository sales;
  final CreatedInvoice invoice;

  @override
  State<_TrialInvoiceDetailsSheet> createState() =>
      _TrialInvoiceDetailsSheetState();
}

class _TrialInvoiceDetailsSheetState extends State<_TrialInvoiceDetailsSheet> {
  List<SaleLine> _lines = [];
  bool _loading = true;
  bool _deleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final lines =
          await widget.sales.getTrialInvoiceLines(widget.invoice.id);
      if (!mounted) return;
      setState(() {
        _lines = lines;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الفاتورة'),
        content: Text(
            'هل تريد حذف الفاتورة التجريبية؟\n${widget.invoice.invoiceNumber}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await widget.sales.deleteTrialInvoice(widget.invoice.id);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.invoice;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;

    return SafeArea(
      maintainBottomViewPadding: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'تفاصيل الفاتورة',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(inv.invoiceNumber,
                  style: const TextStyle(color: AppColors.textSecondary)),
              if (inv.saleDate != null)
                Text(Formatters.dateTime(inv.saleDate!),
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              Text(
                'الإجمالي: ${Formatters.money(inv.finalAmount)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppColors.primary),
              ),
              if (inv.discountAmount > 0)
                Text('الخصم: ${Formatters.money(inv.discountAmount)}'),
              const Divider(height: 24),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Text(_error!,
                            style: const TextStyle(color: AppColors.error))
                        : _lines.isEmpty
                            ? const Text('لا توجد أصناف')
                            : ListView.separated(
                                itemCount: _lines.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 6),
                                itemBuilder: (context, i) {
                                  final line = _lines[i];
                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(line.productName),
                                    subtitle: Text(
                                      '${line.quantity} × ${Formatters.money(line.salePrice)}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    trailing: Text(
                                      Formatters.money(line.finalAmount),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                  );
                                },
                              ),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _deleting ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                      child: const Text('إغلاق'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _deleting ? null : _delete,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(44),
                      ),
                      icon: _deleting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.delete_outline),
                      label: const Text('حذف'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
