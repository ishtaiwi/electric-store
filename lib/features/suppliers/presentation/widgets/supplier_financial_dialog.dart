import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/entities/supplier_invoice.dart';
import '../../domain/entities/supplier_payment.dart';
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
  final _currencyFormat = LocalizationService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  void _loadAllData() {
    final bloc = context.read<SupplierBloc>();
    bloc.add(SupplierLoadInvoices(widget.supplier.id!));
    bloc.add(SupplierLoadPayments(widget.supplier.id!));
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

  void _confirmDeletePayment(SupplierPayment payment) {
    final loc = LocalizationService();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.get('confirmDelete')),
        content: Text(loc.get('deletePaymentConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.get('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<SupplierBloc>().add(SupplierDeletePayment(
                paymentId: payment.id!,
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
      case InvoicePaymentStatus.overpaid:
        color = AppColors.info;
        text = loc.get('overpaid');
        break;
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
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPaymentMethodBadge(SupplierPayment payment) {
    final loc = LocalizationService();
    final isCheque = payment.isCheque;
    final color = isCheque ? AppColors.info : AppColors.success;
    final text = isCheque ? loc.get('chequePayment') : loc.get('cashPayment');
    final icon = isCheque ? Icons.description_outlined : Icons.payments_outlined;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final loc = LocalizationService();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 950,
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: Column(
          children: [
            // ─── Header ───
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primary],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.supplier.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          loc.get('supplierFinancialDashboard'),
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // ─── Summary Bar ───
            BlocBuilder<SupplierBloc, SupplierState>(
              builder: (context, state) {
                Map<String, dynamic>? summary;
                List<SupplierPayment> payments = [];
                if (state is SupplierLoaded) {
                  summary = state.financialSummary;
                  payments = state.payments;
                }

                final totalAmount = (summary?['total_amount'] as num?)?.toDouble() ?? 0;
                final totalPaid = (summary?['total_paid'] as num?)?.toDouble() ?? 0;
                final totalOutstanding = (summary?['total_outstanding'] as num?)?.toDouble() ?? 0;
                final totalInvoices = (summary?['total_invoices'] as num?)?.toInt() ?? 0;

                final cashPayments = payments.where((p) => p.isCash).fold<double>(0, (sum, p) => sum + p.amount);
                final chequePayments = payments.where((p) => p.isCheque).fold<double>(0, (sum, p) => sum + p.amount);

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: AppColors.background,
                  child: Row(
                    children: [
                      _summaryChip(
                        loc.get('totalInvoiced'),
                        _currencyFormat.formatCurrency(totalAmount),
                        Icons.receipt_long,
                        AppColors.primary,
                        '$totalInvoices ${loc.get('supplierInvoices')}',
                      ),
                      const SizedBox(width: 8),
                      _summaryChip(
                        loc.get('totalPaid'),
                        _currencyFormat.formatCurrency(totalPaid),
                        Icons.check_circle_outline,
                        AppColors.success,
                        '${loc.get('cashPayment')}: ${_currencyFormat.formatCurrency(cashPayments)}  •  ${loc.get('chequePayment')}: ${_currencyFormat.formatCurrency(chequePayments)}',
                      ),
                      const SizedBox(width: 8),
                      _summaryChip(
                        loc.get('supplierBalance'),
                        _currencyFormat.formatCurrency(totalOutstanding),
                        totalOutstanding > 0
                            ? Icons.warning_amber_rounded
                            : totalOutstanding < 0
                                ? Icons.swap_vert
                                : Icons.check_circle,
                        totalOutstanding > 0
                            ? AppColors.error
                            : totalOutstanding < 0
                                ? AppColors.info
                                : AppColors.success,
                        totalOutstanding > 0
                            ? loc.get('positiveBalance')
                            : totalOutstanding < 0
                                ? loc.get('negativeBalance')
                                : loc.get('zeroBalance'),
                      ),
                    ],
                  ),
                );
              },
            ),

            // ─── Tabs ───
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                tabs: [
                  Tab(icon: const Icon(Icons.receipt_long, size: 20), text: loc.get('supplierInvoices')),
                  Tab(icon: const Icon(Icons.payments_outlined, size: 20), text: loc.get('allPayments')),
                  Tab(icon: const Icon(Icons.account_balance, size: 20), text: loc.get('accountLedger')),
                ],
              ),
            ),

            // ─── Tab Content ───
            Expanded(
              child: BlocBuilder<SupplierBloc, SupplierState>(
                builder: (context, state) {
                  List<SupplierInvoice> invoices = [];
                  List<SupplierPayment> payments = [];
                  Map<String, dynamic>? summary;

                  if (state is SupplierLoaded) {
                    invoices = state.invoices;
                    payments = state.payments;
                    summary = state.financialSummary;
                  }

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildInvoicesTab(invoices),
                      _buildPaymentsTab(payments, invoices),
                      _buildLedgerTab(invoices, payments, summary),
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

  // ─────────────────────────────────────────────────────────────────
  //  SUMMARY CHIP
  // ─────────────────────────────────────────────────────────────────
  Widget _summaryChip(String title, String value, IconData icon, Color color, String subtitle) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(subtitle, style: TextStyle(fontSize: 10, color: AppColors.textHint), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  TAB 1: INVOICES
  // ─────────────────────────────────────────────────────────────────
  Widget _buildInvoicesTab(List<SupplierInvoice> invoices) {
    final loc = LocalizationService();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${loc.get('total')}: ${invoices.length}',
                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
              ),
              ElevatedButton.icon(
                onPressed: _showAddInvoiceDialog,
                icon: const Icon(Icons.add, size: 18),
                label: Text(loc.get('addSupplierInvoice')),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: invoices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 56, color: AppColors.textHint),
                      const SizedBox(height: 12),
                      Text(loc.get('noSupplierInvoices'), style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: invoices.length,
                  itemBuilder: (context, index) => _buildInvoiceCard(invoices[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildInvoiceCard(SupplierInvoice inv) {
    final loc = LocalizationService();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: (inv.isOverpaid ? AppColors.info : inv.isPaid ? AppColors.success : inv.isPartiallyPaid ? Colors.orange : AppColors.error).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            inv.hasFile ? (inv.isPdf ? Icons.picture_as_pdf : Icons.image) : Icons.receipt,
            color: inv.hasFile ? (inv.isPdf ? Colors.red : Colors.blue) : AppColors.textHint,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text('#${inv.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            _buildStatusBadge(inv),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Icon(Icons.calendar_today, size: 12, color: AppColors.textHint),
              const SizedBox(width: 4),
              Text(_dateFormat.format(inv.invoiceDate), style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(width: 16),
              Text(_currencyFormat.formatCurrency(inv.totalAmount), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (inv.remainingAmount > 0)
                Text(
                  '${loc.get('remaining')}: ${_currencyFormat.formatCurrency(inv.remainingAmount)}',
                  style: TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w600),
                )
              else if (inv.isOverpaid)
                Text(
                  '${loc.get('creditBalanceLabel')}: ${_currencyFormat.formatCurrency(inv.creditAmount)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.info, fontWeight: FontWeight.w600),
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
                // Amount breakdown
                Row(
                  children: [
                    _amountChip(loc.get('totalAmountLabel'), _currencyFormat.formatCurrency(inv.totalAmount), AppColors.primary),
                    const SizedBox(width: 8),
                    _amountChip(loc.get('paidAmountLabel'), _currencyFormat.formatCurrency(inv.paidAmount), AppColors.success),
                    const SizedBox(width: 8),
                    _amountChip(
                      inv.isOverpaid ? loc.get('creditBalanceLabel') : loc.get('remainingBalanceLabel'),
                      inv.isOverpaid
                          ? _currencyFormat.formatCurrency(inv.creditAmount)
                          : _currencyFormat.formatCurrency(inv.remainingAmount),
                      inv.isOverpaid ? AppColors.info : inv.remainingAmount > 0 ? AppColors.error : AppColors.success,
                    ),
                  ],
                ),
                if (inv.notes != null && inv.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('${loc.get('notes')}: ${inv.notes}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 10),
                // Action row
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (inv.hasFile)
                      _actionBtn(Icons.open_in_new, loc.get('openFile'), null, () => _openFile(inv.filePath!)),
                    _actionBtn(Icons.payment, loc.get('recordPaymentForInvoice'), AppColors.success, () => _showRecordPaymentDialog(inv)),
                    _actionBtn(Icons.edit, loc.get('edit'), AppColors.primary, () => _showEditInvoiceDialog(inv)),
                    _actionBtn(Icons.delete, loc.get('delete'), AppColors.error, () => _confirmDeleteInvoice(inv)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: color)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, String tooltip, Color? color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(tooltip, style: const TextStyle(fontSize: 12)),
        style: TextButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  TAB 2: PAYMENTS LEDGER
  // ─────────────────────────────────────────────────────────────────
  Widget _buildPaymentsTab(List<SupplierPayment> payments, List<SupplierInvoice> invoices) {
    final loc = LocalizationService();

    // Build invoice number lookup map
    final invoiceMap = <int, String>{};
    for (final inv in invoices) {
      if (inv.id != null) invoiceMap[inv.id!] = inv.invoiceNumber;
    }

    final cashTotal = payments.where((p) => p.isCash).fold<double>(0, (sum, p) => sum + p.amount);
    final chequeTotal = payments.where((p) => p.isCheque).fold<double>(0, (sum, p) => sum + p.amount);

    return Column(
      children: [
        // Payment breakdown header
        Container(
          padding: const EdgeInsets.all(12),
          color: AppColors.background,
          child: Row(
            children: [
              _paymentSummaryPill(Icons.payments_outlined, loc.get('totalCashPayments'), _currencyFormat.formatCurrency(cashTotal), AppColors.success),
              const SizedBox(width: 8),
              _paymentSummaryPill(Icons.description_outlined, loc.get('totalChequePayments'), _currencyFormat.formatCurrency(chequeTotal), AppColors.info),
              const Spacer(),
              Text(
                '${payments.length} ${loc.get('allPayments')}',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Payments table
        Expanded(
          child: payments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.payments_outlined, size: 56, color: AppColors.textHint),
                      const SizedBox(height: 12),
                      Text(loc.get('noPaymentsYet'), style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Table(
                    border: TableBorder.all(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                    columnWidths: const {
                      0: FlexColumnWidth(1.2),  // Date
                      1: FlexColumnWidth(1.2),  // Invoice Ref
                      2: FlexColumnWidth(1.3),  // Amount
                      3: FlexColumnWidth(1.2),  // Method
                      4: FlexColumnWidth(1.2),  // Cheque #
                      5: FlexColumnWidth(1.2),  // Notes
                      6: FixedColumnWidth(50),   // Actions
                    },
                    children: [
                      // Header
                      TableRow(
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        ),
                        children: [
                          _tHeader(loc.get('date')),
                          _tHeader(loc.get('invoiceRef')),
                          _tHeader(loc.get('amount')),
                          _tHeader(loc.get('paymentMethodLabel')),
                          _tHeader(loc.get('chequeNumber')),
                          _tHeader(loc.get('notes')),
                          _tHeader(''),
                        ],
                      ),
                      // Rows
                      ...payments.map((p) {
                        final invoiceNum = invoiceMap[p.supplierInvoiceId] ?? '-';
                        return TableRow(
                          decoration: BoxDecoration(
                            color: payments.indexOf(p).isEven ? Colors.white : Colors.grey.shade50,
                          ),
                          children: [
                            _tCell(_dateFormat.format(p.paymentDate)),
                            _tCellWidget(
                              Text('#$invoiceNum', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                            _tCellWidget(
                              Text(
                                _currencyFormat.formatCurrency(p.amount),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: _buildPaymentMethodBadge(p),
                            ),
                            _tCell(p.chequeNumber ?? '-'),
                            _tCell(p.notes ?? '-'),
                            Padding(
                              padding: const EdgeInsets.all(4),
                              child: IconButton(
                                icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                                onPressed: () => _confirmDeletePayment(p),
                                tooltip: loc.get('delete'),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _paymentSummaryPill(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: color)),
              Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  TAB 3: ACCOUNT LEDGER (Full Statement)
  // ─────────────────────────────────────────────────────────────────
  Widget _buildLedgerTab(List<SupplierInvoice> invoices, List<SupplierPayment> payments, Map<String, dynamic>? summary) {
    final loc = LocalizationService();

    // Build a combined & sorted list of transactions
    final List<_LedgerEntry> entries = [];

    // Add invoices as debit entries
    for (final inv in invoices) {
      entries.add(_LedgerEntry(
        date: inv.invoiceDate,
        type: _LedgerType.invoice,
        reference: '#${inv.invoiceNumber}',
        debit: inv.totalAmount,
        credit: 0,
        notes: inv.notes,
      ));
    }

    // Add payments as credit entries
    // Build invoice number lookup map
    final invoiceMap = <int, String>{};
    for (final inv in invoices) {
      if (inv.id != null) invoiceMap[inv.id!] = inv.invoiceNumber;
    }

    for (final p in payments) {
      final invoiceNum = invoiceMap[p.supplierInvoiceId] ?? '?';
      entries.add(_LedgerEntry(
        date: p.paymentDate,
        type: _LedgerType.payment,
        reference: '#$invoiceNum',
        debit: 0,
        credit: p.amount,
        notes: p.isCheque ? '${loc.get('cheque')}: ${p.chequeNumber ?? '-'}' : loc.get('cashPayment'),
        paymentMethod: p.paymentMethod,
      ));
    }

    // Sort by date ascending
    entries.sort((a, b) => a.date.compareTo(b.date));

    // Calculate running balance
    double balance = 0;
    for (final entry in entries) {
      balance += entry.debit - entry.credit;
      entry.runningBalance = balance;
    }

    final totalOutstanding = (summary?['total_outstanding'] as num?)?.toDouble() ?? balance;
    final totalAmount = (summary?['total_amount'] as num?)?.toDouble() ?? 0;
    final totalPaid = (summary?['total_paid'] as num?)?.toDouble() ?? 0;
    final overpaidCount = (summary?['overpaid_count'] as num?)?.toInt() ?? 0;
    final paidCount = (summary?['paid_count'] as num?)?.toInt() ?? 0;
    final partialCount = (summary?['partial_count'] as num?)?.toInt() ?? 0;
    final unpaidCount = (summary?['unpaid_count'] as num?)?.toInt() ?? 0;

    return Column(
      children: [
        // Financial overview bar
        Container(
          padding: const EdgeInsets.all(12),
          color: AppColors.background,
          child: Row(
            children: [
              // Status breakdown chips
              if (overpaidCount > 0) ...[
                _statusChip('$overpaidCount', loc.get('overpaid'), AppColors.info),
                const SizedBox(width: 6),
              ],
              _statusChip('$paidCount', loc.get('fullyPaid'), AppColors.success),
              const SizedBox(width: 6),
              _statusChip('$partialCount', loc.get('partiallyPaid'), Colors.orange),
              const SizedBox(width: 6),
              _statusChip('$unpaidCount', loc.get('unpaid'), AppColors.error),
              const Spacer(),
              // Balance indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: totalOutstanding > 0
                        ? [AppColors.error.withOpacity(0.1), AppColors.error.withOpacity(0.05)]
                        : totalOutstanding < 0
                            ? [AppColors.info.withOpacity(0.1), AppColors.info.withOpacity(0.05)]
                            : [AppColors.success.withOpacity(0.1), AppColors.success.withOpacity(0.05)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (totalOutstanding > 0 ? AppColors.error : totalOutstanding < 0 ? AppColors.info : AppColors.success).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '${loc.get('currentBalance')}: ',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      _currencyFormat.formatCurrency(totalOutstanding),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: totalOutstanding > 0 ? AppColors.error : totalOutstanding < 0 ? AppColors.info : AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Ledger table
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_balance, size: 56, color: AppColors.textHint),
                      const SizedBox(height: 12),
                      Text(loc.get('noTransactions'), style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      // Ledger table
                      Table(
                        border: TableBorder.all(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                        columnWidths: const {
                          0: FlexColumnWidth(1.1),  // Date
                          1: FlexColumnWidth(0.9),  // Type
                          2: FlexColumnWidth(1.1),  // Reference
                          3: FlexColumnWidth(1.2),  // Debit
                          4: FlexColumnWidth(1.2),  // Credit
                          5: FlexColumnWidth(1.2),  // Balance
                          6: FlexColumnWidth(1.5),  // Details
                        },
                        children: [
                          // Header
                          TableRow(
                            decoration: BoxDecoration(
                              color: AppColors.primaryDark.withOpacity(0.08),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                            ),
                            children: [
                              _tHeader(loc.get('date')),
                              _tHeader(loc.get('transactionType')),
                              _tHeader(loc.get('invoiceRef')),
                              _tHeader(loc.get('debit')),
                              _tHeader(loc.get('creditEntry')),
                              _tHeader(loc.get('runningBalance')),
                              _tHeader(loc.get('details')),
                            ],
                          ),
                          // Rows
                          ...entries.asMap().entries.map((mapEntry) {
                            final i = mapEntry.key;
                            final e = mapEntry.value;
                            final isInvoice = e.type == _LedgerType.invoice;
                            return TableRow(
                              decoration: BoxDecoration(
                                color: i.isEven ? Colors.white : Colors.grey.shade50,
                              ),
                              children: [
                                _tCell(_dateFormat.format(e.date)),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: (isInvoice ? AppColors.error : AppColors.success).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isInvoice ? loc.get('invoiceEntry') : loc.get('paymentEntry'),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isInvoice ? AppColors.error : AppColors.success,
                                      ),
                                    ),
                                  ),
                                ),
                                _tCell(e.reference),
                                _tCellWidget(
                                  Text(
                                    e.debit > 0 ? _currencyFormat.formatCurrency(e.debit) : '-',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: e.debit > 0 ? AppColors.error : AppColors.textHint),
                                  ),
                                ),
                                _tCellWidget(
                                  Text(
                                    e.credit > 0 ? _currencyFormat.formatCurrency(e.credit) : '-',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: e.credit > 0 ? AppColors.success : AppColors.textHint),
                                  ),
                                ),
                                _tCellWidget(
                                  Text(
                                    _currencyFormat.formatCurrency(e.runningBalance),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: e.runningBalance > 0 ? AppColors.error : e.runningBalance < 0 ? AppColors.info : AppColors.success,
                                    ),
                                  ),
                                ),
                                _tCell(e.notes ?? '-'),
                              ],
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Totals row
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primaryDark.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primaryDark.withOpacity(0.15)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Text('${loc.get('debit')}: ', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                                  Text(
                                    _currencyFormat.formatCurrency(totalAmount),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.error),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Row(
                                children: [
                                  Text('${loc.get('creditEntry')}: ', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                                  Text(
                                    _currencyFormat.formatCurrency(totalPaid),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.success),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Row(
                                children: [
                                  Text('${loc.get('currentBalance')}: ', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                                  Text(
                                    _currencyFormat.formatCurrency(totalOutstanding),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: totalOutstanding > 0 ? AppColors.error : totalOutstanding < 0 ? AppColors.info : AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _statusChip(String count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(count, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }

  // ─── Table helpers ───
  Widget _tHeader(String text) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _tCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(text, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
    );
  }

  Widget _tCellWidget(Widget child) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: child,
    );
  }
}

// ─── Ledger Entry model ───
enum _LedgerType { invoice, payment }

class _LedgerEntry {
  final DateTime date;
  final _LedgerType type;
  final String reference;
  final double debit;
  final double credit;
  final String? notes;
  final SupplierPaymentMethod? paymentMethod;
  double runningBalance = 0;

  _LedgerEntry({
    required this.date,
    required this.type,
    required this.reference,
    required this.debit,
    required this.credit,
    this.notes,
    this.paymentMethod,
  });
}
