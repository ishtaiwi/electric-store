import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../customers/presentation/bloc/customer_bloc.dart';
import '../../../products/presentation/bloc/product_bloc.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/sale_item.dart';
import '../bloc/invoice_bloc.dart';
import 'edit_invoice_dialog.dart';

class InvoiceDetailsDialog extends StatefulWidget {
  final Invoice invoice;

  const InvoiceDetailsDialog({super.key, required this.invoice});

  @override
  State<InvoiceDetailsDialog> createState() => _InvoiceDetailsDialogState();
}

class _InvoiceDetailsDialogState extends State<InvoiceDetailsDialog> {
  final _paymentController = TextEditingController();
  final _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _showPaymentForm = false;
  bool _isEditingNotes = false;

  @override
  void initState() {
    super.initState();
    _notesController.text = widget.invoice.notes ?? '';
  }

  @override
  void dispose() {
    _paymentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _recordPayment() {
    if (_formKey.currentState?.validate() ?? false) {
      final paymentAmount = double.tryParse(_paymentController.text) ?? 0;
      final newPaidAmount = widget.invoice.paidAmount + paymentAmount;
      context.read<InvoiceBloc>().add(
        InvoiceUpdatePaidAmount(invoiceId: widget.invoice.id!, paidAmount: newPaidAmount),
      );
      di.sl<CustomerBloc>().add(CustomerRefresh());
      Navigator.pop(context);
    }
  }

  void _payFull() {
    context.read<InvoiceBloc>().add(
      InvoiceUpdatePaidAmount(invoiceId: widget.invoice.id!, paidAmount: widget.invoice.finalAmount),
    );
    di.sl<CustomerBloc>().add(CustomerRefresh());
    Navigator.pop(context);
  }

  void _editInvoice(List<SaleItem> items) {
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<InvoiceBloc>(),
        child: EditInvoiceDialog(
          invoice: widget.invoice,
          items: items,
        ),
      ),
    );
  }

  void _deleteInvoice() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
            const SizedBox(width: 10),
            Text(LocalizationService().get('deleteInvoiceTitle')),
          ],
        ),
        content: Text(
          LocalizationService().get('confirmDeleteInvoiceMsg'),
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(LocalizationService().get('cancel')),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx); // close confirmation dialog
              context.read<InvoiceBloc>().add(InvoiceDelete(widget.invoice.id!));
              di.sl<CustomerBloc>().add(CustomerRefresh());
              di.sl<ProductBloc>().add(ProductRefresh());
              Navigator.pop(context); // close details dialog
            },
            icon: const Icon(Icons.delete_forever, size: 18),
            label: Text(LocalizationService().get('delete')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getPaymentMethodIcon(String method) {
    switch (method) {
      case 'cash':
        return Icons.payments_outlined;
      case 'card':
        return Icons.credit_card;
      case 'credit':
        return Icons.account_balance_wallet_outlined;
      default:
        return Icons.payment;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'paid':
        return Icons.check_circle;
      case 'partial':
        return Icons.timelapse;
      case 'unpaid':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final statusColor = _getPaymentStatusColor(widget.invoice.paymentStatus);

    return BlocBuilder<InvoiceBloc, InvoiceState>(
      builder: (context, state) {
        List<SaleItem> items = [];
        if (state is InvoiceDetailsLoaded) {
          items = state.items;
        }

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
          child: Container(
            width: 680,
            constraints: const BoxConstraints(maxHeight: 700),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ─── Top accent bar + header ───
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primaryDark, AppColors.primary],
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  child: Row(
                    children: [
                      // Invoice icon
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.receipt_long, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      // Invoice number + date
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${LocalizationService().get('invoiceNumber')} #${widget.invoice.id}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dateFormat.format(widget.invoice.createdAt),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getStatusIcon(widget.invoice.paymentStatus),
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _getPaymentStatusLabel(widget.invoice.paymentStatus),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Close button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            child: Icon(Icons.close, color: Colors.white.withOpacity(0.8), size: 22),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── Body (scrollable) ───
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ─── Info cards row ───
                        Row(
                          children: [
                            Expanded(
                              child: _InfoCard(
                                icon: Icons.person_outline,
                                label: LocalizationService().get('customerName'),
                                value: widget.invoice.customerName ?? LocalizationService().get('walkInCustomer'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _InfoCard(
                                icon: _getPaymentMethodIcon(widget.invoice.paymentMethod),
                                label: LocalizationService().get('paymentMethod'),
                                value: _getPaymentMethodLabel(widget.invoice.paymentMethod),
                                accentColor: _getPaymentMethodColor(widget.invoice.paymentMethod),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _InfoCard(
                                icon: Icons.badge_outlined,
                                label: LocalizationService().get('cashier'),
                                value: widget.invoice.userName ?? LocalizationService().get('unknown'),
                              ),
                            ),
                          ],
                        ),

                        // ─── Payment balance bar (if not fully paid) ───
                        if (!widget.invoice.isFullyPaid) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.warning.withOpacity(0.06),
                                  AppColors.warning.withOpacity(0.02),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.warning.withOpacity(0.25)),
                            ),
                            child: Column(
                              children: [
                                // Progress bar
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                LocalizationService().get('paidAmount'),
                                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                              ),
                                              Text(
                                                '₪${widget.invoice.paidAmount.toStringAsFixed(2)} / ₪${widget.invoice.finalAmount.toStringAsFixed(2)}',
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(6),
                                            child: LinearProgressIndicator(
                                              value: widget.invoice.finalAmount > 0
                                                  ? (widget.invoice.paidAmount / widget.invoice.finalAmount).clamp(0.0, 1.0)
                                                  : 0,
                                              minHeight: 8,
                                              backgroundColor: AppColors.divider,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                widget.invoice.paidAmount > 0 ? AppColors.success : AppColors.error,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: AppColors.error.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            LocalizationService().get('remaining'),
                                            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '₪${widget.invoice.remainingAmount.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: AppColors.error,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                if (!_showPaymentForm)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => setState(() => _showPaymentForm = true),
                                          icon: const Icon(Icons.payment, size: 18),
                                          label: Text(LocalizationService().get('recordPayment')),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.primary,
                                            side: const BorderSide(color: AppColors.primary),
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _payFull,
                                          icon: const Icon(Icons.check_circle_outline, size: 18),
                                          label: Text('${LocalizationService().get('payFull')} (₪${widget.invoice.remainingAmount.toStringAsFixed(2)})'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.success,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Form(
                                    key: _formKey,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller: _paymentController,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            decoration: InputDecoration(
                                              labelText: LocalizationService().get('paymentAmount'),
                                              prefixText: '₪ ',
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                              isDense: true,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                            ),
                                            validator: (value) {
                                              if (value == null || value.isEmpty) {
                                                return LocalizationService().get('required');
                                              }
                                              final amount = double.tryParse(value);
                                              if (amount == null || amount <= 0) {
                                                return LocalizationService().get('invalidNumber');
                                              }
                                              if (amount > widget.invoice.remainingAmount) {
                                                return '${LocalizationService().get('max')}: ₪${widget.invoice.remainingAmount.toStringAsFixed(2)}';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton(
                                          onPressed: _recordPayment,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          child: Text(LocalizationService().get('record')),
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(Icons.close, size: 20),
                                          onPressed: () => setState(() => _showPaymentForm = false),
                                          splashRadius: 18,
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // ─── Items section ───
                        Row(
                          children: [
                            const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            Text(
                              LocalizationService().get('items'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const Spacer(),
                            if (items.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${items.length}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Items table
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.divider),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: state is InvoiceLoading
                              ? const Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Center(child: CircularProgressIndicator()),
                                )
                              : items.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.all(32),
                                      child: Center(
                                        child: Column(
                                          children: [
                                            Icon(Icons.inbox_outlined, size: 36, color: AppColors.textHint),
                                            const SizedBox(height: 8),
                                            Text(
                                              LocalizationService().get('loadingItems'),
                                              style: const TextStyle(color: AppColors.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : Column(
                                      children: [
                                        // Table header
                                        Container(
                                          color: AppColors.primary.withOpacity(0.07),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                flex: 4,
                                                child: Text(
                                                  LocalizationService().get('product'),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12,
                                                    color: AppColors.primary.withOpacity(0.8),
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Text(
                                                  LocalizationService().get('qty'),
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12,
                                                    color: AppColors.primary.withOpacity(0.8),
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  LocalizationService().get('price'),
                                                  textAlign: TextAlign.end,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12,
                                                    color: AppColors.primary.withOpacity(0.8),
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  LocalizationService().get('total'),
                                                  textAlign: TextAlign.end,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12,
                                                    color: AppColors.primary.withOpacity(0.8),
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Table rows
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(maxHeight: 180),
                                          child: ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: items.length,
                                            itemBuilder: (context, index) {
                                              final item = items[index];
                                              final isEven = index.isEven;
                                              return Container(
                                                color: isEven ? Colors.transparent : AppColors.background.withOpacity(0.5),
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      flex: 4,
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            item.productName,
                                                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                                          ),
                                                          if (item.note != null && item.note!.isNotEmpty)
                                                            Padding(
                                                              padding: const EdgeInsets.only(top: 2),
                                                              child: Text(
                                                                item.note!,
                                                                style: const TextStyle(
                                                                  fontSize: 11,
                                                                  color: AppColors.textSecondary,
                                                                  fontStyle: FontStyle.italic,
                                                                ),
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 1,
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: AppColors.primary.withOpacity(0.08),
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: Text(
                                                          '${item.quantity}',
                                                          textAlign: TextAlign.center,
                                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 2,
                                                      child: Text(
                                                        '₪${item.unitPrice.toStringAsFixed(2)}',
                                                        textAlign: TextAlign.end,
                                                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 2,
                                                      child: Text(
                                                        '₪${item.totalPrice.toStringAsFixed(2)}',
                                                        textAlign: TextAlign.end,
                                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                        ),

                        const SizedBox(height: 16),

                        // ─── Totals section ───
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withOpacity(0.04),
                                AppColors.success.withOpacity(0.04),
                              ],
                            ),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Column(
                            children: [
                              _TotalRow(
                                label: '${LocalizationService().get('subtotal')}:',
                                value: '₪${widget.invoice.subtotal.toStringAsFixed(2)}',
                              ),
                              if (widget.invoice.discountAmount > 0) ...[
                                const SizedBox(height: 6),
                                _TotalRow(
                                  label: '${LocalizationService().get('discount')}:',
                                  value: '-₪${widget.invoice.discountAmount.toStringAsFixed(2)}',
                                  valueColor: AppColors.error,
                                  icon: Icons.discount_outlined,
                                ),
                              ],
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Divider(color: AppColors.divider, height: 1),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${LocalizationService().get('total')}:',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '₪${widget.invoice.finalAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // ─── Notes section ───
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.divider.withOpacity(0.6)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.sticky_note_2_outlined, size: 16, color: AppColors.textSecondary),
                                      const SizedBox(width: 8),
                                      Text(
                                        LocalizationService().get('notes'),
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  if (!_isEditingNotes)
                                    InkWell(
                                      borderRadius: BorderRadius.circular(6),
                                      onTap: () => setState(() => _isEditingNotes = true),
                                      child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit_outlined, size: 14, color: AppColors.primary),
                                            const SizedBox(width: 4),
                                            Text(
                                              LocalizationService().get('edit'),
                                              style: const TextStyle(fontSize: 12, color: AppColors.primary),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (_isEditingNotes)
                                Column(
                                  children: [
                                    TextField(
                                      controller: _notesController,
                                      maxLines: 3,
                                      decoration: InputDecoration(
                                        hintText: LocalizationService().get('enterNotes'),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.all(12),
                                        filled: true,
                                        fillColor: AppColors.surface,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton(
                                          onPressed: () {
                                            _notesController.text = widget.invoice.notes ?? '';
                                            setState(() => _isEditingNotes = false);
                                          },
                                          child: Text(LocalizationService().get('cancel')),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            context.read<InvoiceBloc>().add(
                                              InvoiceUpdateNotes(
                                                invoiceId: widget.invoice.id!,
                                                notes: _notesController.text.isEmpty ? null : _notesController.text,
                                              ),
                                            );
                                            setState(() => _isEditingNotes = false);
                                          },
                                          icon: const Icon(Icons.save_outlined, size: 16),
                                          label: Text(LocalizationService().get('save')),
                                          style: ElevatedButton.styleFrom(
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                )
                              else
                                Text(
                                  widget.invoice.notes?.isNotEmpty == true
                                      ? widget.invoice.notes!
                                      : LocalizationService().get('noNotes'),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontStyle: widget.invoice.notes?.isNotEmpty == true ? FontStyle.normal : FontStyle.italic,
                                    color: widget.invoice.notes?.isNotEmpty == true ? AppColors.textPrimary : AppColors.textHint,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                // ─── Bottom action bar ───
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.divider)),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  child: Row(
                    children: [
                      // Delete button
                      OutlinedButton.icon(
                        onPressed: _deleteInvoice,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: Text(LocalizationService().get('delete')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: BorderSide(color: AppColors.error.withOpacity(0.4)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Edit button
                      OutlinedButton.icon(
                        onPressed: () => _editInvoice(items),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: Text(LocalizationService().get('editInvoice')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.info,
                          side: BorderSide(color: AppColors.info.withOpacity(0.4)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // PDF save button
                      OutlinedButton.icon(
                        onPressed: () {
                          context.read<InvoiceBloc>().add(InvoiceSavePdf(widget.invoice.id!));
                        },
                        icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                        label: Text(LocalizationService().get('savePdf')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error.withOpacity(0.8),
                          side: BorderSide(color: AppColors.error.withOpacity(0.3)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                        child: Text(LocalizationService().get('close')),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () {
                          context.read<InvoiceBloc>().add(InvoicePrint(widget.invoice.id!));
                        },
                        icon: const Icon(Icons.print_outlined, size: 18),
                        label: Text(LocalizationService().get('print')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
}

// ─── Info card widget ───
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? accentColor;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Total row widget ───
class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final IconData? icon;

  const _TotalRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: valueColor ?? AppColors.textSecondary),
              const SizedBox(width: 6),
            ],
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
