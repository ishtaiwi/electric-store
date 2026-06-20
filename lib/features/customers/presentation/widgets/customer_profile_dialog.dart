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
import 'customer_financial_dialog.dart';
import 'customer_form_dialog.dart';

class CustomerProfileDialog extends StatefulWidget {
  final Customer customer;

  const CustomerProfileDialog({super.key, required this.customer});

  @override
  State<CustomerProfileDialog> createState() => _CustomerProfileDialogState();
}

class _CustomerProfileDialogState extends State<CustomerProfileDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Invoice> _invoices = [];
  bool _isLoading = true;
  final _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInvoices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    try {
      final invoiceRepo = di.sl<InvoiceRepository>();
      _invoices = await invoiceRepo.getInvoicesByCustomer(widget.customer.id!);
    } catch (e) {
      // Handle error
    }
    setState(() => _isLoading = false);
  }

  void _editCustomer() {
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<CustomerBloc>(),
        child: CustomerFormDialog(customer: widget.customer),
      ),
    ).then((_) {
      if (mounted) Navigator.pop(context); // Close profile after edit
    });
  }

  Future<void> _exportCustomerStatementPdf() async {
    if (_invoices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocalizationService().get('noInvoicesToExport')),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final pdfService = di.sl<PdfService>();
      final invoiceRepo = di.sl<InvoiceRepository>();
      final settingsRepo = di.sl<SettingsRepository>();
      
      // Get all invoice items
      final Map<int, List<SaleItem>> invoiceItems = {};
      for (final invoice in _invoices) {
        if (invoice.id != null) {
          final items = await invoiceRepo.getInvoiceItems(invoice.id!);
          invoiceItems[invoice.id!] = items;
        }
      }
      
      // Get store settings
      final settings = await settingsRepo.getSettings();
      
      // Generate PDF
      final filePath = await pdfService.saveCustomerStatementPdf(
        customer: widget.customer,
        invoices: _invoices,
        invoiceItems: invoiceItems,
        storeSettings: settings,
      );
      
      // Close loading dialog
      if (mounted) Navigator.pop(context);
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${LocalizationService().get('pdfSavedTo')}: $filePath'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: LocalizationService().get('ok'),
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);
      
      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${LocalizationService().get('error')}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _createInvoiceForCustomer() {
    Navigator.pop(context); // Close profile dialog
    // Navigate to sales page with customer pre-selected
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${LocalizationService().get('goToSalesTab')} ${widget.customer.name}'),
        backgroundColor: AppColors.info,
        action: SnackBarAction(
          label: LocalizationService().get('ok'),
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _confirmDeleteInvoice(Invoice invoice) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(LocalizationService().get('deleteInvoice')),
        content: Text(
          'Are you sure you want to delete invoice #${invoice.invoiceNumber}?\n\n'
          'This will restore the stock quantities.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(LocalizationService().get('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final invoiceRepo = di.sl<InvoiceRepository>();
                await invoiceRepo.deleteInvoice(invoice.id!);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(LocalizationService().get('invoiceDeleted')),
                    backgroundColor: AppColors.success,
                  ),
                );
                // Refresh both customer and invoice data
                context.read<CustomerBloc>().add(CustomerRefresh());
                di.sl<InvoiceBloc>().add(InvoiceRefresh());
                _loadInvoices();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${LocalizationService().get('errorDeleting')} $e'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(LocalizationService().get('delete')),
          ),
        ],
      ),
    );
  }

  void _showInvoiceDetails(Invoice invoice) {
    showDialog(
      context: context,
      builder: (dialogContext) => _InvoiceDetailDialog(
        invoice: invoice,
        onEdit: () => _editInvoice(invoice),
        onDelete: () => _confirmDeleteInvoice(invoice),
        onPaymentRecorded: (newPaidAmount) {
          if (invoice.id != null) {
            _recordPayment(invoice.id!, newPaidAmount);
          }
        },
      ),
    );
  }

  void _recordPayment(int invoiceId, double newPaidAmount) {
    // Update invoice paid amount using singleton
    di.sl<InvoiceBloc>().add(
      InvoiceUpdatePaidAmount(invoiceId: invoiceId, paidAmount: newPaidAmount),
    );
    // Refresh both customer and invoice data
    context.read<CustomerBloc>().add(CustomerRefresh());
    di.sl<InvoiceBloc>().add(InvoiceRefresh());
    // Reload invoices
    _loadInvoices();
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(LocalizationService().get('paymentRecorded')),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _editInvoice(Invoice invoice) {
    // Show edit dialog - for now just show a message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${LocalizationService().get('editing')} #${invoice.invoiceNumber}'),
        backgroundColor: AppColors.info,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 750,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    widget.customer.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.customer.name,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.customer.phone != null)
                        Row(
                          children: [
                            const Icon(Icons.phone, size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              widget.customer.phone!,
                              style: const TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      if (widget.customer.email != null)
                        Row(
                          children: [
                            const Icon(Icons.email, size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              widget.customer.email!,
                              style: const TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                // Balance display
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: widget.customer.balance > 0
                        ? AppColors.error.withOpacity(0.1)
                        : AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: widget.customer.balance > 0 ? AppColors.error : AppColors.success,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        widget.customer.balance > 0 ? LocalizationService().get('debt') : LocalizationService().get('balance'),
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        '₪${widget.customer.balance.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: widget.customer.balance > 0
                              ? AppColors.error
                              : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _createInvoiceForCustomer,
                  icon: const Icon(Icons.add),
                  label: Text(LocalizationService().get('newInvoice')),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _editCustomer,
                  icon: const Icon(Icons.edit),
                  label: Text(LocalizationService().get('edit')),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (dialogContext) => BlocProvider.value(
                        value: context.read<CustomerBloc>(),
                        child: CustomerFinancialDialog(customer: widget.customer),
                      ),
                    ).then((_) => _loadInvoices());
                  },
                  icon: const Icon(Icons.account_balance_wallet, size: 18),
                  label: Text(LocalizationService().get('customerFinancial')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _exportCustomerStatementPdf,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: Text(LocalizationService().get('exportPdf')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.info,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tabs
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: LocalizationService().get('invoices')),
                Tab(text: LocalizationService().get('details')),
              ],
            ),
            const SizedBox(height: 8),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildInvoicesTab(),
                  _buildDetailsTab(),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildInvoicesTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_invoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long, size: 64, color: AppColors.disabled),
            const SizedBox(height: 16),
            Text(LocalizationService().get('noInvoicesFound')),
            const SizedBox(height: 8),
            Text(
              LocalizationService().get('createFirstInvoice'),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInvoices,
      child: ListView.separated(
        itemCount: _invoices.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final invoice = _invoices[index];
          return ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.receipt, color: AppColors.primary),
            ),
            title: Text(
              'Invoice #${invoice.invoiceNumber}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(_dateFormat.format(invoice.createdAt)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₪${invoice.finalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Payment status badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getPaymentStatusColor(invoice.paymentStatus).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getPaymentStatusLabel(invoice.paymentStatus),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getPaymentStatusColor(invoice.paymentStatus),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Payment method badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: invoice.paymentMethod == 'cash'
                                ? AppColors.success.withOpacity(0.1)
                                : AppColors.info.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            invoice.paymentMethod.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: invoice.paymentMethod == 'cash'
                                  ? AppColors.success
                                  : AppColors.info,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'view':
                        _showInvoiceDetails(invoice);
                        break;
                      case 'delete':
                        _confirmDeleteInvoice(invoice);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: [
                          const Icon(Icons.visibility),
                          const SizedBox(width: 8),
                          Text(LocalizationService().get('viewDetails')),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete, color: AppColors.error),
                          const SizedBox(width: 8),
                          Text(LocalizationService().get('delete'), style: const TextStyle(color: AppColors.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            onTap: () => _showInvoiceDetails(invoice),
          );
        },
      ),
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow(LocalizationService().get('name'), widget.customer.name),
          _buildDetailRow(LocalizationService().get('phone'), widget.customer.phone ?? '-'),
          _buildDetailRow(LocalizationService().get('email'), widget.customer.email ?? '-'),
          _buildDetailRow(LocalizationService().get('address'), widget.customer.address ?? '-'),
          _buildDetailRow(LocalizationService().get('totalInvoices'), '${_invoices.length}'),
          _buildDetailRow(
            LocalizationService().get('totalPurchases'),
            '₪${_invoices.fold<double>(0, (sum, inv) => sum + inv.finalAmount).toStringAsFixed(2)}',
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
  
  String _getPaymentStatusLabel(String status) {
    switch (status) {
      case 'overpaid':
        return LocalizationService().get('overpaid');
      case 'paid':
        return LocalizationService().get('paid');
      case 'partial':
        return LocalizationService().get('partial');
      case 'unpaid':
        return LocalizationService().get('unpaid');
      default:
        return status;
    }
  }
  
  Color _getPaymentStatusColor(String status) {
    switch (status) {
      case 'overpaid':
        return AppColors.info;
      case 'paid':
        return AppColors.success;
      case 'partial':
        return AppColors.warning;
      case 'unpaid':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }
}

class _InvoiceDetailDialog extends StatefulWidget {
  final Invoice invoice;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(double newPaidAmount) onPaymentRecorded;

  const _InvoiceDetailDialog({
    required this.invoice,
    required this.onEdit,
    required this.onDelete,
    required this.onPaymentRecorded,
  });

  @override
  State<_InvoiceDetailDialog> createState() => _InvoiceDetailDialogState();
}

class _InvoiceDetailDialogState extends State<_InvoiceDetailDialog> {
  final _paymentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _paymentController.dispose();
    super.dispose();
  }

  void _recordPayment() {
    if (_formKey.currentState?.validate() ?? false) {
      final paymentAmount = double.tryParse(_paymentController.text) ?? 0;
      final newPaidAmount = widget.invoice.paidAmount + paymentAmount;
      Navigator.pop(context);
      widget.onPaymentRecorded(newPaidAmount);
    }
  }

  void _payFull() {
    Navigator.pop(context);
    widget.onPaymentRecorded(widget.invoice.finalAmount);
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final remaining = widget.invoice.remainingAmount;
    final isPaid = remaining <= 0;

    final loc = LocalizationService();
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 30),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 540,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.receipt_long, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          'Invoice #${widget.invoice.invoiceNumber}',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getPaymentStatusLabel(widget.invoice.paymentStatus),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.white70),
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onDelete();
                    },
                    tooltip: loc.get('delete'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRow(loc.get('date'), dateFormat.format(widget.invoice.createdAt)),
                      _buildRow(loc.get('customerName'), widget.invoice.customerName ?? 'Walk-in'),
                      _buildRow(loc.get('payment'), widget.invoice.paymentMethod.toUpperCase()),
                      const Divider(),
                      _buildRow(loc.get('subtotal'), '₪${widget.invoice.totalAmount.toStringAsFixed(2)}'),
                      if (widget.invoice.discountAmount > 0)
                        _buildRow(loc.get('discount'), '-₪${widget.invoice.discountAmount.toStringAsFixed(2)}'),
                      _buildRow(
                        loc.get('total'),
                        '₪${widget.invoice.finalAmount.toStringAsFixed(2)}',
                        isBold: true,
                      ),
                      const Divider(),
                      // Payment breakdown
                      _buildRow(
                        loc.get('paidAmount'),
                        '₪${widget.invoice.paidAmount.toStringAsFixed(2)}',
                        color: AppColors.success,
                      ),
                      _buildRow(
                        loc.get('remainingAmount'),
                        '₪${remaining.toStringAsFixed(2)}',
                        color: remaining > 0 ? AppColors.error : AppColors.success,
                        isBold: true,
                      ),
                      if (!isPaid) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          loc.get('recordPayment'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _paymentController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: loc.get('paymentAmount'),
                                  hintText: loc.get('enterPaymentAmount'),
                                  prefixText: '₪ ',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return loc.get('required');
                                  }
                                  final amount = double.tryParse(value);
                                  if (amount == null || amount <= 0) {
                                    return loc.get('invalidNumber');
                                  }
                                  if (amount > remaining) {
                                    return '${loc.get('max')}: ₪${remaining.toStringAsFixed(2)}';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _recordPayment,
                              child: Text(loc.get('record')),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _payFull,
                            icon: const Icon(Icons.check_circle),
                            label: Text('${loc.get('payFull')} (₪${remaining.toStringAsFixed(2)})'),
                          ),
                        ),
                      ],
                      const Divider(),
                      _buildRow(loc.get('profit'), '₪${widget.invoice.totalProfit.toStringAsFixed(2)}'),
                    ],
                  ),
                ),
              ),
            ),
            // Actions
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(loc.get('close')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 18 : 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _getPaymentStatusLabel(String status) {
    switch (status) {
      case 'overpaid':
        return LocalizationService().get('overpaid');
      case 'paid':
        return LocalizationService().get('paid');
      case 'partial':
        return LocalizationService().get('partial');
      case 'unpaid':
        return LocalizationService().get('unpaid');
      default:
        return status;
    }
  }
}
