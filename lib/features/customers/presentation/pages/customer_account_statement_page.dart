import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/services/pdf_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../invoices/domain/entities/invoice.dart';
import '../../../invoices/domain/entities/sale_item.dart';
import '../../../invoices/domain/repositories/invoice_repository.dart';
import '../../../invoices/presentation/bloc/invoice_bloc.dart';
import '../../../settings/domain/repositories/settings_repository.dart';
import '../../domain/entities/customer.dart';
import '../bloc/customer_bloc.dart';

class CustomerAccountStatementPage extends StatefulWidget {
  final Customer customer;

  const CustomerAccountStatementPage({super.key, required this.customer});

  @override
  State<CustomerAccountStatementPage> createState() =>
      _CustomerAccountStatementPageState();
}

class _CustomerAccountStatementPageState
    extends State<CustomerAccountStatementPage> {
  List<Invoice> _invoices = [];
  Map<int, List<SaleItem>> _invoiceItems = {};
  Set<int> _expandedInvoices = {};
  bool _isLoading = true;
  final _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  final _localization = LocalizationService();

  // Summary data
  double _totalPurchases = 0;
  double _totalPaid = 0;
  double _totalRemaining = 0;
  int _paidInvoiceCount = 0;
  int _unpaidInvoiceCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final invoiceRepo = di.sl<InvoiceRepository>();
      _invoices = await invoiceRepo.getInvoicesByCustomer(widget.customer.id!);

      // Load items for all invoices
      _invoiceItems.clear();
      for (final invoice in _invoices) {
        if (invoice.id != null) {
          final items = await invoiceRepo.getInvoiceItems(invoice.id!);
          _invoiceItems[invoice.id!] = items;
        }
      }

      // Calculate summary
      _totalPurchases = 0;
      _totalPaid = 0;
      _totalRemaining = 0;
      _paidInvoiceCount = 0;
      _unpaidInvoiceCount = 0;

      for (final invoice in _invoices) {
        _totalPurchases += invoice.finalAmount;
        _totalPaid += invoice.paidAmount;
        _totalRemaining += invoice.remainingAmount;
        if (invoice.isFullyPaid) {
          _paidInvoiceCount++;
        } else {
          _unpaidInvoiceCount++;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_localization.get('error')}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _toggleExpand(int invoiceId) {
    setState(() {
      if (_expandedInvoices.contains(invoiceId)) {
        _expandedInvoices.remove(invoiceId);
      } else {
        _expandedInvoices.add(invoiceId);
      }
    });
  }

  void _expandAll() {
    setState(() {
      _expandedInvoices = _invoices
          .where((inv) => inv.id != null)
          .map((inv) => inv.id!)
          .toSet();
    });
  }

  void _collapseAll() {
    setState(() {
      _expandedInvoices.clear();
    });
  }

  Future<void> _exportToPdf() async {
    if (_invoices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_localization.get('noInvoicesToExport')),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final pdfService = di.sl<PdfService>();
      final settingsRepo = di.sl<SettingsRepository>();
      final settings = await settingsRepo.getSettings();

      final filePath = await pdfService.saveCustomerStatementPdf(
        customer: widget.customer,
        invoices: _invoices,
        invoiceItems: _invoiceItems,
        storeSettings: settings,
      );

      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_localization.get('pdfSavedTo')}: $filePath'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 5),
          ),
        );
      }
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
    }
  }

  void _recordPayment(Invoice invoice) {
    final paymentController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final remaining = invoice.remainingAmount;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${_localization.get('recordPayment')} - #${invoice.invoiceNumber}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_localization.get('remainingAmount')}: ₪${remaining.toStringAsFixed(2)}',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: paymentController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: _localization.get('paymentAmount'),
                  prefixText: '₪ ',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return _localization.get('required');
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return _localization.get('invalidNumber');
                  }
                  if (amount > remaining) {
                    return '${_localization.get('max')}: ₪${remaining.toStringAsFixed(2)}';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_localization.get('cancel')),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _updatePayment(invoice.id!, invoice.finalAmount);
            },
            child: Text(_localization.get('payFull')),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(dialogContext);
                final amount = double.tryParse(paymentController.text) ?? 0;
                _updatePayment(invoice.id!, invoice.paidAmount + amount);
              }
            },
            child: Text(_localization.get('record')),
          ),
        ],
      ),
    );
  }

  void _updatePayment(int invoiceId, double newPaidAmount) {
    di.sl<InvoiceBloc>().add(
      InvoiceUpdatePaidAmount(invoiceId: invoiceId, paidAmount: newPaidAmount),
    );
    // Refresh both customer and invoice data
    context.read<CustomerBloc>().add(CustomerRefresh());
    di.sl<InvoiceBloc>().add(InvoiceRefresh());
    _loadData();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_localization.get('paymentRecorded')),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _confirmDeleteInvoice(Invoice invoice) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_localization.get('deleteInvoice')),
        content: Text(
          '${_localization.get('confirmDeleteInvoice')} #${invoice.invoiceNumber}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_localization.get('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final invoiceRepo = di.sl<InvoiceRepository>();
                await invoiceRepo.deleteInvoice(invoice.id!);
                if (!mounted) return;
                // Refresh both customer and invoice data
                context.read<CustomerBloc>().add(CustomerRefresh());
                di.sl<InvoiceBloc>().add(InvoiceRefresh());
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_localization.get('invoiceDeleted')),
                    backgroundColor: AppColors.success,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${_localization.get('error')}: $e'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
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
        title: Text(_localization.get('accountStatement')),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _collapseAll,
            icon: const Icon(Icons.unfold_less),
            tooltip: _localization.get('collapseAll'),
          ),
          IconButton(
            onPressed: _expandAll,
            icon: const Icon(Icons.unfold_more),
            tooltip: _localization.get('expandAll'),
          ),
          IconButton(
            onPressed: _exportToPdf,
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: _localization.get('exportPdf'),
          ),
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: _localization.get('refresh'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  children: [
                    _buildCustomerHeader(),
                    _buildSummaryCards(),
                    Expanded(child: _buildInvoicesList()),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCustomerHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.primary,
            child: Text(
              widget.customer.name.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.customer.name,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                if (widget.customer.phone != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.phone,
                            size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          widget.customer.phone!,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (widget.customer.email != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.email,
                            size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          widget.customer.email!,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (widget.customer.address != null)
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.customer.address!,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            decoration: BoxDecoration(
              color: _totalRemaining > 0
                  ? AppColors.error.withOpacity(0.1)
                  : AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _totalRemaining > 0 ? AppColors.error : AppColors.success,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Text(
                  _totalRemaining > 0
                      ? _localization.get('totalDebt')
                      : _localization.get('balance'),
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  '₪${_totalRemaining.abs().toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: _totalRemaining > 0
                        ? AppColors.error
                        : AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 700;
          final cards = [
            _buildSummaryCard(
              icon: Icons.receipt_long,
              title: _localization.get('totalInvoices'),
              value: '${_invoices.length}',
              color: AppColors.primary,
            ),
            _buildSummaryCard(
              icon: Icons.shopping_cart,
              title: _localization.get('totalPurchases'),
              value: '₪${_totalPurchases.toStringAsFixed(2)}',
              color: AppColors.info,
            ),
            _buildSummaryCard(
              icon: Icons.payments,
              title: _localization.get('totalPaid'),
              value: '₪${_totalPaid.toStringAsFixed(2)}',
              color: AppColors.success,
            ),
            _buildSummaryCard(
              icon: Icons.check_circle,
              title: _localization.get('paidInvoices'),
              value: '$_paidInvoiceCount',
              color: AppColors.success,
            ),
            _buildSummaryCard(
              icon: Icons.warning,
              title: _localization.get('unpaidInvoices'),
              value: '$_unpaidInvoiceCount',
              color: AppColors.error,
            ),
          ];

          if (isNarrow) {
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: cards,
            );
          }
          return Row(
            children: cards
                .expand((card) => [card, const SizedBox(width: 16)])
                .toList()
              ..removeLast(),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
    );
  }

  Widget _buildInvoicesList() {
    if (_invoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 80, color: AppColors.disabled.withOpacity(0.5)),
            const SizedBox(height: 20),
            Text(
              _localization.get('noInvoicesFound'),
              style: TextStyle(
                fontSize: 18,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      itemCount: _invoices.length,
      itemBuilder: (context, index) {
        final invoice = _invoices[index];
        final isExpanded = _expandedInvoices.contains(invoice.id);
        final items = _invoiceItems[invoice.id] ?? [];

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // Invoice header
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _toggleExpand(invoice.id!),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_right,
                        color: AppColors.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.receipt, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  '#${invoice.invoiceNumber}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                _buildStatusBadge(invoice.paymentStatus),
                                _buildPaymentMethodBadge(invoice.paymentMethod),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _dateFormat.format(invoice.createdAt),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${items.length} ${_localization.get('items')}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₪${invoice.finalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (invoice.remainingAmount > 0)
                            Text(
                              '${_localization.get('remaining')}: ₪${invoice.remainingAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (invoice.discountAmount > 0)
                            Text(
                              '${_localization.get('discount')}: ₪${invoice.discountAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: AppColors.success,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          switch (value) {
                            case 'payment':
                              _recordPayment(invoice);
                              break;
                            case 'delete':
                              _confirmDeleteInvoice(invoice);
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          if (!invoice.isFullyPaid)
                            PopupMenuItem(
                              value: 'payment',
                              child: Row(
                                children: [
                                  const Icon(Icons.payment, color: AppColors.success),
                                  const SizedBox(width: 8),
                                  Text(_localization.get('recordPayment')),
                                ],
                              ),
                            ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                const Icon(Icons.delete, color: AppColors.error),
                                const SizedBox(width: 8),
                                Text(
                                  _localization.get('delete'),
                                  style: const TextStyle(color: AppColors.error),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Expanded invoice items
              if (isExpanded) ...[
                const Divider(height: 1),
                _buildInvoiceDetails(invoice, items),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'paid':
        color = AppColors.success;
        label = _localization.get('paid');
        break;
      case 'partial':
        color = AppColors.warning;
        label = _localization.get('partial');
        break;
      default:
        color = AppColors.error;
        label = _localization.get('unpaid');
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildPaymentMethodBadge(String method) {
    final color = method == 'cash' ? AppColors.success : AppColors.info;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        method.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildInvoiceDetails(Invoice invoice, List<SaleItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Items table header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 50,
                  child: Text(
                    '#',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    _localization.get('productName'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    _localization.get('barcode'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Text(
                    _localization.get('quantity'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Text(
                    _localization.get('unitPrice'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Text(
                    _localization.get('total'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Items rows
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: index.isEven ? Colors.white : Colors.grey.shade100,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 50,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      item.productName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.barcode ?? '-',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${item.quantity}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '₪${item.salePrice.toStringAsFixed(2)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '₪${item.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 20),
          // Summary
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildSummaryRow(
                  _localization.get('subtotal'),
                  '₪${invoice.totalAmount.toStringAsFixed(2)}',
                ),
                if (invoice.discountAmount > 0)
                  _buildSummaryRow(
                    _localization.get('discount'),
                    '-₪${invoice.discountAmount.toStringAsFixed(2)}',
                    valueColor: AppColors.success,
                  ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1),
                ),
                _buildSummaryRow(
                  _localization.get('total'),
                  '₪${invoice.finalAmount.toStringAsFixed(2)}',
                  isBold: true,
                ),
                const SizedBox(height: 8),
                _buildSummaryRow(
                  _localization.get('paidAmount'),
                  '₪${invoice.paidAmount.toStringAsFixed(2)}',
                  valueColor: AppColors.success,
                ),
                _buildSummaryRow(
                  _localization.get('remainingAmount'),
                  '₪${invoice.remainingAmount.toStringAsFixed(2)}',
                  valueColor:
                      invoice.remainingAmount > 0 ? AppColors.error : AppColors.success,
                  isBold: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value,
      {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              fontSize: isBold ? 16 : 15,
              color: isBold ? null : AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              fontSize: isBold ? 18 : 15,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
