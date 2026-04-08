import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/entities/supplier_invoice.dart';
import '../bloc/supplier_bloc.dart';
import 'supplier_invoice_form_dialog.dart';
import 'supplier_record_payment_dialog.dart';

class SupplierFinancialDialog extends StatefulWidget {
  final Supplier supplier;

  const SupplierFinancialDialog({super.key, required this.supplier});

  @override
  State<SupplierFinancialDialog> createState() => _SupplierFinancialDialogState();
}

class _SupplierFinancialDialogState extends State<SupplierFinancialDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    context.read<SupplierBloc>().add(SupplierLoadInvoices(widget.supplier.id!));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddInvoiceDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<SupplierBloc>(),
        child: SupplierInvoiceFormDialog(supplierId: widget.supplier.id!),
      ),
    );
  }

  void _showEditInvoiceDialog(SupplierInvoice invoice) {
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<SupplierBloc>(),
        child: SupplierInvoiceFormDialog(
          supplierId: widget.supplier.id!,
          invoice: invoice,
        ),
      ),
    );
  }

  void _showRecordPaymentDialog(SupplierInvoice invoice) {
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<SupplierBloc>(),
        child: SupplierRecordPaymentDialog(invoice: invoice),
      ),
    );
  }

  void _confirmDeleteInvoice(SupplierInvoice invoice) {
    final loc = LocalizationService();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.get('confirmDelete')),
        content: Text(loc.get('confirmDeleteSupplierInvoice')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.get('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<SupplierBloc>().add(SupplierDeleteInvoice(
                invoiceId: invoice.id!,
                supplierId: widget.supplier.id!,
              ));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(loc.get('delete')),
          ),
        ],
      ),
    );
  }

  Future<void> _openFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LocalizationService().get('fileNotFound')),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    await Process.run('cmd', ['/c', 'start', '', filePath]);
  }

  Widget _buildStatusBadge(SupplierInvoice invoice) {
    final loc = LocalizationService();
    Color color;
    String text;
    switch (invoice.paymentStatus) {
      case InvoicePaymentStatus.paid:
        color = AppColors.success;
        text = loc.get('fullyPaid');
        break;
      case InvoicePaymentStatus.partiallyPaid:
        color = Colors.orange;
        text = loc.get('partiallyPaid');
        break;
      case InvoicePaymentStatus.unpaid:
        color = AppColors.error;
        text = loc.get('unpaid');
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = LocalizationService();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 850,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${loc.get('supplierFinancials')} - ${widget.supplier.name}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Tabs
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              tabs: [
                Tab(
                  icon: const Icon(Icons.receipt_long),
                  text: loc.get('supplierInvoices'),
                ),
                Tab(
                  icon: const Icon(Icons.assessment),
                  text: loc.get('supplierAccountStatement'),
                ),
              ],
            ),

            // Tab Content
            Expanded(
              child: BlocBuilder<SupplierBloc, SupplierState>(
                builder: (context, state) {
                  List<SupplierInvoice> invoices = [];
                  Map<String, dynamic>? summary;

                  if (state is SupplierLoaded) {
                    invoices = state.invoices;
                    summary = state.financialSummary;
                  }

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildInvoicesTab(invoices),
                      _buildStatementTab(invoices, summary),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Invoices Tab ───
  Widget _buildInvoicesTab(List<SupplierInvoice> invoices) {
    final loc = LocalizationService();

    return Column(
      children: [
        // Add Invoice button
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${loc.get('total')}: ${invoices.length}',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              ElevatedButton.icon(
                onPressed: _showAddInvoiceDialog,
                icon: const Icon(Icons.add),
                label: Text(loc.get('addSupplierInvoice')),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Invoices list
        Expanded(
          child: invoices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 48, color: AppColors.textHint),
                      const SizedBox(height: 8),
                      Text(
                        loc.get('noSupplierInvoices'),
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: invoices.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final inv = invoices[index];
                    return _buildInvoiceCard(inv);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildInvoiceCard(SupplierInvoice inv) {
    final loc = LocalizationService();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: ExpansionTile(
        leading: Icon(
          inv.hasFile
              ? (inv.isPdf ? Icons.picture_as_pdf : Icons.image)
              : Icons.receipt,
          color: inv.hasFile
              ? (inv.isPdf ? Colors.red : Colors.blue)
              : AppColors.textHint,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '#${inv.invoiceNumber}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            _buildStatusBadge(inv),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              Text(
                _dateFormat.format(inv.invoiceDate),
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              Text(
                '${loc.get('totalAmountLabel')}: ${LocalizationService().formatCurrency(inv.totalAmount)}',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                '${loc.get('remainingBalanceLabel')}: ${LocalizationService().formatCurrency(inv.remainingAmount)}',
                style: TextStyle(
                  fontSize: 12,
                  color: inv.remainingAmount > 0 ? AppColors.error : AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Invoice details
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _detailChip(loc.get('totalAmountLabel'),
                        LocalizationService().formatCurrency(inv.totalAmount), Colors.blue),
                    _detailChip(loc.get('paidAmountLabel'),
                        LocalizationService().formatCurrency(inv.paidAmount), AppColors.success),
                    _detailChip(loc.get('remainingBalanceLabel'),
                        LocalizationService().formatCurrency(inv.remainingAmount),
                        inv.remainingAmount > 0 ? AppColors.error : AppColors.success),
                  ],
                ),
                if (inv.notes != null && inv.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${loc.get('notes')}: ${inv.notes}',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
                const SizedBox(height: 8),

                // Action buttons
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    if (inv.hasFile)
                      TextButton.icon(
                        onPressed: () => _openFile(inv.filePath!),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: Text(loc.get('openFile')),
                      ),
                    if (!inv.isPaid)
                      TextButton.icon(
                        onPressed: () => _showRecordPaymentDialog(inv),
                        icon: const Icon(Icons.payment, size: 16),
                        label: Text(loc.get('recordPaymentForInvoice')),
                        style: TextButton.styleFrom(foregroundColor: AppColors.success),
                      ),
                    TextButton.icon(
                      onPressed: () => _showEditInvoiceDialog(inv),
                      icon: const Icon(Icons.edit, size: 16),
                      label: Text(loc.get('edit')),
                    ),
                    TextButton.icon(
                      onPressed: () => _confirmDeleteInvoice(inv),
                      icon: const Icon(Icons.delete, size: 16),
                      label: Text(loc.get('delete')),
                      style: TextButton.styleFrom(foregroundColor: AppColors.error),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: color)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // ─── Account Statement Tab ───
  Widget _buildStatementTab(List<SupplierInvoice> invoices, Map<String, dynamic>? summary) {
    final loc = LocalizationService();

    if (summary == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalAmount = (summary['total_amount'] as num?)?.toDouble() ?? 0;
    final totalPaid = (summary['total_paid'] as num?)?.toDouble() ?? 0;
    final totalOutstanding = (summary['total_outstanding'] as num?)?.toDouble() ?? 0;
    final totalInvoices = (summary['total_invoices'] as num?)?.toInt() ?? 0;
    final paidCount = (summary['paid_count'] as num?)?.toInt() ?? 0;
    final partialCount = (summary['partial_count'] as num?)?.toInt() ?? 0;
    final unpaidCount = (summary['unpaid_count'] as num?)?.toInt() ?? 0;
    final lastPaymentAmount = summary['last_payment_amount'] as double?;
    final lastPaymentDate = summary['last_payment_date'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards row
          Row(
            children: [
              _summaryCard(
                loc.get('totalInvoiced'),
                LocalizationService().formatCurrency(totalAmount),
                Icons.receipt_long,
                Colors.blue,
              ),
              const SizedBox(width: 12),
              _summaryCard(
                loc.get('totalPaid'),
                LocalizationService().formatCurrency(totalPaid),
                Icons.check_circle,
                AppColors.success,
              ),
              const SizedBox(width: 12),
              _summaryCard(
                loc.get('totalOutstanding'),
                LocalizationService().formatCurrency(totalOutstanding),
                Icons.warning_amber_rounded,
                totalOutstanding > 0 ? AppColors.error : AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Status breakdown
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.get('financialOverview'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _statementRow(loc.get('totalInvoices'), '$totalInvoices'),
                  _statementRow(loc.get('paidInvoicesCount'), '$paidCount',
                      color: AppColors.success),
                  _statementRow(loc.get('partialInvoicesCount'), '$partialCount',
                      color: Colors.orange),
                  _statementRow(loc.get('unpaidInvoicesCount'), '$unpaidCount',
                      color: AppColors.error),
                  const Divider(),
                  _statementRow(
                    loc.get('currentBalance'),
                    LocalizationService().formatCurrency(totalOutstanding),
                    color: totalOutstanding > 0 ? AppColors.error : AppColors.success,
                    isBold: true,
                  ),
                  if (lastPaymentAmount != null && lastPaymentDate != null) ...[
                    const Divider(),
                    _statementRow(
                      loc.get('lastPayment'),
                      '${LocalizationService().formatCurrency(lastPaymentAmount)} (${_dateFormat.format(DateTime.parse(lastPaymentDate))})',
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Invoice details table
          Text(
            loc.get('supplierInvoices'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          if (invoices.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  loc.get('noSupplierInvoices'),
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            _buildInvoiceTable(invoices),
        ],
      ),
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(title, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statementRow(String label, String value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.w500)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color,
              fontSize: isBold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceTable(List<SupplierInvoice> invoices) {
    final loc = LocalizationService();

    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      columnWidths: const {
        0: FlexColumnWidth(1.5),
        1: FlexColumnWidth(1.2),
        2: FlexColumnWidth(1.2),
        3: FlexColumnWidth(1.2),
        4: FlexColumnWidth(1.2),
        5: FlexColumnWidth(1),
      },
      children: [
        // Header
        TableRow(
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1)),
          children: [
            _tableHeader(loc.get('invoiceNumberLabel')),
            _tableHeader(loc.get('invoiceDateLabel')),
            _tableHeader(loc.get('totalAmountLabel')),
            _tableHeader(loc.get('paidAmountLabel')),
            _tableHeader(loc.get('remainingBalanceLabel')),
            _tableHeader(loc.get('paymentStatusLabel')),
          ],
        ),
        // Rows
        ...invoices.map((inv) => TableRow(
              children: [
                _tableCell('#${inv.invoiceNumber}'),
                _tableCell(_dateFormat.format(inv.invoiceDate)),
                _tableCell(LocalizationService().formatCurrency(inv.totalAmount)),
                _tableCell(LocalizationService().formatCurrency(inv.paidAmount)),
                _tableCellColored(
                  LocalizationService().formatCurrency(inv.remainingAmount),
                  inv.remainingAmount > 0 ? AppColors.error : AppColors.success,
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: _buildStatusBadge(inv),
                ),
              ],
            )),
      ],
    );
  }

  Widget _tableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _tableCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _tableCellColored(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
    );
  }
}
