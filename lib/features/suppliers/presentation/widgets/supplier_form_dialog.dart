import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/localization_service.dart';
import '../../domain/entities/supplier.dart';
import '../bloc/supplier_bloc.dart';

class SupplierFormDialog extends StatefulWidget {
  final Supplier? supplier;

  const SupplierFormDialog({super.key, this.supplier});

  @override
  State<SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends State<SupplierFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _noteController;

  bool get isEditing => widget.supplier != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.supplier?.name ?? '');
    _phoneController = TextEditingController(text: widget.supplier?.phone ?? '');
    _addressController = TextEditingController(text: widget.supplier?.address ?? '');
    _noteController = TextEditingController(text: widget.supplier?.note ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final supplier = Supplier(
        id: widget.supplier?.id,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );

      if (isEditing) {
        context.read<SupplierBloc>().add(SupplierUpdate(supplier));
      } else {
        context.read<SupplierBloc>().add(SupplierCreate(supplier));
      }

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = LocalizationService();
    return AlertDialog(
      title: Text(isEditing ? loc.get('editSupplier') : loc.get('addSupplier')),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '${loc.get('supplierName')} *',
                  prefixIcon: const Icon(Icons.business),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return loc.get('supplierNameRequired');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Phone
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: loc.get('phone'),
                  prefixIcon: const Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 16),

              // Address
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: loc.get('address'),
                  prefixIcon: const Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 16),

              // Note
              TextFormField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: loc.get('notes'),
                  prefixIcon: const Icon(Icons.notes),
                ),
                maxLines: 3,
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
          child: Text(isEditing ? loc.get('update') : loc.get('save')),
        ),
      ],
    );
  }
}
