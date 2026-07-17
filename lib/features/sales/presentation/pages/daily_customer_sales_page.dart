import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/daily_customer_sales_report.dart';
import '../../domain/repositories/sales_repository.dart';

/// Today's (or filtered-date) customer sales, ordered like account statements.
class DailyCustomerSalesPage extends StatefulWidget {
  const DailyCustomerSalesPage({super.key});

  @override
  State<DailyCustomerSalesPage> createState() => _DailyCustomerSalesPageState();
}

class _DailyCustomerSalesPageState extends State<DailyCustomerSalesPage> {
  final _loc = LocalizationService();
  final _dateFormat = DateFormat('dd-MM-yyyy');

  late DateTime _fromDate;
  late DateTime _toDate;

  DailyCustomerSalesReport? _report;
  bool _isLoading = false;
  String? _error;
  final Set<int> _expandedCustomers = {};

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _fromDate = DateTime(today.year, today.month, today.day);
    _toDate = _fromDate;
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final report = await di.sl<SalesRepository>().getDailyCustomerSalesReport(
            fromDate: _fromDate,
            toDate: _toDate,
          );
      if (!mounted) return;
      setState(() {
        _report = report;
        _isLoading = false;
        // Expand all customers by default when few, otherwise first few
        _expandedCustomers
          ..clear()
          ..addAll(
            report.byCustomer.length <= 8
                ? report.byCustomer.map((g) => g.customerId)
                : report.byCustomer.take(3).map((g) => g.customerId),
          );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _fromDate = DateTime(picked.year, picked.month, picked.day);
      if (_toDate.isBefore(_fromDate)) _toDate = _fromDate;
    });
    await _loadReport();
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: _fromDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _toDate = DateTime(picked.year, picked.month, picked.day);
    });
    await _loadReport();
  }

  void _setToday() {
    final today = DateTime.now();
    setState(() {
      _fromDate = DateTime(today.year, today.month, today.day);
      _toDate = _fromDate;
    });
    _loadReport();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(_loc.get('dailyCustomerSales')),
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
            _loc.get('dailyCustomerSalesHint'),
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _pickFromDate,
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text('${_loc.get('filterFromDate')}: ${_dateFormat.format(_fromDate)}'),
              ),
              OutlinedButton.icon(
                onPressed: _pickToDate,
                icon: const Icon(Icons.event, size: 16),
                label: Text('${_loc.get('filterToDate')}: ${_dateFormat.format(_toDate)}'),
              ),
              FilledButton.icon(
                onPressed: _setToday,
                icon: const Icon(Icons.today, size: 18),
                label: Text(_loc.get('today')),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              IconButton(
                onPressed: _isLoading ? null : _loadReport,
                icon: const Icon(Icons.refresh_rounded),
                color: AppColors.primary,
                tooltip: _loc.get('refresh'),
              ),
            ],
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

    final report = _report ??
        DailyCustomerSalesReport.empty(fromDate: _fromDate, toDate: _toDate);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSummaryCards(report),
        const SizedBox(height: 16),
        if (report.byCustomer.isEmpty)
          _buildEmptyState()
        else
          ...report.byCustomer.map(_buildCustomerSection),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            _loc.get('noDailyCustomerSales'),
            style: TextStyle(color: Colors.grey[600], fontSize: 15),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(DailyCustomerSalesReport report) {
    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            title: _loc.get('totalSales'),
            value: _loc.formatCurrency(report.totalAmount),
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

  Widget _buildCustomerSection(DailyCustomerSalesGroup group) {
    final isExpanded = _expandedCustomers.contains(group.customerId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedCustomers.remove(group.customerId);
                } else {
                  _expandedCustomers.add(group.customerId);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      group.customerName.isNotEmpty
                          ? group.customerName.substring(0, 1).toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.customerName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${group.itemCount} ${_loc.get('items')}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _loc.formatCurrency(group.totalAmount),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  AppColors.primary.withValues(alpha: 0.06),
                ),
                columns: [
                  DataColumn(label: Text(_loc.get('date'), style: _headerStyle)),
                  DataColumn(label: Text(_loc.get('productName'), style: _headerStyle)),
                  DataColumn(
                    label: Text(_loc.get('quantity'), style: _headerStyle),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Text(_loc.get('finalAmount'), style: _headerStyle),
                    numeric: true,
                  ),
                  DataColumn(label: Text(_loc.get('invoiceNumber'), style: _headerStyle)),
                  DataColumn(label: Text(_loc.get('notes'), style: _headerStyle)),
                ],
                rows: group.lines.map((line) {
                  return DataRow(
                    cells: [
                      DataCell(Text(
                        line.saleDate != null
                            ? _dateFormat.format(line.saleDate!)
                            : '-',
                      )),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(child: Text(line.productName)),
                            if (line.isCustomProduct) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _loc.get('customProduct'),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      DataCell(Text('${line.quantity}')),
                      DataCell(Text(_loc.formatCurrency(line.finalAmount))),
                      DataCell(Text(line.invoiceNumber ?? '-')),
                      DataCell(Text(line.note?.isNotEmpty == true ? line.note! : '-')),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  TextStyle get _headerStyle => const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 12,
      );
}
