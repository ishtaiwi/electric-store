import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_colors.dart';
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
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isEditing ? loc.get('editSupplierInvoice') : loc.get('addSupplierInvoice'),
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
            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Invoice Number
                      TextFormField(
                        controller: _invoiceNumberController,
                        decoration: InputDecoration(
                          labelText: '${loc.get('invoiceNumberLabel')} *',
                          prefixIcon: const Icon(Icons.receipt_long),
                          border: const OutlineInputBorder(),
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
                        borderRadius: BorderRadius.circular(8),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: loc.get('invoiceDateLabel'),
                            prefixIcon: const Icon(Icons.calendar_today),
                            border: const OutlineInputBorder(),
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
                          border: const OutlineInputBorder(),
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
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                child: Row(
                                  children: [
                                    Icon(
                                      _fileType == 'pdf' ? Icons.picture_as_pdf : (_fileName != null ? Icons.image : Icons.attach_file),
                                      color: _fileName != null ? Colors.green : Colors.grey,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _fileName ?? loc.get('attachInvoiceFile'),
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: _fileName != null ? null : Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.upload_file),
                              tooltip: loc.get('attachInvoiceFile'),
                              onPressed: _pickFile,
                            ),
                            if (_fileName != null)
                              IconButton(
                                icon: const Icon(Icons.clear, color: Colors.red, size: 20),
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
                      ),
                      const SizedBox(height: 16),

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
                    icon: Icon(isEditing ? Icons.save : Icons.add, size: 18),
                    label: Text(isEditing ? loc.get('update') : loc.get('save')),
                    style: ElevatedButton.styleFrom(
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
}
