import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/customer_payment.dart';
import '../bloc/customer_bloc.dart';

class CustomerEditPaymentDialog extends StatefulWidget {
  final CustomerPayment payment;
  final double invoiceFinalAmount;
  final double otherPaymentsTotal;

  const CustomerEditPaymentDialog({
    super.key,
    required this.payment,
    required this.invoiceFinalAmount,
    this.otherPaymentsTotal = 0,
  });

  @override
  State<CustomerEditPaymentDialog> createState() => _CustomerEditPaymentDialogState();
}

class _CustomerEditPaymentDialogState extends State<CustomerEditPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  late final TextEditingController _chequeNumberController;
  late DateTime _selectedDate;
  late CustomerPaymentMethod _paymentMethod;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.payment.amount.toStringAsFixed(2));
    _notesController = TextEditingController(text: widget.payment.notes ?? '');
    _chequeNumberController = TextEditingController(text: widget.payment.chequeNumber ?? '');
    _selectedDate = widget.payment.paymentDate;
    _paymentMethod = widget.payment.paymentMethod;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _chequeNumberController.dispose();
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

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final amount = double.tryParse(_amountController.text.trim()) ?? 0;
      final updated = widget.payment.copyWith(
        amount: amount,
        paymentDate: _selectedDate,
        paymentMethod: _paymentMethod,
        chequeNumber: _paymentMethod == CustomerPaymentMethod.cheque
            ? _chequeNumberController.text.trim()
            : null,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
      context.read<CustomerBloc>().add(CustomerUpdatePayment(updated));
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = LocalizationService();
    final dateFormat = DateFormat('yyyy-MM-dd');
    final maxAllowed = widget.invoiceFinalAmount - widget.otherPaymentsTotal;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${loc.get('editPayment')} - RCP-${widget.payment.id?.toString().padLeft(5, '0') ?? ''}',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.payment.invoiceNumber != null)
                        Text(
                          '${loc.get('invoiceRef')}: #${widget.payment.invoiceNumber}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _amountController,
                        decoration: InputDecoration(
                          labelText: '${loc.get('paymentAmount')} *',
                          prefixIcon: const Icon(Icons.attach_money),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                          if (amount > maxAllowed + 0.01) {
                            return loc.get('amountExceedsRemaining');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(loc.get('paymentMethodLabel'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<CustomerPaymentMethod>(
                              title: Text(loc.get('cashPayment')),
                              value: CustomerPaymentMethod.cash,
                              groupValue: _paymentMethod,
                              onChanged: (v) => setState(() => _paymentMethod = v!),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<CustomerPaymentMethod>(
                              title: Text(loc.get('chequePayment')),
                              value: CustomerPaymentMethod.cheque,
                              groupValue: _paymentMethod,
                              onChanged: (v) => setState(() => _paymentMethod = v!),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                      if (_paymentMethod == CustomerPaymentMethod.cheque) ...[
                        TextFormField(
                          controller: _chequeNumberController,
                          decoration: InputDecoration(
                            labelText: '${loc.get('chequeNumber')} *',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (value) {
                            if (_paymentMethod == CustomerPaymentMethod.cheque &&
                                (value == null || value.trim().isEmpty)) {
                              return loc.get('chequeNumberRequired');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      InkWell(
                        onTap: _pickDate,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: loc.get('paymentDate'),
                            prefixIcon: const Icon(Icons.calendar_today),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(dateFormat.format(_selectedDate)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _notesController,
                        decoration: InputDecoration(
                          labelText: loc.get('paymentNotes'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.get('cancel'))),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.save, size: 18),
                    label: Text(loc.get('save')),
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
