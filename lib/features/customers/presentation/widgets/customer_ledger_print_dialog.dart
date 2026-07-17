import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/customer_ledger.dart';
import '../../domain/entities/customer_ledger_entry.dart';

/// Filter-based + optional manual selection for ledger PDF export.
class CustomerLedgerPrintDialog extends StatefulWidget {
  final CustomerLedger ledger;
  final bool isPrint;

  const CustomerLedgerPrintDialog({
    super.key,
    required this.ledger,
    required this.isPrint,
  });

  @override
  State<CustomerLedgerPrintDialog> createState() => _CustomerLedgerPrintDialogState();
}

class _CustomerLedgerPrintDialogState extends State<CustomerLedgerPrintDialog> {
  final _dateFormat = DateFormat('dd-MM-yyyy');
  final _searchController = TextEditingController();
  final _selected = <int>{};

  DateTime? _fromDate;
  DateTime? _toDate;
  LedgerDocumentType? _documentType;
  bool _showManualList = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _typeLabel(LedgerDocumentType type) {
    final loc = LocalizationService();
    switch (type) {
      case LedgerDocumentType.openingBalance:
        return loc.get('carriedForwardBalance');
      case LedgerDocumentType.salesInvoice:
        return loc.get('salesEntry');
      case LedgerDocumentType.paymentReceipt:
        return loc.get('receiptVoucher');
      case LedgerDocumentType.salesReturn:
        return loc.get('salesReturn');
      case LedgerDocumentType.manualAdjustment:
        return loc.get('manualAdjustment');
      case LedgerDocumentType.accountDiscount:
        return loc.get('ledgerDiscount');
    }
  }

  String get _searchQuery => _searchController.text.trim().toLowerCase();

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool _entryMatchesFilters(CustomerLedgerEntry entry) {
    final entryDay = _dateOnly(entry.date);
    if (_fromDate != null && entryDay.isBefore(_dateOnly(_fromDate!))) return false;
    if (_toDate != null && entryDay.isAfter(_dateOnly(_toDate!))) return false;
    if (_documentType != null && entry.documentType != _documentType) return false;
    if (_searchQuery.isNotEmpty) {
      final matchesDoc = entry.documentNumber.toLowerCase().contains(_searchQuery);
      final matchesInv = entry.invoiceNumber?.toLowerCase().contains(_searchQuery) ?? false;
      if (!matchesDoc && !matchesInv) return false;
    }
    return true;
  }

  List<int> get _filteredIndices {
    final indices = <int>[];
    for (var i = 0; i < widget.ledger.entries.length; i++) {
      if (_entryMatchesFilters(widget.ledger.entries[i])) {
        indices.add(i);
      }
    }
    return indices;
  }

  bool get _hasActiveFilters =>
      _fromDate != null ||
      _toDate != null ||
      _documentType != null ||
      _searchQuery.isNotEmpty;

  void _selectMatching() {
    setState(() {
      _selected
        ..clear()
        ..addAll(_filteredIndices);
    });
  }

  void _clearFilters() {
    setState(() {
      _fromDate = null;
      _toDate = null;
      _documentType = null;
      _searchController.clear();
      _selected.clear();
    });
  }

  void _applyThisMonth() {
    final now = DateTime.now();
    setState(() {
      _fromDate = DateTime(now.year, now.month, 1);
      _toDate = now;
      _selected.clear();
    });
  }

  void _applyLast30Days() {
    final now = DateTime.now();
    setState(() {
      _toDate = now;
      _fromDate = now.subtract(const Duration(days: 30));
      _selected.clear();
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? (_fromDate ?? DateTime.now()) : (_toDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _fromDate = picked;
      } else {
        _toDate = picked;
      }
      _selected.clear();
    });
  }

