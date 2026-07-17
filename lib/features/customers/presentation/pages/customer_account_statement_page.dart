import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/localization_service.dart';
import '../../../../core/services/pdf_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../invoices/domain/entities/sale_item.dart';
import '../../../sales/domain/repositories/sales_repository.dart';
import '../../../invoices/domain/repositories/invoice_repository.dart';
import '../../../invoices/presentation/bloc/invoice_bloc.dart';
import '../../../invoices/presentation/widgets/edit_invoice_dialog.dart';
import '../../../products/presentation/bloc/product_bloc.dart';
import '../../../settings/domain/repositories/settings_repository.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/customer_ledger.dart';
import '../../domain/entities/customer_ledger_entry.dart';
import '../../domain/entities/customer_ledger_filters.dart';
import '../../domain/repositories/customer_repository.dart';
import '../bloc/customer_bloc.dart';
import '../widgets/customer_edit_payment_dialog.dart';
import '../widgets/customer_ledger_sales_panel.dart';
import '../widgets/customer_ledger_discount_dialog.dart';
import '../widgets/customer_ledger_notes_dialog.dart';
import '../widgets/customer_ledger_print_dialog.dart';
import '../widgets/customer_record_payment_dialog.dart';

class CustomerAccountStatementPage extends StatefulWidget {
  final Customer customer;

  const CustomerAccountStatementPage({super.key, required this.customer});

  @override
  State<CustomerAccountStatementPage> createState() =>
      _CustomerAccountStatementPageState();
}

