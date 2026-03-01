import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../customers/presentation/bloc/customer_bloc.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/sale_item.dart';
import '../bloc/invoice_bloc.dart';

class InvoiceDetailsDialog extends StatefulWidget {
  final Invoice invoice;

  const InvoiceDetailsDialog({super.key, required this.invoice});

  @override
  State<InvoiceDetailsDialog> createState() => _InvoiceDetailsDialogState();
}

class _InvoiceDetailsDialogState extends State<InvoiceDetailsDialog> {
  final _paymentController = TextEditingController();
  final _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _showPaymentForm = false;
  bool _isEditingNotes = false;

  @override
  void initState() {
    super.initState();
    _notesController.text = widget.invoice.notes ?? '';
  }

  @override
  void dispose() {
    _paymentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _recordPayment() {
    if (_formKey.currentState?.validate() ?? false) {
      final paymentAmount = double.tryParse(_paymentController.text) ?? 0;
      final newPaidAmount = widget.invoice.paidAmount + paymentAmount;
      context.read<InvoiceBloc>().add(
        InvoiceUpdatePaidAmount(invoiceId: widget.invoice.id!, paidAmount: newPaidAmount),
      );
      // Also refresh customers to update their balance
      di.sl<CustomerBloc>().add(CustomerRefresh());
      Navigator.pop(context);
    }
  }

  void _payFull() {
    context.read<InvoiceBloc>().add(
      InvoiceUpdatePaidAmount(invoiceId: widget.invoice.id!, paidAmount: widget.invoice.finalAmount),
    );
    // Also refresh customers to update their balance
    di.sl<CustomerBloc>().add(CustomerRefresh());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return BlocBuilder<InvoiceBloc, InvoiceState>(
      builder: (context, state) {
        List<SaleItem> items = [];
        
        if (state is InvoiceDetailsLoaded) {
          items = state.items;
        }

        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${LocalizationService().get('invoiceNumber')} #${widget.invoice.id}'),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.print),
                    onPressed: () {
                      context.read<InvoiceBloc>().add(InvoicePrint(widget.invoice.id!));
                    },
                    tooltip: LocalizationService().get('printInvoice'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    tooltip: LocalizationService().get('close'),
                  ),
                ],
              ),
            ],
          ),
          content: SizedBox(
            width: 600,
            height: 500,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Invoice header info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _InfoItem(
                            icon: Icons.calendar_today,
                            label: LocalizationService().get('date'),
                            value: dateFormat.format(widget.invoice.createdAt),
                          ),
                          _InfoItem(
                            icon: Icons.person,
                            label: LocalizationService().get('customerName'),
                            value: widget.invoice.customerName ?? LocalizationService().get('walkInCustomer'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _InfoItem(
                            icon: Icons.payment,
                            label: LocalizationService().get('paymentMethod'),
                            value: _getPaymentMethodLabel(widget.invoice.paymentMethod),
                          ),
                          _InfoItem(
                            icon: Icons.check_circle_outline,
                            label: LocalizationService().get('status'),
                            value: _getPaymentStatusLabel(widget.invoice.paymentStatus),
                            valueColor: _getPaymentStatusColor(widget.invoice.paymentStatus),
                          ),
                          _InfoItem(
                            icon: Icons.person_outline,
                            label: LocalizationService().get('cashier'),
                            value: widget.invoice.userName ?? LocalizationService().get('unknown'),
                          ),
                        ],
                      ),
                      if (!widget.invoice.isFullyPaid) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  Column(
                                    children: [
                                      Text(LocalizationService().get('paidAmount'), style: const TextStyle(fontSize: 12)),
                                      Text('₪${widget.invoice.paidAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success)),
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      Text(LocalizationService().get('remaining'), style: const TextStyle(fontSize: 12)),
                                      Text('₪${widget.invoice.remainingAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (!_showPaymentForm)
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => setState(() => _showPaymentForm = true),
                                    icon: const Icon(Icons.payment),
                                    label: Text(LocalizationService().get('recordPayment')),
                                  ),
                                )
                              else
                                Form(
                                  key: _formKey,
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              controller: _paymentController,
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              decoration: InputDecoration(
                                                labelText: LocalizationService().get('paymentAmount'),
                                                prefixText: '₪ ',
                                                border: const OutlineInputBorder(),
                                                isDense: true,
                                              ),
                                              validator: (value) {
                                                if (value == null || value.isEmpty) {
                                                  return LocalizationService().get('required');
                                                }
                                                final amount = double.tryParse(value);
                                                if (amount == null || amount <= 0) {
                                                  return LocalizationService().get('invalidNumber');
                                                }
                                                if (amount > widget.invoice.remainingAmount) {
                                                  return '${LocalizationService().get('max')}: ₪${widget.invoice.remainingAmount.toStringAsFixed(2)}';
                                                }
                                                return null;
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            onPressed: _recordPayment,
                                            child: Text(LocalizationService().get('record')),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: _payFull,
                                          icon: const Icon(Icons.check_circle),
                                          label: Text('${LocalizationService().get('payFull')} (₪${widget.invoice.remainingAmount.toStringAsFixed(2)})'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Items header
                Text(
                  LocalizationService().get('items'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),

                // Items list
                Expanded(
                  child: state is InvoiceLoading
                      ? const Center(child: CircularProgressIndicator())
                      : items.isEmpty
                          ? Center(child: Text(LocalizationService().get('loadingItems')))
                          : Card(
                              child: SingleChildScrollView(
                                child: DataTable(
                                  columnSpacing: 24,
                                  columns: [
                                    DataColumn(label: Text(LocalizationService().get('product'))),
                                    DataColumn(label: Text(LocalizationService().get('qty')), numeric: true),
                                    DataColumn(label: Text(LocalizationService().get('price')), numeric: true),
                                    DataColumn(label: Text(LocalizationService().get('total')), numeric: true),
                                  ],
                                  rows: items.map((item) {
                                    return DataRow(cells: [
                                      DataCell(Text(item.productName)),
                                      DataCell(Text('${item.quantity}')),
                                      DataCell(Text('₪${item.unitPrice.toStringAsFixed(2)}')),
                                      DataCell(
                                        Text(
                                          '₪${item.totalPrice.toStringAsFixed(2)}',
                                          style: const TextStyle(fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ]);
                                  }).toList(),
                                ),
                              ),
                            ),
                ),
                const SizedBox(height: 16),

                // Totals
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.success.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${LocalizationService().get('subtotal')}:'),
                          Text('₪${widget.invoice.subtotal.toStringAsFixed(2)}'),
                        ],
                      ),
                      if (widget.invoice.discountAmount > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${LocalizationService().get('discount')}:'),
                            Text(
                              '-₪${widget.invoice.discountAmount.toStringAsFixed(2)}',
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ],
                        ),
                      ],
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${LocalizationService().get('total')}:',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            '₪${widget.invoice.finalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Notes section
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.note, size: 18, color: AppColors.textSecondary),
                              const SizedBox(width: 8),
                              Text(
                                LocalizationService().get('notes'),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          if (!_isEditingNotes)
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () => setState(() => _isEditingNotes = true),
                              tooltip: LocalizationService().get('edit'),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_isEditingNotes)
                        Column(
                          children: [
                            TextField(
                              controller: _notesController,
                              maxLines: 3,
                              decoration: InputDecoration(
                                hintText: LocalizationService().get('enterNotes'),
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    _notesController.text = widget.invoice.notes ?? '';
                                    setState(() => _isEditingNotes = false);
                                  },
                                  child: Text(LocalizationService().get('cancel')),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    context.read<InvoiceBloc>().add(
                                      InvoiceUpdateNotes(
                                        invoiceId: widget.invoice.id!,
                                        notes: _notesController.text.isEmpty ? null : _notesController.text,
                                      ),
                                    );
                                    setState(() => _isEditingNotes = false);
                                  },
                                  child: Text(LocalizationService().get('save')),
                                ),
                              ],
                            ),
                          ],
                        )
                      else
                        Text(
                          widget.invoice.notes?.isNotEmpty == true 
                              ? widget.invoice.notes! 
                              : LocalizationService().get('noNotes'),
                          style: TextStyle(
                            fontStyle: widget.invoice.notes?.isNotEmpty == true ? FontStyle.normal : FontStyle.italic,
                            color: widget.invoice.notes?.isNotEmpty == true ? AppColors.textPrimary : AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(LocalizationService().get('close')),
            ),
            ElevatedButton.icon(
              onPressed: () {
                context.read<InvoiceBloc>().add(InvoicePrint(widget.invoice.id!));
              },
              icon: const Icon(Icons.print),
              label: Text(LocalizationService().get('print')),
            ),
          ],
        );
      },
    );
  }

  String _getPaymentMethodLabel(String method) {
    switch (method) {
      case 'cash':
        return LocalizationService().get('cash');
      case 'card':
        return LocalizationService().get('card');
      case 'credit':
        return LocalizationService().get('credit');
      default:
        return method;
    }
  }
  
  String _getPaymentStatusLabel(String status) {
    switch (status) {
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

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w500, color: valueColor),
            ),
          ],
        ),
      ],
    );
  }
}