  List<int> _resolveExportIndices() {
    if (_selected.isNotEmpty) return _selected.toList()..sort();
    if (_hasActiveFilters) return _filteredIndices;
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final loc = LocalizationService();
    final title = widget.isPrint ? loc.get('selectEntriesToPrint') : loc.get('selectEntriesToExport');
    final filtered = _filteredIndices;
    final exportCount = _selected.isNotEmpty ? _selected.length : filtered.length;
    final canExportFiltered =
        exportCount > 0 && (_hasActiveFilters || _selected.isNotEmpty);
    final canExportAll = widget.ledger.entries.isNotEmpty;

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 580,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.primaryDark, AppColors.primary]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
              ),
              child: Row(
                children: [
                  Icon(widget.isPrint ? Icons.print : Icons.picture_as_pdf, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed: canExportAll ? () => Navigator.pop(context, <int>[]) : null,
                      icon: Icon(widget.isPrint ? Icons.print : Icons.picture_as_pdf),
                      label: Text(loc.get('exportFullStatement')),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      loc.get('orExportPartial'),
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.calendar_month, size: 16),
                          label: Text(loc.get('thisMonth')),
                          onPressed: _applyThisMonth,
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.date_range, size: 16),
                          label: Text(loc.get('last30Days')),
                          onPressed: _applyLast30Days,
                        ),
                        if (_hasActiveFilters)
                          ActionChip(
                            avatar: const Icon(Icons.filter_alt_off, size: 16),
                            label: Text(loc.get('clearFilters')),
                            onPressed: _clearFilters,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDate(isFrom: true),
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(
                              _fromDate != null
                                  ? '${loc.get('filterFromDate')}: ${_dateFormat.format(_fromDate!)}'
                                  : loc.get('filterFromDate'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDate(isFrom: false),
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(
                              _toDate != null
                                  ? '${loc.get('filterToDate')}: ${_dateFormat.format(_toDate!)}'
                                  : loc.get('filterToDate'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<LedgerDocumentType?>(
                      value: _documentType,
                      decoration: InputDecoration(
                        labelText: loc.get('documentType'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                      ),
                      items: [
                        DropdownMenuItem(value: null, child: Text(loc.get('allDocumentTypes'))),
                        DropdownMenuItem(
                          value: LedgerDocumentType.salesInvoice,
                          child: Text(loc.get('salesEntry')),
                        ),
                        DropdownMenuItem(
                          value: LedgerDocumentType.paymentReceipt,
                          child: Text(loc.get('receiptVoucher')),
                        ),
                        DropdownMenuItem(
                          value: LedgerDocumentType.accountDiscount,
                          child: Text(loc.get('ledgerDiscount')),
                        ),
                      ],
                      onChanged: (v) => setState(() {
                        _documentType = v;
                        _selected.clear();
                      }),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: loc.get('searchDocumentNumber'),
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() => _selected.clear()),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.get('matchingEntries').replaceAll('{count}', '${filtered.length}'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (_selected.isNotEmpty)
                            Text(
                              loc.get('selectedEntries').replaceAll('{count}', '${_selected.length}'),
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: filtered.isEmpty ? null : _selectMatching,
                          icon: const Icon(Icons.done_all, size: 18),
                          label: Text(loc.get('selectMatching')),
                        ),
                        if (_selected.isNotEmpty)
                          TextButton.icon(
                            onPressed: () => setState(() => _selected.clear()),
                            icon: const Icon(Icons.deselect, size: 18),
                            label: Text(loc.get('clearSelection')),
                          ),
                      ],
                    ),
                    InkWell(
                      onTap: () => setState(() => _showManualList = !_showManualList),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Icon(
                              _showManualList ? Icons.expand_less : Icons.expand_more,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              loc.get('manualSelection'),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            if (filtered.isNotEmpty)
                              Text(
                                '${filtered.length}',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (_showManualList) ...[
                      if (filtered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: Text(loc.get('noMatchingEntries'))),
                        )
                      else
                        ...filtered.map((index) {
                          final entry = widget.ledger.entries[index];
                          final amount = entry.debit > 0
                              ? loc.formatCurrency(entry.debit)
                              : loc.formatCurrency(entry.credit);
                          return CheckboxListTile(
                            value: _selected.contains(index),
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selected.add(index);
                                } else {
                                  _selected.remove(index);
                                }
                              });
                            },
                            title: Text(
                              '${_dateFormat.format(entry.date)} — ${_typeLabel(entry.documentType)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              '${entry.documentNumber} | $amount',
                              style: const TextStyle(fontSize: 11),
                            ),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          );
                        }),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(loc.get('cancel')),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: canExportFiltered
                        ? () => Navigator.pop(context, _resolveExportIndices())
                        : null,
                    icon: Icon(widget.isPrint ? Icons.print : Icons.picture_as_pdf),
                    label: Text(
                      widget.isPrint
                          ? '${loc.get('exportMatching')} ($exportCount)'
                          : '${loc.get('exportMatching')} ($exportCount)',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
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
}
