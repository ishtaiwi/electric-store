import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/supplier.dart';
import '../bloc/supplier_bloc.dart';
import '../widgets/supplier_form_dialog.dart';
import '../widgets/supplier_attachments_dialog.dart';

class SuppliersPage extends StatefulWidget {
  const SuppliersPage({super.key});

  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showSupplierDialog({Supplier? supplier}) {
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<SupplierBloc>(),
        child: SupplierFormDialog(supplier: supplier),
      ),
    );
  }

  void _showAttachmentsDialog(Supplier supplier) {
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<SupplierBloc>(),
        child: SupplierAttachmentsDialog(supplier: supplier),
      ),
    );
  }

  void _confirmDelete(Supplier supplier) {
    final loc = LocalizationService();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.get('confirmDelete')),
        content: Text(loc.get('confirmDeleteSupplier')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.get('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<SupplierBloc>().add(SupplierDelete(supplier.id!));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(loc.get('delete')),
          ),
        ],
      ),
    );
  }

  List<Supplier> _filterSuppliers(List<Supplier> suppliers) {
    if (_searchQuery.isEmpty) return suppliers;
    final q = _searchQuery.toLowerCase();
    return suppliers.where((s) {
      return s.name.toLowerCase().contains(q) ||
          (s.phone ?? '').toLowerCase().contains(q) ||
          (s.address ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final loc = LocalizationService();

    return BlocConsumer<SupplierBloc, SupplierState>(
      listener: (context, state) {
        if (state is SupplierOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.success,
            ),
          );
        } else if (state is SupplierError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      builder: (context, state) {
        List<Supplier> suppliers = [];
        if (state is SupplierLoaded) {
          suppliers = _filterSuppliers(state.suppliers);
        }

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
                    loc.get('suppliers'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showSupplierDialog(),
                    icon: const Icon(Icons.add),
                    label: Text(loc.get('addSupplier')),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Search
              SizedBox(
                width: 400,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: loc.get('searchSuppliers'),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              const SizedBox(height: 16),

              // Supplier count
              Text(
                '${loc.get('total')}: ${suppliers.length} ${loc.get('suppliers').toLowerCase()}',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),

              // Data Table
              Expanded(
                child: state is SupplierLoading
                    ? const Center(child: CircularProgressIndicator())
                    : suppliers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.local_shipping_outlined,
                                    size: 64, color: AppColors.textHint),
                                const SizedBox(height: 16),
                                Text(
                                  loc.get('noSuppliersFound'),
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Card(
                            elevation: 2,
                            child: DataTable2(
                              columnSpacing: 12,
                              horizontalMargin: 16,
                              minWidth: 600,
                              headingRowColor: WidgetStateProperty.all(
                                AppColors.primary.withOpacity(0.1),
                              ),
                              columns: [
                                DataColumn2(
                                  label: Text(loc.get('name'),
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                                  size: ColumnSize.L,
                                ),
                                DataColumn2(
                                  label: Text(loc.get('phone'),
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                                  size: ColumnSize.M,
                                ),
                                DataColumn2(
                                  label: Text(loc.get('address'),
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                                  size: ColumnSize.L,
                                ),
                                DataColumn2(
                                  label: Text(loc.get('notes'),
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                                  size: ColumnSize.M,
                                ),
                                DataColumn2(
                                  label: Text(loc.get('actions'),
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                                  size: ColumnSize.L,
                                  fixedWidth: 200,
                                ),
                              ],
                              rows: suppliers.map((supplier) {
                                return DataRow2(
                                  cells: [
                                    DataCell(Text(supplier.name)),
                                    DataCell(Text(supplier.phone ?? '-')),
                                    DataCell(Text(supplier.address ?? '-')),
                                    DataCell(Text(
                                      supplier.note ?? '-',
                                      overflow: TextOverflow.ellipsis,
                                    )),
                                    DataCell(Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.attach_file,
                                              color: AppColors.info, size: 20),
                                          tooltip: loc.get('attachments'),
                                          onPressed: () =>
                                              _showAttachmentsDialog(supplier),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit,
                                              color: AppColors.primary, size: 20),
                                          tooltip: loc.get('edit'),
                                          onPressed: () =>
                                              _showSupplierDialog(supplier: supplier),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.delete,
                                              color: AppColors.error, size: 20),
                                          tooltip: loc.get('delete'),
                                          onPressed: () => _confirmDelete(supplier),
                                        ),
                                      ],
                                    )),
                                  ],
                                );
                              }).toList(),
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
