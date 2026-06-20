import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../invoices/domain/entities/invoice.dart';
import '../../../invoices/domain/repositories/invoice_repository.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/customer_payment.dart';
import '../../domain/repositories/customer_repository.dart';
import '../bloc/customer_bloc.dart';
import 'customer_record_payment_dialog.dart';

class CustomerFinancialDialog extends StatefulWidget {
  final Customer customer;

  const CustomerFinancialDialog({super.key, required this.customer});

  @override
  State<CustomerFinancialDialog> createState() => _CustomerFinancialDialogState();
}

class _CustomerFinancialDialogState extends State<CustomerFinancialDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _dateFormat = DateFormat('yyyy-MM-dd');
  final _loc = LocalizationService();

  List<Invoice> _invoices = [];
  List<CustomerPayment> _payments = [];
  Map<String, dynamic> _summary = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final invoiceRepo = di.sl<InvoiceRepository>();
      final customerRepo = di.sl<CustomerRepository>();
      final customerId = widget.customer.id!;

      final results = await Future.wait([
        invoiceRepo.getInvoicesByCustomer(customerId),
        customerRepo.getPaymentsByCustomer(customerId),
        customerRepo.getCustomerFinancialSummary(customerId),
      ]);

      if (mounted) {
        setState(() {
          _invoices = results[0] as List<Invoice>;
          _payments = results[1] as List<CustomerPayment>;
          _summary = results[2] as Map<String, dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showRecordPaymentDialog(Invoice invoice) {
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<CustomerBloc>(),
        child: CustomerRecordPaymentDialog(
          invoice: invoice,
          customerId: widget.customer.id!,
        ),
      ),
    ).then((_) => _loadAllData());
  }

  void _confirmDeletePayment(CustomerPayment payment) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_loc.get('confirmDelete')),
        content: Text(_loc.get('deletePaymentConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_loc.get('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<CustomerBloc>().add(CustomerDeletePayment(
                paymentId: payment.id!,
                customerId: widget.customer.id!,
              ));
              _loadAllData();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(_loc.get('delete'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(Invoice invoice) {
    Color color;
    String text;
    if (invoice.paidAmount > invoice.finalAmount) {
      color = AppColors.info;
      text = _loc.get('overpaid');
    } else if (invoice.isFullyPaid) {
      color = AppColors.success;
      text = _loc.get('fullyPaid');
    } else if (invoice.isPartiallyPaid) {
      color = Colors.orange;
      text = _loc.get('partiallyPaid');
    } else {
      color = AppColors.error;
      text = _loc.get('unpaid');
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

  Widget _buildPaymentMethodBadge(CustomerPayment payment) {
    final isCheque = payment.isCheque;
    final color = isCheque ? AppColors.info : AppColors.success;
    final text = isCheque ? _loc.get('chequePayment') : _loc.get('cashPayment');
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

  @override
  Widget build(BuildContext context) {
    final totalInvoiced = (_summary['total_invoiced'] as num?)?.toDouble() ?? 0;
    final totalPaid = (_summary['total_paid'] as num?)?.toDouble() ?? 0;
    final outstanding = (_summary['outstanding'] as num?)?.toDouble() ?? 0;
    final totalInvoices = (_summary['total_invoices'] as num?)?.toInt() ?? 0;
    final cashTotal = (_summary['cash_total'] as num?)?.toDouble() ?? 0;
    final chequeTotal = (_summary['cheque_total'] as num?)?.toDouble() ?? 0;

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
                          widget.customer.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _loc.get('customerFinancial'),
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
            if (_isLoading)
              const LinearProgressIndicator()
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: AppColors.background,
                child: Row(
                  children: [
                    _summaryChip(
                      _loc.get('totalInvoiced'),
                      _loc.formatCurrency(totalInvoiced),
                      Icons.receipt_long,
                      AppColors.primary,
                      '$totalInvoices ${_loc.get('invoices')}',
                    ),
                    const SizedBox(width: 8),
                    _summaryChip(
                      _loc.get('totalPaidAmount'),
                      _loc.formatCurrency(totalPaid),
                      Icons.check_circle_outline,
                      AppColors.success,
                      '${_loc.get('cashPayment')}: ${_loc.formatCurrency(cashTotal)}  •  ${_loc.get('chequePayment')}: ${_loc.formatCurrency(chequeTotal)}',
                    ),
                    const SizedBox(width: 8),
                    _summaryChip(
                      _loc.get('customerBalance'),
                      _loc.formatCurrency(outstanding.abs()),
                      outstanding > 0
                          ? Icons.warning_amber_rounded
                          : outstanding < 0
                              ? Icons.swap_vert
                              : Icons.check_circle,
                      outstanding > 0
                          ? AppColors.error
                          : outstanding < 0
                              ? AppColors.info
                              : AppColors.success,
                      outstanding > 0
                          ? _loc.get('customerOwesYou')
                          : outstanding < 0
                              ? _loc.get('youOweCustomer')
                              : _loc.get('customerSettled'),
                    ),
                  ],
                ),
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
                  Tab(icon: const Icon(Icons.receipt_long, size: 20), text: _loc.get('invoices')),
                  Tab(icon: const Icon(Icons.payments_outlined, size: 20), text: _loc.get('customerPayments')),
                  Tab(icon: const Icon(Icons.account_balance, size: 20), text: _loc.get('accountLedger')),
                ],
              ),
            ),

            // ─── Tab Content ───
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildInvoicesTab(),
                        _buildPaymentsTab(),
                        _buildLedgerTab(),
                      ],
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
  Widget _buildInvoicesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_loc.get('total')}: ${_invoices.length}',
                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _invoices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 56, color: AppColors.textHint),
                      const SizedBox(height: 12),
                      Text(_loc.get('noInvoicesFound'), style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _invoices.length,
                  itemBuilder: (context, index) => _buildInvoiceCard(_invoices[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildInvoiceCard(Invoice inv) {
    final remaining = inv.remainingAmount;
    final progress = inv.finalAmount > 0 ? (inv.paidAmount / inv.finalAmount).clamp(0.0, 1.0) : 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: (inv.paidAmount > inv.finalAmount
                    ? AppColors.info
                    : inv.isFullyPaid
                        ? AppColors.success
                        : inv.isPartiallyPaid
                            ? Colors.orange
                            : AppColors.error)
                .withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.receipt, color: AppColors.textHint, size: 20),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 12, color: AppColors.textHint),
                  const SizedBox(width: 4),
                  Text(
                    inv.createdDate != null ? _dateFormat.format(inv.createdDate!) : '',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 16),
                  Text(_loc.formatCurrency(inv.finalAmount), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 6),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(
                    inv.paidAmount > inv.finalAmount
                        ? AppColors.info
                        : inv.isFullyPaid
                            ? AppColors.success
                            : Colors.orange,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_loc.get('paid')}: ${_loc.formatCurrency(inv.paidAmount)}',
                    style: TextStyle(fontSize: 11, color: AppColors.success),
                  ),
                  Text(
                    '${_loc.get('remainingAmount')}: ${_loc.formatCurrency(remaining < 0 ? 0 : remaining)}',
                    style: TextStyle(fontSize: 11, color: remaining > 0 ? AppColors.error : AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                const Divider(),
                // Payment history for this invoice
                FutureBuilder<List<CustomerPayment>>(
                  future: di.sl<CustomerRepository>().getPaymentsByInvoice(inv.id!),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(8),
                        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                      );
                    }
                    final invoicePayments = snapshot.data ?? [];
                    if (invoicePayments.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(_loc.get('noPaymentsYet'), style: TextStyle(color: AppColors.textHint, fontSize: 12)),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_loc.get('paymentHistory'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        const SizedBox(height: 6),
                        ...invoicePayments.map((p) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              _buildPaymentMethodBadge(p),
                              const SizedBox(width: 8),
                              Text(_loc.formatCurrency(p.amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(width: 8),
                              Text(_dateFormat.format(p.paymentDate), style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              if (p.chequeNumber != null) ...[
                                const SizedBox(width: 8),
                                Text('#${p.chequeNumber}', style: TextStyle(fontSize: 11, color: AppColors.info)),
                              ],
                              const Spacer(),
                              InkWell(
                                onTap: () => _confirmDeletePayment(p),
                                child: Icon(Icons.delete_outline, size: 18, color: AppColors.error.withOpacity(0.7)),
                              ),
                            ],
                          ),
                        )),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                // Record payment button
                if (inv.remainingAmount > 0)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showRecordPaymentDialog(inv),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(_loc.get('recordPayment')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.success,
                        side: const BorderSide(color: AppColors.success),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  )
                else if (inv.paidAmount > inv.finalAmount)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: AppColors.info),
                        const SizedBox(width: 6),
                        Text(
                          '${_loc.get('overpaid')}: ${_loc.formatCurrency(inv.paidAmount - inv.finalAmount)}',
                          style: const TextStyle(color: AppColors.info, fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  TAB 2: PAYMENTS
  // ─────────────────────────────────────────────────────────────────
  Widget _buildPaymentsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_loc.get('total')}: ${_payments.length}',
                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        // Payment breakdown chips
        if (_payments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                _paymentBreakdownChip(
                  Icons.payments_outlined,
                  _loc.get('cashPayment'),
                  _loc.formatCurrency(
                    _payments.where((p) => p.isCash).fold<double>(0, (sum, p) => sum + p.amount),
                  ),
                  AppColors.success,
                ),
                const SizedBox(width: 8),
                _paymentBreakdownChip(
                  Icons.description_outlined,
                  _loc.get('chequePayment'),
                  _loc.formatCurrency(
                    _payments.where((p) => p.isCheque).fold<double>(0, (sum, p) => sum + p.amount),
                  ),
                  AppColors.info,
                ),
              ],
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child: _payments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.payments_outlined, size: 56, color: AppColors.textHint),
                      const SizedBox(height: 12),
                      Text(_loc.get('noCustomerPayments'), style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _payments.length,
                  itemBuilder: (context, index) => _buildPaymentCard(_payments[index]),
                ),
        ),
      ],
    );
  }

  Widget _paymentBreakdownChip(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard(CustomerPayment payment) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: (payment.isCheque ? AppColors.info : AppColors.success).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            payment.isCheque ? Icons.description_outlined : Icons.payments_outlined,
            color: payment.isCheque ? AppColors.info : AppColors.success,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Text(
              _loc.formatCurrency(payment.amount),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(width: 8),
            _buildPaymentMethodBadge(payment),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(Icons.receipt_outlined, size: 12, color: AppColors.textHint),
              const SizedBox(width: 4),
              Text(
                payment.invoiceNumber != null ? '#${payment.invoiceNumber}' : '',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 12),
              Icon(Icons.calendar_today, size: 12, color: AppColors.textHint),
              const SizedBox(width: 4),
              Text(
                _dateFormat.format(payment.paymentDate),
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              if (payment.chequeNumber != null) ...[
                const SizedBox(width: 12),
                Icon(Icons.pin_outlined, size: 12, color: AppColors.info),
                const SizedBox(width: 4),
                Text('#${payment.chequeNumber}', style: TextStyle(fontSize: 12, color: AppColors.info)),
              ],
            ],
          ),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, size: 20, color: AppColors.error.withOpacity(0.7)),
          onPressed: () => _confirmDeletePayment(payment),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  TAB 3: ACCOUNT LEDGER
  // ─────────────────────────────────────────────────────────────────
  Widget _buildLedgerTab() {
    // Build ledger entries from invoices and payments, sorted by date
    final List<_LedgerEntry> entries = [];

    for (final inv in _invoices) {
      entries.add(_LedgerEntry(
        date: inv.createdDate ?? DateTime.now(),
        type: 'invoice',
        reference: '#${inv.invoiceNumber}',
        debit: inv.finalAmount,
        credit: 0,
        description: '${_loc.get('invoiceEntry')} #${inv.invoiceNumber}',
      ));
    }

    for (final p in _payments) {
      entries.add(_LedgerEntry(
        date: p.paymentDate,
        type: 'payment',
        reference: p.invoiceNumber != null ? '#${p.invoiceNumber}' : '',
        debit: 0,
        credit: p.amount,
        description: '${_loc.get('paymentEntry')} - ${p.isCheque ? _loc.get('chequePayment') : _loc.get('cashPayment')}${p.chequeNumber != null ? ' #${p.chequeNumber}' : ''}',
      ));
    }

    // Sort by date ascending
    entries.sort((a, b) => a.date.compareTo(b.date));

    // Calculate running balance
    double runningBalance = 0;
    for (final entry in entries) {
      runningBalance += entry.debit - entry.credit;
      entry.balance = runningBalance;
    }

    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance, size: 56, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text(_loc.get('noTransactions'), style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Ledger header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.05),
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              SizedBox(width: 85, child: Text(_loc.get('date'), style: _headerStyle)),
              SizedBox(width: 50, child: Text(_loc.get('transactionType'), style: _headerStyle)),
              Expanded(child: Text(_loc.get('description'), style: _headerStyle)),
              SizedBox(width: 90, child: Text(_loc.get('debit'), style: _headerStyle, textAlign: TextAlign.end)),
              SizedBox(width: 90, child: Text(_loc.get('creditEntry'), style: _headerStyle, textAlign: TextAlign.end)),
              SizedBox(width: 100, child: Text(_loc.get('runningBalance'), style: _headerStyle, textAlign: TextAlign.end)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final isInvoice = entry.type == 'invoice';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: index.isEven ? Colors.white : Colors.grey.shade50,
                  border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 85,
                      child: Text(_dateFormat.format(entry.date), style: const TextStyle(fontSize: 12)),
                    ),
                    SizedBox(
                      width: 50,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isInvoice ? AppColors.error : AppColors.success).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isInvoice ? _loc.get('debit') : _loc.get('creditEntry'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isInvoice ? AppColors.error : AppColors.success,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(entry.description, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                    ),
                    SizedBox(
                      width: 90,
                      child: Text(
                        entry.debit > 0 ? _loc.formatCurrency(entry.debit) : '-',
                        style: TextStyle(fontSize: 12, color: AppColors.error, fontWeight: entry.debit > 0 ? FontWeight.w600 : FontWeight.normal),
                        textAlign: TextAlign.end,
                      ),
                    ),
                    SizedBox(
                      width: 90,
                      child: Text(
                        entry.credit > 0 ? _loc.formatCurrency(entry.credit) : '-',
                        style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: entry.credit > 0 ? FontWeight.w600 : FontWeight.normal),
                        textAlign: TextAlign.end,
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text(
                        _loc.formatCurrency(entry.balance),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: entry.balance > 0 ? AppColors.error : entry.balance < 0 ? AppColors.success : AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        // Ledger footer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.05),
            border: Border(top: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            children: [
              const Spacer(),
              Text(
                '${_loc.get('customerBalance')}: ',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              Text(
                _loc.formatCurrency(entries.isNotEmpty ? entries.last.balance : 0),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: (entries.isNotEmpty && entries.last.balance > 0)
                      ? AppColors.error
                      : (entries.isNotEmpty && entries.last.balance < 0)
                          ? AppColors.success
                          : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  TextStyle get _headerStyle => TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 11,
    color: AppColors.textSecondary,
  );
}

class _LedgerEntry {
  final DateTime date;
  final String type;
  final String reference;
  final double debit;
  final double credit;
  final String description;
  double balance = 0;

  _LedgerEntry({
    required this.date,
    required this.type,
    required this.reference,
    required this.debit,
    required this.credit,
    required this.description,
  });
}
