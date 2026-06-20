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
  late final TextEditingController _chequeNumberController;
  late DateTime _selectedDate;
  SupplierPaymentMethod _paymentMethod = SupplierPaymentMethod.cash;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _notesController = TextEditingController();
    _chequeNumberController = TextEditingController();
    _selectedDate = DateTime.now();
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

  void _payFull() {
    final remaining = widget.invoice.remainingAmount;
    if (remaining > 0) {
      _amountController.text = remaining.toStringAsFixed(2);
    }
  }

  bool get _isOverpaying {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    return amount > widget.invoice.remainingAmount && widget.invoice.remainingAmount >= 0;
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final amount = double.tryParse(_amountController.text.trim()) ?? 0;

      final payment = SupplierPayment(
        supplierInvoiceId: widget.invoice.id!,
        amount: amount,
        paymentDate: _selectedDate,
        paymentMethod: _paymentMethod,
        chequeNumber: _paymentMethod == SupplierPaymentMethod.cheque
            ? _chequeNumberController.text.trim()
            : null,
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
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.payment, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Expanded(child: Text(loc.get('recordPaymentForInvoice'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                // Invoice info summary
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary.withOpacity(0.05), AppColors.primary.withOpacity(0.02)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                  ),
                  child: Column(
                    children: [
                      _infoRow(loc.get('invoiceNumberLabel'), '#${widget.invoice.invoiceNumber}'),
                      const SizedBox(height: 6),
                      _infoRow(loc.get('totalAmountLabel'),
                          LocalizationService().formatCurrency(widget.invoice.totalAmount)),
                      const SizedBox(height: 6),
                      _infoRow(loc.get('paidAmountLabel'),
                          LocalizationService().formatCurrency(widget.invoice.paidAmount),
                          valueColor: AppColors.success),
                      Divider(color: AppColors.primary.withOpacity(0.2), height: 16),
                      _infoRow(
                        loc.get('remainingBalanceLabel'),
                        LocalizationService().formatCurrency(remaining),
                        valueColor: remaining > 0 ? AppColors.error : AppColors.success,
                        isBold: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Payment Amount
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _amountController,
                        decoration: InputDecoration(
                          labelText: '${loc.get('paymentAmount')} *',
                          prefixIcon: const Icon(Icons.attach_money),
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return loc.get('amountIsRequired');
                          }
                          final amount = double.tryParse(value.trim());
                          if (amount == null || amount <= 0) {
                            return loc.get('amountMustBePositive');
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: ElevatedButton.icon(
                        onPressed: remaining > 0 ? _payFull : null,
                        icon: const Icon(Icons.done_all, size: 18),
                        label: Text(loc.get('payFull')),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Payment Method
                Text(
                  loc.get('paymentMethodLabel'),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _PaymentMethodCard(
                        icon: Icons.payments_outlined,
                        label: loc.get('cashPayment'),
                        isSelected: _paymentMethod == SupplierPaymentMethod.cash,
                        color: AppColors.success,
                        onTap: () => setState(() => _paymentMethod = SupplierPaymentMethod.cash),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PaymentMethodCard(
                        icon: Icons.description_outlined,
                        label: loc.get('chequePayment'),
                        isSelected: _paymentMethod == SupplierPaymentMethod.cheque,
                        color: AppColors.info,
                        onTap: () => setState(() => _paymentMethod = SupplierPaymentMethod.cheque),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Cheque Number (only if cheque)
                if (_paymentMethod == SupplierPaymentMethod.cheque) ...[
                  TextFormField(
                    controller: _chequeNumberController,
                    decoration: InputDecoration(
                      labelText: '${loc.get('chequeNumber')} *',
                      prefixIcon: const Icon(Icons.pin_outlined),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (_paymentMethod == SupplierPaymentMethod.cheque &&
                          (value == null || value.trim().isEmpty)) {
                        return loc.get('chequeNumberRequired');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // Payment Date
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: loc.get('date'),
                      prefixIcon: const Icon(Icons.calendar_today),
                      border: const OutlineInputBorder(),
                    ),
                    child: Text(dateFormat.format(_selectedDate)),
                  ),
                ),
                const SizedBox(height: 16),

                // Overpayment warning
                if (_isOverpaying) ...[                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.warning.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.warning, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            loc.get('overpaymentWarning'),
                            style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Notes
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: loc.get('notes'),
                    prefixIcon: const Icon(Icons.notes),
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      // Actions
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(loc.get('cancel')),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.check, size: 18),
              label: Text(loc.get('record')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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

  Widget _infoRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(
          fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          fontSize: isBold ? 14 : 13,
        )),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: valueColor,
            fontSize: isBold ? 15 : 13,
          ),
        ),
      ],
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _PaymentMethodCard({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? color : Colors.grey, size: 28),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? color : Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
