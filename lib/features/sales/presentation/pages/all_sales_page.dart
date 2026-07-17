import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/sale_record.dart';
import '../bloc/all_sales_bloc.dart';
import 'account_ledger_profit_page.dart';
import 'daily_customer_sales_page.dart';

class AllSalesPage extends StatefulWidget {
  const AllSalesPage({super.key});

  @override
  State<AllSalesPage> createState() => _AllSalesPageState();
}

class _AllSalesPageState extends State<AllSalesPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<AllSalesBloc>().add(AllSalesLoadMore());
    }
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        context.read<AllSalesBloc>().add(AllSalesSearch(value));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = LocalizationService();

    return Container(
      color: Colors.grey[50],
      child: Column(
        children: [
          // ─── Header ───
          _buildHeader(l10n),

          // ─── Content ───
          Expanded(
            child: BlocBuilder<AllSalesBloc, AllSalesState>(
              builder: (context, state) {
                if (state is AllSalesLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is AllSalesError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: AppColors.error),
                        const SizedBox(height: 12),
                        Text(state.message, style: const TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () => context.read<AllSalesBloc>().add(AllSalesRefresh()),
                          icon: const Icon(Icons.refresh),
                          label: Text(l10n.get('refresh')),
                        ),
                      ],
                    ),
                  );
                }
                if (state is AllSalesLoaded) {
                  if (state.records.isEmpty) {
                    return _buildEmptyState(l10n, state.searchQuery.isNotEmpty);
                  }
                  return _buildRecordsTable(state, l10n);
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(LocalizationService l10n) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.receipt, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.get('allSales'),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    BlocBuilder<AllSalesBloc, AllSalesState>(
                      builder: (context, state) {
                        if (state is AllSalesLoaded) {
                          return Text(
                            '${state.totalCount} ${l10n.get('records')}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ),
              // Account statement profit report
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AccountLedgerProfitPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.account_balance, size: 18),
                label: Text(l10n.get('accountLedgerProfit')),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(width: 8),
              // Daily customer sales (ledger order)
              FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DailyCustomerSalesPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.people_alt_outlined, size: 18),
                label: Text(l10n.get('dailyCustomerSales')),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(width: 8),
              // Refresh button
              IconButton(
                onPressed: () => context.read<AllSalesBloc>().add(AllSalesRefresh()),
                icon: const Icon(Icons.refresh_rounded),
                color: AppColors.primary,
                tooltip: l10n.get('refresh'),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Search Field
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.get('searchAllSalesHint'),
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: const Icon(Icons.search, size: 24),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          context.read<AllSalesBloc>().add(AllSalesSearch(''));
                          setState(() {});
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              style: const TextStyle(fontSize: 16),
              onChanged: (value) {
                setState(() {}); // update suffix icon
                _onSearchChanged(value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(LocalizationService l10n, bool isSearching) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSearching ? Icons.search_off : Icons.receipt_long_outlined,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            isSearching ? l10n.get('noSearchResults') : l10n.get('noSalesRecords'),
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          if (isSearching) ...[
            const SizedBox(height: 8),
            Text(
              l10n.get('tryDifferentSearch'),
              style: TextStyle(fontSize: 13, color: Colors.grey[400]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecordsTable(AllSalesLoaded state, LocalizationService l10n) {
    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SingleChildScrollView(
                controller: _scrollController,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(AppColors.primary.withOpacity(0.1)),
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 64,
                    columnSpacing: 20,
                    horizontalMargin: 16,
                    columns: [
                      DataColumn(label: Text(l10n.get('productName'), style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text(l10n.get('barcode'), style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text(l10n.get('quantity'), style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                      DataColumn(label: Text(l10n.get('unitPrice'), style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                      DataColumn(label: Text(l10n.get('totalAmount'), style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                      DataColumn(label: Text(l10n.get('discount'), style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                      DataColumn(label: Text(l10n.get('finalAmount'), style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                      DataColumn(label: Text(l10n.get('profit'), style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                      DataColumn(label: Text(l10n.get('customer'), style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text(l10n.get('invoiceNumber'), style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text(l10n.get('saleDate'), style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text(l10n.get('notes'), style: const TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: state.records.map((record) => _buildDataRow(record, l10n)).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Load more / status bar
        _buildStatusBar(state, l10n),
      ],
    );
  }

  DataRow _buildDataRow(SaleRecord record, LocalizationService l10n) {
    return DataRow(
      color: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered)) {
          return AppColors.primary.withOpacity(0.04);
        }
        return null;
      }),
      cells: [
        // Product name
        DataCell(
          SizedBox(
            width: 160,
            child: Row(
              children: [
                if (record.isCustomProduct)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      l10n.get('customProduct'),
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    record.productName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Barcode
        DataCell(
          Text(
            record.barcode ?? '-',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ),
        // Quantity
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${record.quantity}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ),
        ),
        // Unit price
        DataCell(
          Text(
            '₪${record.salePrice.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        // Total amount
        DataCell(
          Text(
            '₪${record.totalAmount.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        // Discount
        DataCell(
          Text(
            record.discountAmount > 0 ? '₪${record.discountAmount.toStringAsFixed(2)}' : '-',
            style: TextStyle(
              color: record.discountAmount > 0 ? AppColors.error : Colors.grey[400],
              fontWeight: record.discountAmount > 0 ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ),
        // Final amount
        DataCell(
          Text(
            '₪${record.finalAmount.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
        ),
        // Profit
        DataCell(
          Text(
            '₪${record.profit.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: record.profit >= 0 ? AppColors.success : AppColors.error,
            ),
          ),
        ),
        // Customer
        DataCell(
          SizedBox(
            width: 120,
            child: Text(
              record.customerName ?? '-',
              style: TextStyle(
                color: record.customerName != null ? AppColors.textPrimary : Colors.grey[400],
                fontWeight: record.customerName != null ? FontWeight.w500 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        // Invoice number
        DataCell(
          Text(
            record.invoiceNumber ?? '-',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ),
        // Sale date
        DataCell(
          Text(
            record.saleDate != null
                ? '${record.saleDate!.year}-${record.saleDate!.month.toString().padLeft(2, '0')}-${record.saleDate!.day.toString().padLeft(2, '0')} ${record.saleDate!.hour.toString().padLeft(2, '0')}:${record.saleDate!.minute.toString().padLeft(2, '0')}'
                : '-',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ),
        // Note
        DataCell(
          SizedBox(
            width: 100,
            child: Text(
              record.note ?? '-',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBar(AllSalesLoaded state, LocalizationService l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          // Summary
          RichText(
            text: TextSpan(
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
              children: [
                TextSpan(text: '${l10n.get('showing')} '),
                TextSpan(
                  text: '${state.records.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                TextSpan(text: ' ${l10n.get('of')} '),
                TextSpan(
                  text: '${state.totalCount}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                TextSpan(text: ' ${l10n.get('records')}'),
              ],
            ),
          ),
          const Spacer(),
          // Load more button
          if (state.hasMore)
            state.isLoadingMore
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : FilledButton.icon(
                    onPressed: () => context.read<AllSalesBloc>().add(AllSalesLoadMore()),
                    icon: const Icon(Icons.expand_more, size: 18),
                    label: Text(l10n.get('loadMore')),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
        ],
      ),
    );
  }
}
