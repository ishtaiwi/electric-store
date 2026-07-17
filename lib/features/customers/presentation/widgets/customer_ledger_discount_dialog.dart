import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_colors.dart';

enum LedgerDiscountMode { invoice, account }

class CustomerLedgerDiscountDialog extends StatefulWidget {
  final LedgerDiscountMode mode;
  final String title;
  final String? subtitle;
  final double referenceAmount;
  final double currentDiscount;

  const CustomerLedgerDiscountDialog({
    super.key,
    required this.mode,
    required this.title,
    this.subtitle,
    required this.referenceAmount,
    this.currentDiscount = 0,
  });

  @override
  State<CustomerLedgerDiscountDialog> createState() => _CustomerLedgerDiscountDialogState();
}

class _CustomerLedgerDiscountDialogState extends State<CustomerLedgerDiscountDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  final _loc = LocalizationService();

  @override
  void initState() {
    super.initState();
    final initial = widget.mode == LedgerDiscountMode.invoice
        ? widget.currentDiscount
        : 0.0;
    _amountController = TextEditingController(
      text: initial > 0 ? initial.toStringAsFixed(2) : '',
    );
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _amount => double.tryParse(_amountController.text.trim()) ?? 0;

  double get _maxAmount => widget.mode == LedgerDiscountMode.invoice
      ? widget.referenceAmount
      : math.max(widget.referenceAmount, 0);

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, {
      'amount': _amount,
      'notes': _notesController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final isInvoice = widget.mode == LedgerDiscountMode.invoice;
    final afterAmount = isInvoice
        ? widget.referenceAmount - _amount
        : widget.referenceAmount - _amount;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.discount, color: AppColors.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isInvoice ? _loc.get('invoiceDiscount') : _loc.get('accountDiscount'),
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 4),
                Text(widget.subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isInvoice ? _loc.get('invoiceTotalBeforeDiscount') : _loc.get('currentBalance'),
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    Text(
                      _loc.formatCurrency(widget.referenceAmount),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    if (_amount > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        isInvoice ? _loc.get('invoiceTotalAfterDiscount') : _loc.get('balanceAfterDiscount'),
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      Text(
                        _loc.formatCurrency(afterAmount),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  labelText: _loc.get('discountAmount'),
                  prefixIcon: const Icon(Icons.discount_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                validator: (value) {
                  final amount = double.tryParse(value?.trim() ?? '') ?? 0;
                  if (amount <= 0) return _loc.get('amountRequired');
                  if (isInvoice && amount > widget.referenceAmount) {
                    return _loc.get('discountExceedsTotal');
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: _loc.get('notes'),
                  hintText: _loc.get('enterNotes'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_loc.get('cancel')),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
          ),
          child: Text(_loc.get('applyDiscount')),
        ),
      ],
    );
  }
}
