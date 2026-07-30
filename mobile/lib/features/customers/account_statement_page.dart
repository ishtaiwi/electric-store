import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../data/customer_repository.dart';
import '../../data/models.dart';

class AccountStatementPage extends StatefulWidget {
  const AccountStatementPage({
    super.key,
    required this.repository,
    required this.customerId,
    required this.user,
  });

  final CustomerRepository repository;
  final int customerId;
  final AppUser user;

  @override
  State<AccountStatementPage> createState() => _AccountStatementPageState();
}

class _AccountStatementPageState extends State<AccountStatementPage> {
  CustomerLedger? _ledger;
  bool _loading = true;
  String? _error;
  bool _todayOnly = true;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, now.day);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ledger = await widget.repository.getLedger(
        widget.customerId,
        fromDate: _todayOnly ? _from : _from,
        toDate: _todayOnly ? _from : _to,
      );
      if (!mounted) return;
      setState(() => _ledger = ledger);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickFrom() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    setState(() {
      _from = d;
      _todayOnly = false;
    });
    _load();
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _to ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    setState(() {
      _to = d;
      _todayOnly = false;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final ledger = _ledger;
    return Scaffold(
      appBar: AppBar(
        title: Text(ledger?.customer.name ?? 'كشف الحساب'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ledger == null
                  ? const SizedBox.shrink()
                  : Column(
                      children: [
                        _SummaryCard(ledger: ledger),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              FilterChip(
                                label: const Text('اليوم'),
                                selected: _todayOnly,
                                onSelected: (v) {
                                  final now = DateTime.now();
                                  setState(() {
                                    _todayOnly = v;
                                    if (v) {
                                      _from = DateTime(
                                          now.year, now.month, now.day);
                                      _to = null;
                                    } else {
                                      _from = null;
                                      _to = null;
                                    }
                                  });
                                  _load();
                                },
                              ),
                              ActionChip(
                                avatar: const Icon(Icons.date_range, size: 18),
                                label: Text(_from == null
                                    ? 'من تاريخ'
                                    : 'من ${Formatters.date(_from!)}'),
                                onPressed: _pickFrom,
                              ),
                              ActionChip(
                                avatar: const Icon(Icons.event, size: 18),
                                label: Text(_to == null
                                    ? 'إلى تاريخ'
                                    : 'إلى ${Formatters.date(_to!)}'),
                                onPressed: _pickTo,
                              ),
                              ActionChip(
                                label: const Text('كل الفترة'),
                                onPressed: () {
                                  setState(() {
                                    _todayOnly = false;
                                    _from = null;
                                    _to = null;
                                  });
                                  _load();
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: ledger.entries.isEmpty
                              ? const Center(
                                  child: Text('لا حركات في الفترة المحددة'))
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(
                                      12, 0, 12, 24),
                                  itemCount: ledger.entries.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, i) {
                                    final e = ledger.entries[i];
                                    return _LedgerTile(entry: e);
                                  },
                                ),
                        ),
                      ],
                    ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.ledger});

  final CustomerLedger ledger;

  @override
  Widget build(BuildContext context) {
    final c = ledger.customer;
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    c.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                Text(c.code,
                    style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ),
            if (c.phone != null && c.phone!.isNotEmpty)
              Text(c.phone!,
                  style: const TextStyle(color: AppColors.textSecondary)),
            const Divider(height: 20),
            Row(
              children: [
                _Stat(
                    label: 'مدين',
                    value: Formatters.money(ledger.totalDebit),
                    color: AppColors.error),
                _Stat(
                    label: 'دائن',
                    value: Formatters.money(ledger.totalCredit),
                    color: AppColors.success),
                _Stat(
                  label: 'الرصيد',
                  value: Formatters.money(ledger.currentBalance),
                  color: ledger.currentBalance > 0
                      ? AppColors.error
                      : ledger.currentBalance < 0
                          ? AppColors.success
                          : AppColors.textPrimary,
                ),
              ],
            ),
            if (ledger.previousBalance != 0) ...[
              const SizedBox(height: 8),
              Text(
                'رصيد مرحّل: ${Formatters.money(ledger.previousBalance)}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color, fontSize: 13)),
        ],
      ),
    );
  }
}

class _LedgerTile extends StatelessWidget {
  const _LedgerTile({required this.entry});

  final LedgerEntry entry;

  Color get _badgeColor {
    switch (entry.documentType) {
      case LedgerDocType.salesInvoice:
        return AppColors.primary;
      case LedgerDocType.paymentReceipt:
        return AppColors.success;
      case LedgerDocType.accountDiscount:
        return AppColors.warning;
      case LedgerDocType.manualAdjustment:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: CircleAvatar(
          backgroundColor: _badgeColor,
          radius: 18,
          child: Text(
            entry.documentType == LedgerDocType.salesInvoice
                ? 'ف'
                : entry.documentType == LedgerDocType.paymentReceipt
                    ? 'ق'
                    : entry.documentType == LedgerDocType.accountDiscount
                        ? 'خ'
                        : 'ت',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        title: Text(
          '${entry.typeLabel} · ${entry.documentNumber}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          Formatters.date(entry.date) +
              (entry.notes != null && entry.notes!.isNotEmpty
                  ? ' · ${entry.notes}'
                  : ''),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (entry.debit > 0)
              Text('+${Formatters.money(entry.debit)}',
                  style: const TextStyle(
                      color: AppColors.error, fontWeight: FontWeight.bold)),
            if (entry.credit > 0)
              Text('-${Formatters.money(entry.credit)}',
                  style: const TextStyle(
                      color: AppColors.success, fontWeight: FontWeight.bold)),
            Text(
              Formatters.money(entry.runningBalance),
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
        children: [
          if (entry.lineItems.isEmpty)
            const Align(
              alignment: Alignment.centerRight,
              child: Text('لا تفاصيل إضافية',
                  style: TextStyle(color: AppColors.textSecondary)),
            )
          else
            ...entry.lineItems.map(
              (line) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(line.productName),
                subtitle: Text(
                    '${line.quantity} × ${Formatters.money(line.salePrice)}'),
                trailing: Text(Formatters.money(line.finalAmount)),
              ),
            ),
        ],
      ),
    );
  }
}
