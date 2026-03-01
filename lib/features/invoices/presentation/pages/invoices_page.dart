import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/invoice.dart';
import '../bloc/invoice_bloc.dart';
import '../widgets/invoice_details_dialog.dart';

class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedPaymentMethod;
  final _dateFormat = DateFormat('yyyy-MM-dd');
  final _searchController = TextEditingController();
  String _searchQuery = '';
  
  // Store invoices locally to prevent disappearing on detail view
  List<Invoice> _invoices = [];

  @override
  void initState() {
    super.initState();
    // Default to current month
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = now;
    
    // Load invoices after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInvoices();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(
        start: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
        end: _endDate ?? DateTime.now(),
      ),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadInvoices();
    }
  }

  void _loadInvoices() {
    context.read<InvoiceBloc>().add(InvoiceLoadByDateRange(
      start: _startDate!,
      end: _endDate!,
    ));
  }

  void _showInvoiceDetails(Invoice invoice) {
    context.read<InvoiceBloc>().add(InvoiceLoadDetails(invoice.id!));
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<InvoiceBloc>(),
        child: InvoiceDetailsDialog(invoice: invoice),
      ),
    ).then((_) {
      // Auto-refresh invoices after dialog closes (payment/delete may have happened)
      _loadInvoices();
    });
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

  Color _getPaymentMethodColor(String method) {
    switch (method) {
      case 'cash':
        return AppColors.success;
      case 'card':
        return AppColors.info;
      case 'credit':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
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

  void _openPdfFolder(String filePath) {
    try {
      final file = File(filePath);
      final directory = file.parent.path;
      if (Platform.isWindows) {
        Process.run('explorer', [directory]);
      } else if (Platform.isMacOS) {
        Process.run('open', [directory]);
      } else if (Platform.isLinux) {
        Process.run('xdg-open', [directory]);
      }
    } catch (e) {
      // Silently ignore errors
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<InvoiceBloc, InvoiceState>(
      listener: (context, state) {
        if (state is InvoiceOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.success,
            ),
          );
          // Auto-reload invoices after any operation (payment, delete, etc.)
          _loadInvoices();
        } else if (state is InvoicePdfSaved) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${LocalizationService().get('pdfSaved')}: ${state.filePath}'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: LocalizationService().get('openFolder'),
                textColor: Colors.white,
                onPressed: () {
                  // Open the folder containing the PDF
                  _openPdfFolder(state.filePath);
                },
              ),
            ),
          );
        } else if (state is InvoiceError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      builder: (context, state) {
        // Update cached invoices when list is loaded
        if (state is InvoiceListLoaded) {
          _invoices = state.invoices;
        }
        
        // Apply filters to cached invoices
        List<Invoice> filteredInvoices = _invoices;
        
        // Payment method filter
        if (_selectedPaymentMethod != null) {
          filteredInvoices = filteredInvoices
              .where((i) => i.paymentMethod == _selectedPaymentMethod)
              .toList();
        }
        
        // Search filter (by invoice number or customer name)
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          filteredInvoices = filteredInvoices.where((i) {
            final invoiceNum = i.invoiceNumber.toLowerCase();
            final customerName = (i.customerName ?? '').toLowerCase();
            return invoiceNum.contains(query) || customerName.contains(query);
          }).toList();
        }

        double totalAmount = filteredInvoices.fold(0, (sum, i) => sum + i.finalAmount);

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppStrings.invoices,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Filters
              Row(
                children: [
                  // Search field
                  SizedBox(
                    width: 250,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: LocalizationService().get('searchInvoiceOrCustomer'),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() => _searchQuery = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Date range picker
                  OutlinedButton.icon(
                    onPressed: _selectDateRange,
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _startDate != null && _endDate != null
                          ? '${_dateFormat.format(_startDate!)} - ${_dateFormat.format(_endDate!)}'
                          : LocalizationService().get('selectDateRange'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // Refresh button
                  IconButton(
                    onPressed: _loadInvoices,
                    icon: const Icon(Icons.refresh),
                    tooltip: LocalizationService().get('refresh'),
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 16),

                  // Payment method filter
                  DropdownButton<String?>(
                    value: _selectedPaymentMethod,
                    hint: Text(LocalizationService().get('allPaymentMethods')),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(LocalizationService().get('allPaymentMethods')),
                      ),
                      DropdownMenuItem(value: 'cash', child: Text(LocalizationService().get('cash'))),
                      DropdownMenuItem(value: 'card', child: Text(LocalizationService().get('card'))),
                      DropdownMenuItem(value: 'credit', child: Text(LocalizationService().get('credit'))),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedPaymentMethod = value);
                    },
                  ),
                  const Spacer(),

                  // Total amount
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.success.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.attach_money, color: AppColors.success),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              LocalizationService().get('total'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              '₪${totalAmount.toStringAsFixed(2)}',
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
                ],
              ),
              const SizedBox(height: 16),

              // Invoice count
              Text(
                '${filteredInvoices.length} ${LocalizationService().get('invoices').toLowerCase()}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 8),

              // Data Table
              Expanded(
                child: state is InvoiceLoading && _invoices.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : Card(
                        child: DataTable2(
                          columnSpacing: 16,
                          horizontalMargin: 16,
                          minWidth: 800,
                          headingRowColor: WidgetStateProperty.all(
                            AppColors.primary.withOpacity(0.1),
                          ),
                          columns: [
                            DataColumn2(label: Text(LocalizationService().get('invoiceNumber')), size: ColumnSize.S),
                            DataColumn2(label: Text(LocalizationService().get('date')), size: ColumnSize.M),
                            DataColumn2(label: Text(LocalizationService().get('customerName')), size: ColumnSize.L),
                            DataColumn2(label: Text(LocalizationService().get('items')), numeric: true),
                            DataColumn2(label: Text(LocalizationService().get('amount')), numeric: true),
                            DataColumn2(label: Text(LocalizationService().get('status')), size: ColumnSize.S),
                            DataColumn2(label: Text(LocalizationService().get('payment')), size: ColumnSize.S),
                            DataColumn2(label: Text(LocalizationService().get('actions')), size: ColumnSize.S),
                          ],
                          rows: filteredInvoices.map((invoice) {
                            return DataRow2(
                              onTap: () => _showInvoiceDetails(invoice),
                              cells: [
                                DataCell(Text('#${invoice.id}')),
                                DataCell(Text(_dateFormat.format(invoice.createdAt))),
                                DataCell(Text(invoice.customerName ?? 'Walk-in')),
                                DataCell(Text('${invoice.items?.length ?? 0}')),
                                DataCell(
                                  Text(
                                    '₪${invoice.finalAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getPaymentStatusColor(invoice.paymentStatus)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _getPaymentStatusLabel(invoice.paymentStatus),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _getPaymentStatusColor(invoice.paymentStatus),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getPaymentMethodColor(invoice.paymentMethod)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _getPaymentMethodLabel(invoice.paymentMethod),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _getPaymentMethodColor(invoice.paymentMethod),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.visibility, size: 20),
                                        onPressed: () => _showInvoiceDetails(invoice),
                                        tooltip: LocalizationService().get('viewDetails'),
                                        color: AppColors.info,
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.picture_as_pdf, size: 20),
                                        onPressed: () {
                                          context.read<InvoiceBloc>().add(
                                            InvoiceSavePdf(invoice.id!),
                                          );
                                        },
                                        tooltip: LocalizationService().get('savePdf'),
                                        color: AppColors.primary,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                          empty: Center(
                            child: Text(LocalizationService().get('noInvoicesForPeriod')),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
