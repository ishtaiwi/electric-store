import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/product.dart';
import '../bloc/product_bloc.dart';

class StockAdjustmentDialog extends StatefulWidget {
  final Product product;

  const StockAdjustmentDialog({super.key, required this.product});

  @override
  State<StockAdjustmentDialog> createState() => _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends State<StockAdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _reasonController = TextEditingController();
  String _adjustmentType = 'stock_in';

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final quantity = int.tryParse(_quantityController.text) ?? 0;

      context.read<ProductBloc>().add(ProductAdjustStock(
            productId: widget.product.id!,
            adjustment: quantity,
            type: _adjustmentType,
            reason: _reasonController.text.trim().isEmpty
                ? null
                : _reasonController.text.trim(),
          ));

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(LocalizationService().get('stockAdjustment')),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.product.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Current Stock: ${widget.product.quantity}',
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Adjustment type
              Text(
                LocalizationService().get('adjustmentType'),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'stock_in',
                    label: Text(LocalizationService().get('stockIn')),
                    icon: const Icon(Icons.add),
                  ),
                  ButtonSegment(
                    value: 'stock_out',
                    label: Text(LocalizationService().get('stockOut')),
                    icon: const Icon(Icons.remove),
                  ),
                  ButtonSegment(
                    value: 'return',
                    label: Text(LocalizationService().get('return')),
                    icon: const Icon(Icons.undo),
                  ),
                ],
                selected: {_adjustmentType},
                onSelectionChanged: (Set<String> selection) {
                  setState(() {
                    _adjustmentType = selection.first;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Quantity
              TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(
                  labelText: LocalizationService().get('quantity'),
                  prefixIcon: Icon(
                    _adjustmentType == 'stock_in' ? Icons.add : Icons.remove,
                  ),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autofocus: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return LocalizationService().get('quantityRequired');
                  }
                  final qty = int.tryParse(value) ?? 0;
                  if (qty <= 0) {
                    return LocalizationService().get('quantityGreaterThanZero');
                  }
                  if (_adjustmentType == 'stock_out' && qty > widget.product.quantity) {
                    return LocalizationService().get('cannotRemoveMoreThanStock');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Reason
              TextFormField(
                controller: _reasonController,
                decoration: InputDecoration(
                  labelText: LocalizationService().get('reasonOptional'),
                  prefixIcon: const Icon(Icons.note),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Preview
              if (_quantityController.text.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _adjustmentType == 'stock_in'
                        ? AppColors.success.withOpacity(0.1)
                        : AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _adjustmentType == 'stock_in'
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        color: _adjustmentType == 'stock_in'
                            ? AppColors.success
                            : AppColors.warning,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'New Stock: ${_calculateNewStock()}',
                        style: TextStyle(
                          color: _adjustmentType == 'stock_in'
                              ? AppColors.success
                              : AppColors.warning,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(LocalizationService().get('cancel')),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text(LocalizationService().get('save')),
        ),
      ],
    );
  }

  int _calculateNewStock() {
    final qty = int.tryParse(_quantityController.text) ?? 0;
    if (_adjustmentType == 'stock_in' || _adjustmentType == 'return') {
      return widget.product.quantity + qty;
    } else {
      return widget.product.quantity - qty;
    }
  }
}
