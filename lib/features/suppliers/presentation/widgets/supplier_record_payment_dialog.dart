import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/supplier_invoice.dart';
import '../../domain/entities/supplier_payment.dart';
import '../bloc/supplier_bloc.dart';

class SupplierRecordPaymentDialog extends StatefulWidget {
  final SupplierInvoice invoice;

  const SupplierRecordPaymentDialog({super.key, required this.invoice});

  @override
  State<SupplierRecordPaymentDialog> createState() => _SupplierRecordPaymentDialogState();
}

class _SupplierRecordPaymentDialogState extends State<SupplierRecordPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _notesController = TextEditingController();
    _selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _payFull() {
    _amountController.text = widget.invoice.remainingAmount.toStringAsFixed(2);
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final amount = double.tryParse(_amountController.text.trim()) ?? 0;

      final payment = SupplierPayment(
        supplierInvoiceId: widget.invoice.id!,
        amount: amount,
        paymentDate: _selectedDate,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      context.read<SupplierBloc>().add(SupplierRecordPayment(
        payment: payment,
        supplierId: widget.invoice.supplierId,
      ));

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = LocalizationService();
    final dateFormat = DateFormat('yyyy-MM-dd');
    final remaining = widget.invoice.remainingAmount;

    return AlertDialog(
      title: Text(loc.get('recordPaymentForInvoice')),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Invoice info summary
              Card(
                color: AppColors.primary.withOpacity(0.05),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _infoRow(loc.get('invoiceNumberLabel'), '#${widget.invoice.invoiceNumber}'),
                      const SizedBox(height: 4),
                      _infoRow(loc.get('totalAmountLabel'),
                          LocalizationService().formatCurrency(widget.invoice.totalAmount)),
                      const SizedBox(height: 4),
                      _infoRow(loc.get('paidAmountLabel'),
                          LocalizationService().formatCurrency(widget.invoice.paidAmount)),
                      const Divider(),
                      _infoRow(
                        loc.get('remainingBalanceLabel'),
                        LocalizationService().formatCurrency(remaining),
                        valueColor: remaining > 0 ? AppColors.error : AppColors.success,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Payment Amount
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _amountController,
                      decoration: InputDecoration(
                        labelText: '${loc.get('paymentAmount')} *',
                        prefixIcon: const Icon(Icons.attach_money),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return loc.get('amountIsRequired');
                        }
                        final amount = double.tryParse(value.trim());
                        if (amount == null || amount <= 0) {
                          return loc.get('amountMustBePositive');
                        }
                        if (amount > remaining) {
                          return loc.get('paymentExceedsBalance');
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: remaining > 0 ? _payFull : null,
                    child: Text(loc.get('payFull')),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Payment Date
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: loc.get('date'),
                    prefixIcon: const Icon(Icons.calendar_today),
                  ),
                  child: Text(dateFormat.format(_selectedDate)),
                ),
              ),
              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: loc.get('notes'),
                  prefixIcon: const Icon(Icons.notes),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(loc.get('cancel')),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(loc.get('record')),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
