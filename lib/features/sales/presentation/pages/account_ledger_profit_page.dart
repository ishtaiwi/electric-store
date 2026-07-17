import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../../customers/domain/repositories/customer_repository.dart';
import '../../domain/entities/account_ledger_profit_report.dart';
import '../../domain/repositories/sales_repository.dart';

/// Shows full (all-time) profit from customer account-statement sales.
/// Only registered catalog products are counted (custom/manual items excluded).
class AccountLedgerProfitPage extends StatefulWidget {
  const AccountLedgerProfitPage({super.key});

  @override
  State<AccountLedgerProfitPage> createState() => _AccountLedgerProfitPageState();
}

class _AccountLedgerProfitPageState extends State<AccountLedgerProfitPage> {
  final _loc = LocalizationService();
  final _dateFormat = DateFormat('dd-MM-yyyy');

  Customer? _selectedCustomer;

  AccountLedgerProfitReport? _report;
  bool _isLoading = false;
  String? _error;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final report = await di.sl<SalesRepository>().getAccountLedgerProfitReport(
            customerId: _selectedCustomer?.id,
          );
      if (!mounted) return;
      setState(() {
        _report = report;
        _isLoading = false;
        if (_selectedCustomer != null && report.lines.isNotEmpty) {
          _showDetails = true;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openCustomerPicker() async {
    final repo = di.sl<CustomerRepository>();
    String query = '';

    final selected = await showDialog<Customer>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<List<Customer>> loadCustomers() {
              if (query.trim().isEmpty) {
                return repo.getCustomersPaginated(limit: 200);
              }
              return repo.searchCustomers(query.trim());
            }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: SizedBox(
                width: 560,
                height: 560,
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.people, color: Colors.white),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _loc.get('selectCustomer'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: _loc.get('searchCustomers'),
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          isDense: true,
                        ),
                        onChanged: (v) => setDialogState(() => query = v),
                      ),
                    ),
                    Expanded(
                      child: FutureBuilder<List<Customer>>(
                        future: loadCustomers(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final items = snapshot.data ?? [];
                          if (items.isEmpty) {
                            return Center(child: Text(_loc.get('noCustomersFound')));
                          }
                          return ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final c = items[index];
                              final isSelected = _selectedCustomer?.id == c.id;
                              return ListTile(
                                selected: isSelected,
                                selectedTileColor:
                                    AppColors.primary.withValues(alpha: 0.08),
                                leading: CircleAvatar(
                                  backgroundColor:
                                      AppColors.primary.withValues(alpha: 0.15),
                                  child: Text(
                                    c.name.isNotEmpty
                                        ? c.name.substring(0, 1).toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  c.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  [
                                    if (c.phone != null && c.phone!.isNotEmpty) c.phone,
                                    _loc.formatCurrency(c.balance),
                                  ].whereType<String>().join(' • '),
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle,
                                        color: AppColors.primary)
                                    : null,
                                onTap: () => Navigator.pop(dialogContext, c),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: Text(_loc.get('close')),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || selected == null) return;
    setState(() => _selectedCustomer = selected);
    await _loadReport();
  }

  void _clearCustomer() {
    setState(() {
      _selectedCustomer = null;
      _showDetails = false;
    });
    _loadReport();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(_loc.get('accountLedgerProfit')),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadReport,
            icon: const Icon(Icons.refresh),
            tooltip: _loc.get('refresh'),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _loc.get('accountLedgerProfitHint'),
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _openCustomerPicker,
                icon: const Icon(Icons.person_search, size: 18),
                label: Text(
                  _selectedCustomer?.name ?? _loc.get('selectCustomer'),
                  overflow: TextOverflow.ellipsis,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              if (_selectedCustomer != null) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _clearCustomer,
                  icon: const Icon(Icons.clear, size: 18),
                  label: Text(_loc.get('allCustomers')),
                ),
              ],
              const Spacer(),
              IconButton(
                onPressed: _isLoading ? null : _loadReport,
                icon: const Icon(Icons.refresh_rounded),
                color: AppColors.primary,
                tooltip: _loc.get('refresh'),
              ),
            ],
          ),
          if (_selectedCustomer != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Chip(
                avatar: const Icon(Icons.person, size: 16, color: AppColors.primary),
                label: Text(
                  '${_loc.get('customer')}: ${_selectedCustomer!.name} — ${_loc.get('fullAccountProfit')}',
                ),
                onDeleted: _clearCustomer,
                deleteIconColor: AppColors.error,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadReport,
              icon: const Icon(Icons.refresh),
              label: Text(_loc.get('retry')),
            ),
          ],
        ),
      );
    }