class _CustomerAccountStatementPageState
    extends State<CustomerAccountStatementPage> {
  static const _ledgerColumnWidths = <int, TableColumnWidth>{
    0: FixedColumnWidth(44),
    1: FlexColumnWidth(1),
    2: FlexColumnWidth(1.3),
    3: FlexColumnWidth(1.1),
    4: FlexColumnWidth(1.1),
    5: FlexColumnWidth(1.1),
    6: FlexColumnWidth(1.2),
    7: FlexColumnWidth(2.8),
    8: FixedColumnWidth(48),
  };

  final _localization = LocalizationService();
  final _dateFormat = DateFormat('dd-MM-yyyy');
  final _invoiceSearchController = TextEditingController();
  final _receiptSearchController = TextEditingController();
  final _ledgerScrollController = ScrollController();
  final _horizontalHeaderScrollController = ScrollController();
  final _horizontalBodyScrollController = ScrollController();

  CustomerLedger? _ledger;
  bool _isLoading = true;
  bool _salesPanelExpanded = false;
  late CustomerLedgerFilters _filters;
  bool _syncingHorizontalScroll = false;

  static DateTime _startOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static CustomerLedgerFilters _defaultFilters() =>
      CustomerLedgerFilters(fromDate: _startOfToday());

  @override
  void initState() {
    super.initState();
    _filters = _defaultFilters();
    _horizontalBodyScrollController.addListener(_syncHeaderHorizontalScroll);
    _loadLedger();
  }

  void _syncHeaderHorizontalScroll() {
    if (_syncingHorizontalScroll || !_horizontalHeaderScrollController.hasClients) return;
    _syncingHorizontalScroll = true;
    _horizontalHeaderScrollController.jumpTo(_horizontalBodyScrollController.offset);
    _syncingHorizontalScroll = false;
  }

  @override
  void dispose() {
    _horizontalBodyScrollController.removeListener(_syncHeaderHorizontalScroll);
    _invoiceSearchController.dispose();
    _receiptSearchController.dispose();
    _ledgerScrollController.dispose();
    _horizontalHeaderScrollController.dispose();
    _horizontalBodyScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLedger() async {
    setState(() => _isLoading = true);
    try {
      final ledger = await di.sl<CustomerRepository>().getCustomerLedger(
            widget.customer.id!,
            filters: _filters,
          );
      if (mounted) {
        setState(() {
          _ledger = ledger;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_localization.get('error')}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filters = _filters.copyWith(
        invoiceNumber: _invoiceSearchController.text.trim().isEmpty
            ? null
            : _invoiceSearchController.text.trim(),
        receiptNumber: _receiptSearchController.text.trim().isEmpty
            ? null
            : _receiptSearchController.text.trim(),
        clearInvoiceNumber: _invoiceSearchController.text.trim().isEmpty,
        clearReceiptNumber: _receiptSearchController.text.trim().isEmpty,
      );
    });
    _loadLedger();
  }

  void _clearFilters() {
    _invoiceSearchController.clear();
    _receiptSearchController.clear();
    setState(() => _filters = _defaultFilters());
    _loadLedger();
  }

  bool get _isShowingFullLedger =>
      _filters.fromDate == null && _filters.toDate == null;

  void _showFullLedger() {
    setState(() {
      _filters = _filters.copyWith(clearFromDate: true, clearToDate: true);
    });
    _loadLedger();
  }

  void _showTodayLedger() {
    _invoiceSearchController.clear();
    _receiptSearchController.clear();
    setState(() => _filters = _defaultFilters());
    _loadLedger();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _filters.fromDate : _filters.toDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _filters = isFrom
            ? _filters.copyWith(fromDate: picked)
            : _filters.copyWith(toDate: picked);
      });
      _loadLedger();
    }
  }

  void _onDocumentTypeChanged(LedgerDocumentType? type) {
    setState(() {
      _filters = type == null
          ? _filters.copyWith(clearDocumentType: true)
          : _filters.copyWith(documentType: type);
    });
    _loadLedger();
  }

  String _documentTypeLabel(LedgerDocumentType type) {
    switch (type) {
      case LedgerDocumentType.openingBalance:
        return _localization.get('carriedForwardBalance');
      case LedgerDocumentType.salesInvoice:
        return _localization.get('salesEntry');
      case LedgerDocumentType.paymentReceipt:
        return _localization.get('receiptVoucher');
      case LedgerDocumentType.salesReturn:
        return _localization.get('salesReturn');
      case LedgerDocumentType.manualAdjustment:
        return _localization.get('manualAdjustment');
      case LedgerDocumentType.accountDiscount:
        return _localization.get('ledgerDiscount');
    }
  }

  void _toggleSalesPanel() {
    setState(() => _salesPanelExpanded = !_salesPanelExpanded);
  }

  void _onLedgerSaleSaved() {
    di.sl<InvoiceBloc>().add(InvoiceRefresh());
    context.read<CustomerBloc>().add(CustomerRefresh());
    di.sl<ProductBloc>().add(ProductRefresh());
    setState(() => _salesPanelExpanded = false);
    _loadLedger();
  }

  Future<({List<CustomerLedgerEntry> entries, CustomerLedger ledger})?> _pickEntriesForOutput(
    bool isPrint,
  ) async {
    if (_ledger == null || widget.customer.id == null) return null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    CustomerLedger fullLedger;
    try {
      fullLedger = await di.sl<CustomerRepository>().getCustomerLedger(
            widget.customer.id!,
            filters: const CustomerLedgerFilters(),
          );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_localization.get('error')}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return null;
    }

    if (!mounted) return null;
    Navigator.pop(context);

    final indices = await showDialog<List<int>>(
      context: context,
      builder: (_) => CustomerLedgerPrintDialog(ledger: fullLedger, isPrint: isPrint),
    );
    if (indices == null) return null;

    if (indices.isEmpty) {
      return (entries: fullLedger.entries, ledger: fullLedger);
    }

    return (
      entries: indices.map((i) => fullLedger.entries[i]).toList(),
      ledger: fullLedger,
    );
  }

  Future<void> _exportPdf() async {
    if (_ledger == null) return;
    final output = await _pickEntriesForOutput(false);
    if (output == null || !mounted) return;

    final selectedEntries = output.entries;
    final ledgerForPdf = output.ledger;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final settings = await di.sl<SettingsRepository>().getSettings();
      final isPartial = selectedEntries.length < ledgerForPdf.entries.length;
      final path = await di.sl<PdfService>().saveCustomerLedgerPdf(
            ledger: ledgerForPdf,
            storeSettings: settings,
            entriesOverride: isPartial ? selectedEntries : null,
            isPartialSelection: isPartial,
          );
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_localization.get('pdfSavedTo')}: $path'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_localization.get('error')}: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _editInvoice(int invoiceId) async {
    final invoiceRepo = di.sl<InvoiceRepository>();
    final invoice = await invoiceRepo.getInvoiceById(invoiceId);
    if (invoice == null || !mounted) return;
    final items = invoice.items ?? await invoiceRepo.getInvoiceItems(invoiceId);

    await showDialog(
      context: context,
      builder: (dialogContext) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: di.sl<InvoiceBloc>()),
          BlocProvider.value(value: di.sl<ProductBloc>()),
          BlocProvider.value(value: di.sl<CustomerBloc>()),
        ],
        child: EditInvoiceDialog(invoice: invoice, items: items),
      ),
    );

    di.sl<InvoiceBloc>().add(InvoiceRefresh());
    context.read<CustomerBloc>().add(CustomerRefresh());
    _loadLedger();
  }

  Future<void> _recordCustomerPayment() async {
    if (_ledger == null || widget.customer.id == null) return;

    final anchorId = await di.sl<CustomerRepository>().getOrCreateAccountAnchorInvoice(
          widget.customer.id!,
          customerName: widget.customer.name,
        );
    final anchor = await di.sl<InvoiceRepository>().getInvoiceById(anchorId);
    if (anchor == null || !mounted) return;

    final outstanding = _ledger!.finalBalance > 0 ? _ledger!.finalBalance : widget.customer.balance;

    await showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<CustomerBloc>(),
        child: CustomerRecordPaymentDialog(
          invoice: anchor,
          customerId: widget.customer.id!,
          accountOutstanding: outstanding,
        ),
      ),
    );
    di.sl<InvoiceBloc>().add(InvoiceRefresh());
    _loadLedger();
  }

  Future<void> _confirmDeleteSaleLine(SaleItem item) async {
    if (item.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_localization.get('delete')),
        content: Text(_localization.get('deleteLineItemConfirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_localization.get('cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(_localization.get('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await di.sl<SalesRepository>().deleteAccountSaleLine(item.id!);
    di.sl<InvoiceBloc>().add(InvoiceRefresh());
    context.read<CustomerBloc>().add(CustomerRefresh());
    di.sl<ProductBloc>().add(ProductRefresh());
    _loadLedger();
  }

  Future<void> _applyInvoiceDiscount(CustomerLedgerEntry entry) async {
    if (!entry.isSalesInvoice || entry.invoiceId == null) return;
    final invoice = await di.sl<InvoiceRepository>().getInvoiceById(entry.invoiceId!);
    if (invoice == null || !mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => CustomerLedgerDiscountDialog(
        mode: LedgerDiscountMode.invoice,
        title: entry.documentNumber,
        subtitle: _dateFormat.format(entry.date),
        referenceAmount: invoice.totalAmount,
        currentDiscount: invoice.discountAmount,
      ),
    );
    if (result == null || !mounted) return;

    try {
      await di.sl<InvoiceRepository>().updateInvoiceDiscount(
            entry.invoiceId!,
            result['amount'] as double,
          );
      if ((result['notes'] as String?)?.isNotEmpty == true) {
        await di.sl<InvoiceRepository>().updateInvoiceNotes(
              entry.invoiceId!,
              result['notes'] as String,
            );
      }
      di.sl<InvoiceBloc>().add(InvoiceRefresh());
      context.read<CustomerBloc>().add(CustomerRefresh());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_localization.get('discountApplied')), backgroundColor: AppColors.success),
        );
        _loadLedger();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_localization.get('error')}: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _applyAccountDiscount() async {
    if (_ledger == null) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => CustomerLedgerDiscountDialog(
        mode: LedgerDiscountMode.account,
        title: widget.customer.name,
        subtitle: _localization.get('accountDiscount'),
        referenceAmount: _ledger!.currentBalance,
      ),
    );
    if (result == null || !mounted) return;

    try {
      await di.sl<CustomerRepository>().recordAccountDiscount(
            customerId: widget.customer.id!,
            amount: result['amount'] as double,
            notes: (result['notes'] as String?)?.isNotEmpty == true ? result['notes'] as String : null,
          );
      di.sl<InvoiceBloc>().add(InvoiceRefresh());
      context.read<CustomerBloc>().add(CustomerRefresh());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_localization.get('discountApplied')), backgroundColor: AppColors.success),
        );
        _loadLedger();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_localization.get('error')}: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _editEntryNotes(CustomerLedgerEntry entry) async {
    if (entry.isOpeningBalance) return;
    if (!entry.isSalesInvoice && !entry.isPayment && !entry.isDiscount) return;

    final result = await showDialog<String>(
      context: context,
      builder: (_) => CustomerLedgerNotesDialog(
        documentNumber: entry.documentNumber,
        documentTypeLabel: _documentTypeLabel(entry.documentType),
        initialNotes: entry.notes,
      ),
    );
    if (result == null || !mounted) return;

    final notes = result.isEmpty ? null : result;

    try {
      if (entry.isSalesInvoice && entry.invoiceId != null) {
        await di.sl<InvoiceRepository>().updateInvoiceNotes(entry.invoiceId!, notes);
        di.sl<InvoiceBloc>().add(InvoiceUpdateNotes(invoiceId: entry.invoiceId!, notes: notes));
      } else if (entry.isPayment || entry.isDiscount) {
        final payments = await di.sl<CustomerRepository>().getPaymentsByCustomer(widget.customer.id!);
        final payment = payments.firstWhere((p) => p.id == entry.paymentId);
        await di.sl<CustomerRepository>().updatePayment(payment.copyWith(notes: notes));
        if (mounted) context.read<CustomerBloc>().add(CustomerRefresh());
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_localization.get('notesSaved')),
            backgroundColor: AppColors.success,
          ),
        );
        _loadLedger();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_localization.get('error')}: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _editSaleItemNotes(SaleItem item) async {
    if (item.id == null) return;

    final result = await showDialog<String>(
      context: context,
      builder: (_) => CustomerLedgerNotesDialog(
        documentNumber: item.productName,
        documentTypeLabel: _localization.get('productName'),
        initialNotes: item.note,
      ),
    );
    if (result == null || !mounted) return;

    final note = result.isEmpty ? null : result;

    try {
      await di.sl<InvoiceRepository>().updateSaleItemNote(item.id!, note);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_localization.get('notesSaved')),
            backgroundColor: AppColors.success,
          ),
        );
        _loadLedger();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_localization.get('error')}: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _editPayment(CustomerLedgerEntry entry) async {
    if (entry.paymentId == null || entry.invoiceId == null) return;
    final invoiceRepo = di.sl<InvoiceRepository>();
    final invoice = await invoiceRepo.getInvoiceById(entry.invoiceId!);
    if (invoice == null || !mounted) return;

    final allPayments = await di.sl<CustomerRepository>().getPaymentsByInvoice(entry.invoiceId!);
    final otherTotal = allPayments
        .where((p) => p.id != entry.paymentId)
        .fold<double>(0, (s, p) => s + p.amount);

    final payment = allPayments.firstWhere((p) => p.id == entry.paymentId);

    final updated = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<CustomerBloc>(),
        child: CustomerEditPaymentDialog(
          payment: payment,
          invoiceFinalAmount: invoice.finalAmount,
          otherPaymentsTotal: otherTotal,
        ),
      ),
    );

    if (updated == true) {
      di.sl<InvoiceBloc>().add(InvoiceRefresh());
      _loadLedger();
    }
  }

  void _confirmDeleteInvoice(int invoiceId, String invoiceNumber) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_localization.get('deleteInvoice')),
        content: Text('${_localization.get('confirmDeleteInvoice')} #$invoiceNumber?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_localization.get('cancel'))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await di.sl<InvoiceRepository>().deleteInvoice(invoiceId);
              di.sl<InvoiceBloc>().add(InvoiceRefresh());
              context.read<CustomerBloc>().add(CustomerRefresh());
              _loadLedger();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(_localization.get('delete')),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePayment(int paymentId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_localization.get('confirmDelete')),
        content: Text(_localization.get('deletePaymentConfirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_localization.get('cancel'))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<CustomerBloc>().add(CustomerDeletePayment(
                    paymentId: paymentId,
                    customerId: widget.customer.id!,
                  ));
              di.sl<InvoiceBloc>().add(InvoiceRefresh());
              _loadLedger();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(_localization.get('delete')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_localization.get('customerAccountLedger')),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _ledger == null ? null : _applyAccountDiscount,
            icon: const Icon(Icons.discount),
            tooltip: _localization.get('accountDiscount'),
          ),
          IconButton(
            onPressed: _recordCustomerPayment,
            icon: const Icon(Icons.payments),
            tooltip: _localization.get('recordPayment'),
          ),
          IconButton(
            onPressed: _exportPdf,
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: _localization.get('exportPdf'),
          ),
          IconButton(
            onPressed: _loadLedger,
            icon: const Icon(Icons.refresh),
            tooltip: _localization.get('refresh'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _ledger == null
              ? Center(child: Text(_localization.get('error')))
              : Column(
                  children: [
                    _buildHeader(_ledger!),
                    if (_salesPanelExpanded)
                      Expanded(
                        child: CustomerLedgerSalesPanel(
                          customer: widget.customer,
                          onSaved: _onLedgerSaleSaved,
                        ),
                      )
                    else ...[
                      _buildFilters(),
                      Expanded(child: _buildLedgerTable(_ledger!)),
                    ],
                    _buildFooter(_ledger!),
                  ],
                ),
    );
  }

  Widget _buildHeader(CustomerLedger ledger) {
    final balanceColor = ledger.currentBalance > 0
        ? AppColors.error
        : ledger.currentBalance < 0
            ? AppColors.info
            : AppColors.success;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary,
                child: Text(
                  ledger.customer.name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ledger.customer.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_localization.get('customerCode')}: ${ledger.customerCode}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    if (ledger.customer.phone != null)
                      Text(
                        '${_localization.get('phone')}: ${ledger.customer.phone}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    if (ledger.customer.address != null)
                      Text(
                        '${_localization.get('address')}: ${ledger.customer.address}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: balanceColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: balanceColor),
                ),
                child: Column(
                  children: [
                    Text(
                      _localization.get('currentBalance'),
                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                    ),
                    Text(
                      _localization.formatCurrency(ledger.currentBalance.abs()),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: balanceColor),
                    ),
                    Text(
                      ledger.isDebtor
                          ? _localization.get('customerOwesYou')
                          : ledger.isCreditor
                              ? _localization.get('youOweCustomer')
                              : _localization.get('customerSettled'),
                      style: TextStyle(fontSize: 10, color: balanceColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statChip(_localization.get('totalSales'), ledger.totalSales),
              _statChip(_localization.get('totalPaid'), ledger.totalPayments),
              _statChip(_localization.get('totalOutstandingBalance'), ledger.totalOutstanding,
                  highlight: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, double value, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlight ? AppColors.error.withOpacity(0.08) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: highlight ? AppColors.error.withOpacity(0.3) : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          Text(
            _localization.formatCurrency(value),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: highlight && value > 0 ? AppColors.error : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: _isShowingFullLedger ? _showTodayLedger : _showFullLedger,
            icon: Icon(_isShowingFullLedger ? Icons.today : Icons.view_list, size: 18),
            label: Text(
              _localization.get(_isShowingFullLedger ? 'showTodayLedger' : 'showFullLedger'),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isShowingFullLedger ? AppColors.primary : AppColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _pickDate(isFrom: true),
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(_filters.fromDate != null
                ? '${_localization.get('filterFromDate')}: ${_dateFormat.format(_filters.fromDate!)}'
                : _localization.get('filterFromDate')),
          ),
          OutlinedButton.icon(
            onPressed: () => _pickDate(isFrom: false),
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(_filters.toDate != null
                ? '${_localization.get('filterToDate')}: ${_dateFormat.format(_filters.toDate!)}'
                : _localization.get('filterToDate')),
          ),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<LedgerDocumentType?>(
              value: _filters.documentType,
              decoration: InputDecoration(
                labelText: _localization.get('documentType'),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                DropdownMenuItem(value: null, child: Text(_localization.get('allDocumentTypes'))),
                DropdownMenuItem(
                  value: LedgerDocumentType.salesInvoice,
                  child: Text(_documentTypeLabel(LedgerDocumentType.salesInvoice)),
                ),
                DropdownMenuItem(
                  value: LedgerDocumentType.paymentReceipt,
                  child: Text(_documentTypeLabel(LedgerDocumentType.paymentReceipt)),
                ),
              ],
              onChanged: _onDocumentTypeChanged,
            ),
          ),
          SizedBox(
            width: 160,
            child: TextField(
              controller: _invoiceSearchController,
              decoration: InputDecoration(
                labelText: _localization.get('invoiceNumber'),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onSubmitted: (_) => _applyFilters(),
            ),
          ),
          SizedBox(
            width: 160,
            child: TextField(
              controller: _receiptSearchController,
              decoration: InputDecoration(
                labelText: _localization.get('receiptNumber'),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onSubmitted: (_) => _applyFilters(),
            ),
          ),
          ElevatedButton(onPressed: _applyFilters, child: Text(_localization.get('search'))),
          if (_filters.hasActiveFilters)
            TextButton(onPressed: _clearFilters, child: Text(_localization.get('clearFilters'))),
        ],
      ),
    );
  }

  Widget _buildLedgerTable(CustomerLedger ledger) {
    if (ledger.entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance, size: 64, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text(_localization.get('noTransactions'), style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                if (!_salesPanelExpanded) _toggleSalesPanel();
              },
              icon: const Icon(Icons.add),
              label: Text(_localization.get('registerCustomerGoods')),
            ),
          ],
        ),
      );
    }

    final border = TableBorder.all(color: Colors.grey.shade400, width: 0.8);
    final headerBg = AppColors.primaryDark.withOpacity(0.12);
    final subHeaderBg = Colors.grey.shade100;
    final headerBorder = TableBorder(
      top: border.top,
      left: border.left,
      right: border.right,
      bottom: border.horizontalInside,
      verticalInside: border.verticalInside,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tableWidth = math.max(constraints.maxWidth, 900.0);

          return Column(
            children: [
              Material(
                elevation: 2,
                color: headerBg,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: _horizontalHeaderScrollController,
                  physics: const NeverScrollableScrollPhysics(),
                  child: SizedBox(
                    width: tableWidth,
                    child: Table(
                      border: headerBorder,
                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                      columnWidths: _ledgerColumnWidths,
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: headerBg),
                          children: [
                            _th('#'),
                            _th(_localization.get('voucherDate')),
                            _th(_localization.get('voucherNumber')),
                            _th(_localization.get('voucherType')),
                            _th(_localization.get('debit')),
                            _th(_localization.get('creditEntry')),
                            _th(_localization.get('runningBalance')),
                            _th(_localization.get('notes')),
                            _th(''),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Scrollbar(
                  controller: _ledgerScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _ledgerScrollController,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      controller: _horizontalBodyScrollController,
                      child: SizedBox(
                        width: tableWidth,
                        child: Table(
                          border: border,
                          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                          columnWidths: _ledgerColumnWidths,
                          children: [
                            ..._buildLedgerDataRows(ledger, subHeaderBg),
                            TableRow(
                              decoration: BoxDecoration(color: headerBg),
                              children: [
                                _td(''),
                                _td(''),
                                _td(''),
                                _td(_localization.get('total'), bold: true),
                                _td(_localization.formatCurrency(ledger.totalDebit), bold: true, color: AppColors.error),
                                _td(_localization.formatCurrency(ledger.totalCredit), bold: true, color: AppColors.success),
                                _td(_localization.formatCurrency(ledger.finalBalance), bold: true),
                                _td(''),
                                _td(''),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<TableRow> _buildLedgerDataRows(CustomerLedger ledger, Color subHeaderBg) {
    final rows = <TableRow>[];
    var rowNum = 0;

    for (final entry in ledger.entries) {
      if (entry.isOpeningBalance) {
        rows.add(_mainRow(
          rowNum: ++rowNum,
          entry: entry,
          ledger: ledger,
          alt: rowNum.isEven,
        ));
        continue;
      }

      rows.add(_mainRow(
        rowNum: ++rowNum,
        entry: entry,
        ledger: ledger,
        alt: rowNum.isEven,
      ));

      if (entry.showLineItems) {
        final items = entry.lineItems ?? ledger.invoiceItems[entry.invoiceId] ?? [];
        if (items.isNotEmpty) {
          rows.add(TableRow(
            decoration: BoxDecoration(color: subHeaderBg),
            children: [
              _td(''),
              _td(_localization.get('itemSku'), bold: true, fontSize: 13),
              _td(_localization.get('quantity'), bold: true, fontSize: 13),
              _td(_localization.get('unit'), bold: true, fontSize: 13),
              _td(_localization.get('itemPrice'), bold: true, fontSize: 13),
              _td(_localization.get('itemAmount'), bold: true, fontSize: 13),
              _td(_localization.get('productName'), bold: true, fontSize: 13),
              _td(_localization.get('notes'), bold: true, fontSize: 13),
              _td(''),
            ],
          ));
          for (final item in items) {
            rows.add(TableRow(
              decoration: BoxDecoration(color: Colors.white),
              children: [
                _td(''),
                _td(item.barcode ?? '-', fontSize: 13),
                _td(item.quantity.toStringAsFixed(2), fontSize: 13),
                _td(_localization.get('pcs'), fontSize: 13),
                _td(_localization.formatCurrency(item.salePrice), fontSize: 13),
                _td(_localization.formatCurrency(item.totalAmount), fontSize: 13),
                _td(item.productName, fontSize: 13),
                _tdWidget(_itemNotesCell(item)),
                _tdWidget(
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: _localization.get('delete'),
                    onPressed: () => _confirmDeleteSaleLine(item),
                  ),
                ),
              ],
            ));
          }
          final invoiceTotal = items.fold<double>(0, (s, i) => s + i.totalAmount);
          rows.add(TableRow(
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.06)),
            children: [
              _td(''),
              _td(''),
              _td(''),
              _td(''),
              _td(_localization.get('invoiceSubtotal'), bold: true, fontSize: 13),
              _td(_localization.formatCurrency(invoiceTotal), bold: true, fontSize: 13),
              _td(''),
              _td(''),
              _td(''),
            ],
          ));
        }
      }
    }
    return rows;
  }

  TableRow _mainRow({
    required int rowNum,
    required CustomerLedgerEntry entry,
    required CustomerLedger ledger,
    required bool alt,
  }) {
    return TableRow(
      decoration: BoxDecoration(color: alt ? Colors.grey.shade50 : Colors.white),
      children: [
        _td('$rowNum'),
        _td(_dateFormat.format(entry.date)),
        _td(entry.documentNumber, bold: true),
        _td(_documentTypeLabel(entry.documentType)),
        _td(entry.debit > 0 ? _localization.formatCurrency(entry.debit) : '', color: AppColors.error),
        _td(entry.credit > 0 ? _localization.formatCurrency(entry.credit) : '', color: AppColors.success),
        _td(_localization.formatCurrency(entry.runningBalance), bold: true),
        _tdWidget(_notesCell(entry)),
        _tdWidget(_rowActions(entry)),
      ],
    );
  }

  Widget _notesCell(CustomerLedgerEntry entry) {
    if (entry.isOpeningBalance) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        child: Text(entry.notes ?? '', style: const TextStyle(fontSize: 14)),
      );
    }

    final text = entry.notes?.trim();
    final hasNotes = text != null && text.isNotEmpty;
    final canEdit = entry.isSalesInvoice || entry.isPayment || entry.isDiscount;

    if (!canEdit) {
      return _td(entry.notes ?? '', fontSize: 14);
    }

    return InkWell(
      onTap: () => _editEntryNotes(entry),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                hasNotes ? text! : _localization.get('addNotes'),
                style: TextStyle(
                  fontSize: 14,
                  color: hasNotes ? AppColors.textPrimary : AppColors.textHint,
                  fontStyle: hasNotes ? FontStyle.normal : FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              hasNotes ? Icons.edit_note : Icons.note_add_outlined,
              size: 18,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemNotesCell(SaleItem item) {
    final text = item.note?.trim();
    final hasNotes = text != null && text.isNotEmpty;

    return InkWell(
      onTap: () => _editSaleItemNotes(item),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                hasNotes ? text! : _localization.get('addNotes'),
                style: TextStyle(
                  fontSize: 13,
                  color: hasNotes ? AppColors.textPrimary : AppColors.textHint,
                  fontStyle: hasNotes ? FontStyle.normal : FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              hasNotes ? Icons.edit_note : Icons.note_add_outlined,
              size: 16,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowActions(CustomerLedgerEntry entry) {
    if (entry.isOpeningBalance) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 18),
      padding: EdgeInsets.zero,
      onSelected: (action) {
        switch (action) {
          case 'discount':
            _applyInvoiceDiscount(entry);
            break;
          case 'notes':
            _editEntryNotes(entry);
            break;
          case 'edit':
            if (entry.isSalesInvoice) {
              _editInvoice(entry.invoiceId!);
            } else if (entry.isPayment) {
              _editPayment(entry);
            }
            break;
          case 'delete':
            if (entry.isSalesInvoice) {
              _confirmDeleteInvoice(entry.invoiceId!, entry.documentNumber);
            } else if (entry.isPayment) {
              _confirmDeletePayment(entry.paymentId!);
            }
            break;
        }
      },
      itemBuilder: (context) => [
        if (entry.isSalesInvoice) ...[
          PopupMenuItem(value: 'discount', child: Text(_localization.get('invoiceDiscount'))),
          PopupMenuItem(value: 'notes', child: Text(_localization.get('notes'))),
          PopupMenuItem(value: 'edit', child: Text(_localization.get('edit'))),
          PopupMenuItem(
            value: 'delete',
            child: Text(_localization.get('deleteDayEntry'), style: const TextStyle(color: AppColors.error)),
          ),
        ],
        if (entry.isPayment) ...[
          PopupMenuItem(value: 'notes', child: Text(_localization.get('notes'))),
          PopupMenuItem(value: 'edit', child: Text(_localization.get('editPayment'))),
          PopupMenuItem(
            value: 'delete',
            child: Text(_localization.get('delete'), style: const TextStyle(color: AppColors.error)),
          ),
        ],
        if (entry.isDiscount) ...[
          PopupMenuItem(value: 'notes', child: Text(_localization.get('notes'))),
          PopupMenuItem(
            value: 'delete',
            child: Text(_localization.get('delete'), style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ],
    );
  }

  Widget _th(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      );

  Widget _td(String text, {bool bold = false, Color? color, double fontSize = 14}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            fontSize: fontSize,
            color: color,
          ),
        ),
      );

  Widget _tdWidget(Widget child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: child,
      );

  Widget _buildFooter(CustomerLedger ledger) {
    final balanceColor = ledger.finalBalance > 0
        ? AppColors.error
        : ledger.finalBalance < 0
            ? AppColors.info
            : AppColors.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          _footerStat(_localization.get('totalDebit'), ledger.totalDebit, AppColors.error),
          const SizedBox(width: 24),
          _footerStat(_localization.get('totalCredit'), ledger.totalCredit, AppColors.success),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_localization.get('netBalance'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              Text(
                '${_localization.get('netBalance')} : ${_localization.formatCurrency(ledger.finalBalance.abs())}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: balanceColor),
              ),
              Text(
                ledger.isDebtor
                    ? _localization.get('debtor')
                    : ledger.isCreditor
                        ? _localization.get('creditor')
                        : _localization.get('customerSettled'),
                style: TextStyle(fontSize: 10, color: balanceColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _footerStat(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        Text(
          _localization.formatCurrency(value),
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
