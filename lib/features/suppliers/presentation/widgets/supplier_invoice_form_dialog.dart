import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/localization_service.dart';
import '../../domain/entities/supplier_invoice.dart';
import '../bloc/supplier_bloc.dart';

class SupplierInvoiceFormDialog extends StatefulWidget {
  final int supplierId;
  final SupplierInvoice? invoice;

  const SupplierInvoiceFormDialog({
    super.key,
    required this.supplierId,
    this.invoice,
  });

  @override
  State<SupplierInvoiceFormDialog> createState() => _SupplierInvoiceFormDialogState();
}

class _SupplierInvoiceFormDialogState extends State<SupplierInvoiceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _invoiceNumberController;
  late final TextEditingController _totalAmountController;
  late final TextEditingController _notesController;
  late DateTime _selectedDate;
  String? _filePath;
  String? _fileName;
  String? _fileType;

  bool get isEditing => widget.invoice != null;

  @override
  void initState() {
    super.initState();
    _invoiceNumberController = TextEditingController(text: widget.invoice?.invoiceNumber ?? '');
    _totalAmountController = TextEditingController(
      text: widget.invoice != null ? widget.invoice!.totalAmount.toStringAsFixed(2) : '',
    );
    _notesController = TextEditingController(text: widget.invoice?.notes ?? '');
    _selectedDate = widget.invoice?.invoiceDate ?? DateTime.now();
    _filePath = widget.invoice?.filePath;
    _fileName = widget.invoice?.fileName;
    _fileType = widget.invoice?.fileType;
  }

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _totalAmountController.dispose();
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

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'bmp', 'gif'],
      dialogTitle: LocalizationService().get('selectFile'),
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.path == null) return;
      final ext = file.extension?.toLowerCase() ?? '';
      setState(() {
        _filePath = file.path;
        _fileName = file.name;
        _fileType = ext == 'pdf' ? 'pdf' : 'image';
      });
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final totalAmount = double.tryParse(_totalAmountController.text.trim()) ?? 0;

      final invoice = SupplierInvoice(
        id: widget.invoice?.id,
        supplierId: widget.supplierId,
        invoiceNumber: _invoiceNumberController.text.trim(),
        invoiceDate: _selectedDate,
        totalAmount: totalAmount,
        paidAmount: widget.invoice?.paidAmount ?? 0,
        filePath: _filePath,
        fileName: _fileName,
        fileType: _fileType,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      if (isEditing) {
        context.read<SupplierBloc>().add(SupplierUpdateInvoice(invoice));
      } else {
        context.read<SupplierBloc>().add(SupplierCreateInvoice(invoice));
      }

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = LocalizationService();
    final dateFormat = DateFormat('yyyy-MM-dd');

    return AlertDialog(
      title: Text(isEditing ? loc.get('editSupplierInvoice') : loc.get('addSupplierInvoice')),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Invoice Number
                TextFormField(
                  controller: _invoiceNumberController,
                  decoration: InputDecoration(
                    labelText: '${loc.get('invoiceNumberLabel')} *',
                    prefixIcon: const Icon(Icons.receipt_long),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return loc.get('invoiceNumberRequired');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Invoice Date
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: loc.get('invoiceDateLabel'),
                      prefixIcon: const Icon(Icons.calendar_today),
                    ),
                    child: Text(dateFormat.format(_selectedDate)),
                  ),
                ),
                const SizedBox(height: 16),

                // Total Amount
                TextFormField(
                  controller: _totalAmountController,
                  decoration: InputDecoration(
                    labelText: '${loc.get('totalAmountLabel')} *',
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
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // File Attachment
                Row(
                  children: [
                    Expanded(
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: loc.get('invoiceFile'),
                          prefixIcon: Icon(
                            _fileType == 'pdf' ? Icons.picture_as_pdf : Icons.image,
                            color: _fileName != null ? Colors.green : null,
                          ),
                        ),
                        child: Text(
                          _fileName ?? loc.get('attachInvoiceFile'),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _fileName != null ? null : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.upload_file),
                      tooltip: loc.get('attachInvoiceFile'),
                      onPressed: _pickFile,
                    ),
                    if (_fileName != null)
                      IconButton(
                        icon: const Icon(Icons.clear, color: Colors.red),
                        tooltip: loc.get('clear'),
                        onPressed: () {
                          setState(() {
                            _filePath = null;
                            _fileName = null;
                            _fileType = null;
                          });
                        },
                      ),
                  ],
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
