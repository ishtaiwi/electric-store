import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/price_list.dart';
import '../../domain/entities/price_list_item.dart';
import '../bloc/price_list_bloc.dart';

class PriceListDetailsDialog extends StatelessWidget {
  final PriceList priceList;

  const PriceListDetailsDialog({super.key, required this.priceList});

  @override
  Widget build(BuildContext context) {
    final l10n = LocalizationService();
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Dialog(
      insetPadding: const EdgeInsets.all(32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 750,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: BlocConsumer<PriceListBloc, PriceListState>(
          listener: (context, state) {
            if (state is PriceListPdfSaved) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white),
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
                  content: Text(state.message),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          },
          builder: (context, state) {
            List<PriceListItem> items = [];
            PriceList displayPriceList = priceList;

            if (state is PriceListDetailsLoaded &&
                state.priceList.id == priceList.id) {
              items = state.items;
              displayPriceList = state.priceList;
            }

            final totalAmount = items.fold(0.0, (sum, item) => sum + item.totalPrice);

            return Column(
              children: [
                // ── Gradient header ──
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primary.withOpacity(0.85)],
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.list_alt, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayPriceList.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                    color: Colors.white,
                                  ),
                                ),
                                if (displayPriceList.customerName != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.person, size: 14, color: Colors.white70),
                                        const SizedBox(width: 4),
                                        Text(
                                          displayPriceList.customerName!,
                                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Action buttons
                          _ActionButton(
                            icon: Icons.picture_as_pdf,
                            tooltip: l10n.get('savePdf'),
                            onPressed: displayPriceList.id != null
                                ? () => context.read<PriceListBloc>().add(PriceListSavePdf(displayPriceList.id!))
                                : null,
                          ),
                          const SizedBox(width: 6),
                          _ActionButton(
                            icon: Icons.print,
                            tooltip: l10n.get('print'),
                            onPressed: displayPriceList.id != null
                                ? () => context.read<PriceListBloc>().add(PriceListPrint(displayPriceList.id!))
                                : null,
                          ),
                          const SizedBox(width: 6),
                          _ActionButton(
                            icon: Icons.close,
                            tooltip: l10n.get('close'),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Info chips
                      Row(
                        children: [
                          _InfoChip(icon: Icons.calendar_today, label: dateFormat.format(displayPriceList.createdAt)),
                          const SizedBox(width: 10),
                          _InfoChip(icon: Icons.inventory_2, label: '${items.length} ${l10n.get('items')}'),
                          const SizedBox(width: 10),
                          _InfoChip(
                            icon: Icons.info_outline,
                            label: l10n.get('noInventoryImpact'),
                            color: Colors.amber.shade100,
                            textColor: Colors.amber.shade900,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Notes section ──
                if (displayPriceList.notes != null && displayPriceList.notes!.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    color: Colors.orange.shade50,
                    child: Row(
                      children: [
                        Icon(Icons.notes, size: 16, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            displayPriceList.notes!,
                            style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Items table ──
                Expanded(
                  child: items.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${l10n.get('items')} (${items.length})',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade200),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: SingleChildScrollView(
                                    child: Table(
                                      columnWidths: const {
                                        0: FixedColumnWidth(45),
                                        1: FlexColumnWidth(3),
                                        2: FixedColumnWidth(70),
                                        3: FixedColumnWidth(110),
                                        4: FixedColumnWidth(120),
                                      },
                                      children: [
                                        // Header
                                        TableRow(
                                          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08)),
                                          children: [
                                            _headerCell('#'),
                                            _headerCell(l10n.get('productName')),
                                            _headerCell(l10n.get('qty')),
                                            _headerCell(l10n.get('price')),
                                            _headerCell(l10n.get('total')),
                                          ],
                                        ),
                                        // Rows
                                        ...items.asMap().entries.map((entry) {
                                          final index = entry.key;
                                          final item = entry.value;
                                          return TableRow(
                                            decoration: BoxDecoration(
                                              color: index.isEven ? Colors.white : Colors.grey.shade50,
                                            ),
                                            children: [
                                              _dataCell('${index + 1}', align: TextAlign.center),
                                              _dataCell(item.productName),
                                              _dataCell('${item.quantity}', align: TextAlign.center),
                                              _dataCell(
                                                '${LocalizationService.currencySymbol}${item.unitPrice.toStringAsFixed(2)}',
                                                align: TextAlign.center,
                                              ),
                                              _dataCell(
                                                '${LocalizationService.currencySymbol}${item.totalPrice.toStringAsFixed(2)}',
                                                align: TextAlign.center,
                                                bold: true,
                                                color: AppColors.primary,
                                              ),
                                            ],
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),

                // ── Footer total ──
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                    border: Border(top: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.get('priceListDescription'),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.success, AppColors.success.withOpacity(0.85)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.success.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.receipt_long, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '${l10n.get('total')}: ${LocalizationService.currencySymbol}${totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _headerCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _dataCell(String text, {TextAlign align = TextAlign.start, bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
          color: color,
        ),
        textAlign: align,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _ActionButton({required this.icon, required this.tooltip, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Tooltip(
            message: tooltip,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final Color? textColor;

  const _InfoChip({required this.icon, required this.label, this.color, this.textColor});

  @override
  Widget build(BuildContext context) {
    final bg = color ?? Colors.white.withOpacity(0.15);
    final fg = textColor ?? Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, color: fg)),
        ],
      ),
    );
  }
}