    final report = _report ?? AccountLedgerProfitReport.empty();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSummaryCards(report),
        const SizedBox(height: 16),
        _buildCustomerTable(report),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: report.lines.isEmpty
                ? null
                : () => setState(() => _showDetails = !_showDetails),
            icon: Icon(_showDetails ? Icons.expand_less : Icons.expand_more),
            label: Text(
              _showDetails
                  ? _loc.get('hideDetails')
                  : _loc.get('showSaleDetails'),
            ),
          ),
        ),
        if (_showDetails) ...[
          const SizedBox(height: 8),
          _buildDetailsTable(report),
        ],
      ],
    );
  }

  Widget _buildSummaryCards(AccountLedgerProfitReport report) {
    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            title: _loc.get('totalProfit'),
            value: _loc.formatCurrency(report.totalProfit),
            color: AppColors.success,
            icon: Icons.trending_up,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryCard(
            title: _loc.get('totalSales'),
            value: _loc.formatCurrency(report.totalSales),
            color: AppColors.primary,
            icon: Icons.shopping_cart,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryCard(
            title: _loc.get('items'),
            value: '${report.itemCount}',
            color: AppColors.info,
            icon: Icons.inventory_2_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryCard(
            title: _loc.get('customers'),
            value: '${report.byCustomer.length}',
            color: Colors.teal,
            icon: Icons.people_outline,
          ),
        ),
      ],
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerTable(AccountLedgerProfitReport report) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              _loc.get('profitByCustomer'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          if (report.byCustomer.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      _loc.get('noAccountLedgerProfit'),
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  AppColors.primary.withValues(alpha: 0.06),
                ),
                columns: [
                  DataColumn(label: Text(_loc.get('customer'), style: _headerStyle)),
                  DataColumn(
                    label: Text(_loc.get('items'), style: _headerStyle),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Text(_loc.get('totalSales'), style: _headerStyle),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Text(_loc.get('profit'), style: _headerStyle),
                    numeric: true,
                  ),
                ],
                rows: report.byCustomer.map((row) {
                  return DataRow(
                    cells: [
                      DataCell(Text(row.customerName)),
                      DataCell(Text('${row.itemCount}')),
                      DataCell(Text(_loc.formatCurrency(row.totalSales))),
                      DataCell(
                        Text(
                          _loc.formatCurrency(row.totalProfit),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: row.totalProfit >= 0
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailsTable(AccountLedgerProfitReport report) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              _loc.get('saleDetails'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                Colors.grey.shade100,
              ),
              columns: [
                DataColumn(label: Text(_loc.get('date'), style: _headerStyle)),
                DataColumn(label: Text(_loc.get('customer'), style: _headerStyle)),
                DataColumn(label: Text(_loc.get('productName'), style: _headerStyle)),
                DataColumn(
                  label: Text(_loc.get('quantity'), style: _headerStyle),
                  numeric: true,
                ),
                DataColumn(
                  label: Text(_loc.get('total'), style: _headerStyle),
                  numeric: true,
                ),
                DataColumn(
                  label: Text(_loc.get('profit'), style: _headerStyle),
                  numeric: true,
                ),
                DataColumn(label: Text(_loc.get('invoiceNumber'), style: _headerStyle)),
              ],
              rows: report.lines.map((line) {
                return DataRow(
                  cells: [
                    DataCell(Text(
                      line.saleDate != null
                          ? _dateFormat.format(line.saleDate!)
                          : '-',
                    )),
                    DataCell(Text(line.customerName)),
                    DataCell(Text(line.productName)),
                    DataCell(Text('${line.quantity}')),
                    DataCell(Text(_loc.formatCurrency(line.totalAmount))),
                    DataCell(
                      Text(
                        _loc.formatCurrency(line.profit),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: line.profit >= 0
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                    ),
                    DataCell(Text(line.invoiceNumber ?? '-')),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle get _headerStyle => const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 12,
      );
}
