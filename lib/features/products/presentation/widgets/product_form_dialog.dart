import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../suppliers/domain/entities/supplier.dart';
import '../../../suppliers/domain/repositories/supplier_repository.dart';
import '../../domain/entities/product.dart';
import '../bloc/product_bloc.dart';

class ProductFormDialog extends StatefulWidget {
  final Product? product;

  const ProductFormDialog({super.key, this.product});

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _priceController;
  late final TextEditingController _costPriceController;
  late final TextEditingController _quantityController;
  late final TextEditingController _noteController;
  late final TextEditingController _supplierController;
  late final TextEditingController _minStockController;
  
  List<Supplier> _suppliers = [];
  int? _selectedSupplierId;

  bool get isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _barcodeController = TextEditingController(text: widget.product?.barcode ?? '');
    _priceController = TextEditingController(
      text: widget.product?.price.toString() ?? '',
    );
    _costPriceController = TextEditingController(
      text: widget.product?.costPrice.toString() ?? '',
    );
    _quantityController = TextEditingController(
      text: widget.product?.quantity.toString() ?? '0',
    );
    _noteController = TextEditingController(text: widget.product?.note ?? '');
    _supplierController = TextEditingController(text: widget.product?.supplier ?? '');
    _minStockController = TextEditingController(
      text: (widget.product?.minStock ?? 5).toString(),
    );
    _selectedSupplierId = widget.product?.supplierId;
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    try {
      final repo = di.sl<SupplierRepository>();
      final suppliers = await repo.getAllSuppliers();
      if (mounted) {
        setState(() => _suppliers = suppliers);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _priceController.dispose();
    _costPriceController.dispose();
    _quantityController.dispose();
    _noteController.dispose();
    _supplierController.dispose();
    _minStockController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final product = Product(
        id: widget.product?.id,
        name: _nameController.text.trim(),
        barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
        price: double.tryParse(_priceController.text) ?? 0,
        costPrice: double.tryParse(_costPriceController.text) ?? 0,
        quantity: int.tryParse(_quantityController.text) ?? 0,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        supplier: _supplierController.text.trim().isEmpty ? null : _supplierController.text.trim(),
        supplierId: _selectedSupplierId,
        minStock: int.tryParse(_minStockController.text) ?? 5,
      );

      if (isEditing) {
        context.read<ProductBloc>().add(ProductUpdate(product));
      } else {
        context.read<ProductBloc>().add(ProductCreate(product));
      }

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = LocalizationService();
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 30),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
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
                    child: Icon(
                      isEditing ? Icons.edit : Icons.inventory_2,
                      color: Colors.white, size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEditing ? l10n.get('editProduct') : l10n.get('addProduct'),
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
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
                    children: [
                      // Name
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: l10n.get('productName'),
                          prefixIcon: const Icon(Icons.inventory_2),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return l10n.get('productNameRequired');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Barcode
                      TextFormField(
                        controller: _barcodeController,
                        decoration: InputDecoration(
                          labelText: l10n.get('barcode'),
                          prefixIcon: const Icon(Icons.qr_code),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Price Row
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _priceController,
                              decoration: InputDecoration(
                                labelText: l10n.get('price'),
                                prefixIcon: const Icon(Icons.attach_money),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                              ],
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return l10n.get('priceRequired');
                                }
                                if (double.tryParse(value) == null) {
                                  return l10n.get('invalidPrice');
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _costPriceController,
                              decoration: InputDecoration(
                                labelText: l10n.get('costPrice'),
                                prefixIcon: const Icon(Icons.money_off),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                              ],
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return l10n.get('costPriceRequired');
                                }
                                if (double.tryParse(value) == null) {
                                  return l10n.get('invalidPrice');
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Quantity Row
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _quantityController,
                              decoration: InputDecoration(
                                labelText: l10n.get('quantity'),
                                prefixIcon: const Icon(Icons.numbers),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              enabled: !isEditing, // Disable quantity editing, use stock adjustment instead
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _minStockController,
                              decoration: InputDecoration(
                                labelText: l10n.get('minStock'),
                                prefixIcon: const Icon(Icons.warning_amber),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Note
                      TextFormField(
                        controller: _noteController,
                        decoration: InputDecoration(
                          labelText: l10n.get('notes'),
                          prefixIcon: const Icon(Icons.note),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Supplier dropdown
                      DropdownButtonFormField<int?>(
                        value: _selectedSupplierId,
                        decoration: InputDecoration(
                          labelText: l10n.get('supplier'),
                          prefixIcon: const Icon(Icons.local_shipping),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: [
                          DropdownMenuItem<int?>(
                            value: null,
                            child: Text(l10n.get('noSupplier')),
                          ),
                          ..._suppliers.map((s) => DropdownMenuItem<int?>(
                            value: s.id,
                            child: Text(s.name),
                          )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedSupplierId = value;
                            // Also update text field for backward compatibility
                            if (value != null) {
                              final selected = _suppliers.firstWhere((s) => s.id == value);
                              _supplierController.text = selected.name;
                            } else {
                              _supplierController.clear();
                            }
                          });
                        },
                      ),

                      // Profit margin display
                      if (_priceController.text.isNotEmpty && _costPriceController.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.trending_up, color: AppColors.success, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  '${l10n.get('profitMargin')} ₪${_calculateProfit().toStringAsFixed(2)} (${_calculateMargin().toStringAsFixed(1)}%)',
                                  style: const TextStyle(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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
                    child: Text(l10n.get('cancel')),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _save,
                    icon: Icon(isEditing ? Icons.save : Icons.add, size: 18),
                    label: Text(isEditing ? l10n.get('save') : l10n.get('add')),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  double _calculateProfit() {
    final price = double.tryParse(_priceController.text) ?? 0;
    final cost = double.tryParse(_costPriceController.text) ?? 0;
    return price - cost;
  }

  double _calculateMargin() {
    final price = double.tryParse(_priceController.text) ?? 0;
    final cost = double.tryParse(_costPriceController.text) ?? 0;
    if (cost == 0) return 0;
    return ((price - cost) / cost) * 100;
  }
}
