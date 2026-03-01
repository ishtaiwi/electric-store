import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/price_list.dart';
import '../bloc/price_list_bloc.dart';
import '../widgets/price_list_form_dialog.dart';
import '../widgets/price_list_details_dialog.dart';

class PriceListsPage extends StatefulWidget {
  const PriceListsPage({super.key});

  @override
  State<PriceListsPage> createState() => _PriceListsPageState();
}

class _PriceListsPageState extends State<PriceListsPage> {
  final _dateFormat = DateFormat('yyyy-MM-dd');
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<PriceList> _priceLists = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPriceLists();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadPriceLists() {
    context.read<PriceListBloc>().add(PriceListRefresh());
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<PriceListBloc>(),
        child: const PriceListFormDialog(),
      ),
    );
  }

  void _showEditDialog(PriceList priceList) {
    context.read<PriceListBloc>().add(PriceListLoadDetails(priceList.id!));
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<PriceListBloc>(),
        child: PriceListFormDialog(priceList: priceList),
      ),
    );
  }

  void _showDetailsDialog(PriceList priceList) {
    context.read<PriceListBloc>().add(PriceListLoadDetails(priceList.id!));
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<PriceListBloc>(),
        child: PriceListDetailsDialog(priceList: priceList),
      ),
    );
  }

  void _confirmDelete(PriceList priceList) {
    final l10n = LocalizationService();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_forever, color: AppColors.error),
            ),
            const SizedBox(width: 12),
            Text(l10n.get('confirmDelete')),
          ],
        ),
        content: Text('${l10n.get('confirmDeleteItem')} "${priceList.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.get('cancel')),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<PriceListBloc>().add(PriceListDelete(priceList.id!));
            },
            icon: const Icon(Icons.delete, size: 18),
            label: Text(l10n.get('delete')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = LocalizationService();

    return BlocConsumer<PriceListBloc, PriceListState>(
      listener: (context, state) {
        if (state is PriceListOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(state.message),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        } else if (state is PriceListPdfSaved) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.picture_as_pdf, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text(state.message)),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        } else if (state is PriceListError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text(state.message)),
                ],
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is PriceListListLoaded) {
          _priceLists = state.priceLists;
        }

        // Apply local search filter
        List<PriceList> filteredLists = _priceLists;
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          filteredLists = filteredLists.where((pl) {
            return pl.title.toLowerCase().contains(query) ||
                (pl.customerName ?? '').toLowerCase().contains(query);
          }).toList();
        }

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.list_alt, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.get('priceLists'),
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.get('priceListDescription'),
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _showCreateDialog,
                      icon: const Icon(Icons.add, size: 20),
                      label: Text(l10n.get('createPriceList')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Search bar ──
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: l10n.get('searchPriceLists'),
                          hintStyle: TextStyle(color: Colors.grey.shade500),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onChanged: (value) => setState(() => _searchQuery = value),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _loadPriceLists,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.refresh, color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.list_alt, color: AppColors.primary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '${filteredLists.length}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Data table ──
              Expanded(
                child: state is PriceListLoading && _priceLists.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: DataTable2(
                          columnSpacing: 12,
                          horizontalMargin: 16,
                          minWidth: 750,
                          headingRowHeight: 48,
                          dataRowHeight: 56,
                          headingRowColor: WidgetStateProperty.all(AppColors.primary.withOpacity(0.06)),
                          columns: [
                            DataColumn2(
                              label: Text(l10n.get('title'), style: const TextStyle(fontWeight: FontWeight.bold)),
                              size: ColumnSize.L,
                            ),
                            DataColumn2(
                              label: Text(l10n.get('customerName'), style: const TextStyle(fontWeight: FontWeight.bold)),
                              size: ColumnSize.M,
                            ),
                            DataColumn2(
                              label: Text(l10n.get('items'), style: const TextStyle(fontWeight: FontWeight.bold)),
                              fixedWidth: 70,
                            ),
                            DataColumn2(
                              label: Text(l10n.get('date'), style: const TextStyle(fontWeight: FontWeight.bold)),
                              size: ColumnSize.M,
                            ),
                            DataColumn2(
                              label: Text(l10n.get('actions'), style: const TextStyle(fontWeight: FontWeight.bold)),
                              fixedWidth: 200,
                            ),
                          ],
                          rows: filteredLists.map((priceList) {
                            return DataRow2(
                              onTap: () => _showDetailsDialog(priceList),
                              cells: [
                                DataCell(
                                  Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.description, size: 16, color: AppColors.primary),
                                      ),
                                      const SizedBox(width: 10),
                                      Flexible(
                                        child: Text(
                                          priceList.title,
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    priceList.customerName ?? l10n.get('noCustomer'),
                                    style: TextStyle(
                                      color: priceList.customerName != null ? null : Colors.grey.shade500,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.info.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${priceList.itemCount}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.info),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    _dateFormat.format(priceList.createdAt),
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _SmallIconButton(
                                        icon: Icons.visibility,
                                        color: AppColors.info,
                                        tooltip: l10n.get('viewDetails'),
                                        onPressed: () => _showDetailsDialog(priceList),
                                      ),
                                      _SmallIconButton(
                                        icon: Icons.picture_as_pdf,
                                        color: AppColors.error,
                                        tooltip: l10n.get('savePdf'),
                                        onPressed: () => context.read<PriceListBloc>().add(PriceListSavePdf(priceList.id!)),
                                      ),
                                      _SmallIconButton(
                                        icon: Icons.edit,
                                        color: AppColors.warning,
                                        tooltip: l10n.get('edit'),
                                        onPressed: () => _showEditDialog(priceList),
                                      ),
                                      _SmallIconButton(
                                        icon: Icons.delete,
                                        color: AppColors.error,
                                        tooltip: l10n.get('delete'),
                                        onPressed: () => _confirmDelete(priceList),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                          empty: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.list_alt, size: 48, color: Colors.grey.shade400),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  l10n.get('noPriceListsFound'),
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  l10n.get('priceListDescription'),
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _showCreateDialog,
                                  icon: const Icon(Icons.add, size: 18),
                                  label: Text(l10n.get('createPriceList')),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
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

class _SmallIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  const _SmallIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
