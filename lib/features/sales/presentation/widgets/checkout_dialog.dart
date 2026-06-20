import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../customers/domain/entities/customer.dart';
import '../bloc/sales_bloc.dart';

class CheckoutDialog extends StatefulWidget {
  final List<Customer> customers;
  final Function(int? customerId, String paymentMethod, double discount, double? paidAmount) onCheckout;

  const CheckoutDialog({
    super.key,
    required this.customers,
    required this.onCheckout,
  });

  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  int? _selectedCustomerId;
  String _paymentMethod = 'cash';
  final _discountController = TextEditingController(text: '0');
  final _paidAmountController = TextEditingController();

  bool _isFullPayment = true;

  @override
  void dispose() {
    _discountController.dispose();
    _paidAmountController.dispose();
    super.dispose();
  }

  void _checkout() {
    final discount = double.tryParse(_discountController.text) ?? 0;
    final paidAmount = _isFullPayment ? null : (double.tryParse(_paidAmountController.text) ?? 0);
    widget.onCheckout(_selectedCustomerId, _paymentMethod, discount, paidAmount);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SalesBloc, SalesState>(
      builder: (context, state) {
        double subtotal = 0;
        if (state is SalesReady) {
          subtotal = state.subtotal;
        }
        final discount = double.tryParse(_discountController.text) ?? 0;
        final total = subtotal - discount;

        final loc = LocalizationService();
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 30),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.shopping_cart_checkout, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          loc.get('completeSale'),
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                // Body
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Order summary
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${loc.get('subtotal')}:'),
                                  Text('₪${subtotal.toStringAsFixed(2)}'),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${loc.get('discount')}:', style: const TextStyle(color: AppColors.success)),
                                  Text(
                                    '-₪${discount.toStringAsFixed(2)}',
                                    style: const TextStyle(color: AppColors.success),
                                  ),
                                ],
                              ),
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${loc.get('total')}:',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                  ),
                                  Text(
                                    '₪${total.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Customer selection with search
                        Autocomplete<Customer>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return widget.customers;
                            }
                            return widget.customers.where((customer) =>
                                customer.name.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                                (customer.phone?.contains(textEditingValue.text) ?? false));
                          },
                          displayStringForOption: (Customer customer) => customer.name,
                          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                labelText: loc.get('customerOptional'),
                                prefixIcon: const Icon(Icons.person),
                                hintText: loc.get('searchOrSelectCustomer'),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                suffixIcon: _selectedCustomerId != null || controller.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          controller.clear();
                                          setState(() => _selectedCustomerId = null);
                                        },
                                      )
                                    : null,
                              ),
                            );
                          },
                          optionsViewBuilder: (context, onSelected, options) {
                            return Align(
                              alignment: loc.isArabic ? AlignmentDirectional.topEnd : AlignmentDirectional.topStart,
                              child: Material(
                                elevation: 4,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxHeight: 200, maxWidth: 368),
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: options.length + 1,
                                    itemBuilder: (context, index) {
                                      if (index == 0) {
                                        return ListTile(
                                          leading: const Icon(Icons.person_outline),
                                          title: Text(loc.get('walkInCustomer')),
                                          onTap: () {
                                            setState(() => _selectedCustomerId = null);
                                            FocusManager.instance.primaryFocus?.unfocus();
                                          },
                                        );
                                      }
                                      final customer = options.elementAt(index - 1);
                                      return ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: AppColors.primary.withOpacity(0.1),
                                          child: Text(
                                            customer.name.substring(0, 1).toUpperCase(),
                                            style: const TextStyle(color: AppColors.primary),
                                          ),
                                        ),
                                        title: Text(customer.name),
                                        subtitle: customer.phone != null ? Text(customer.phone!) : null,
                                        trailing: customer.balance > 0
                                            ? Text(
                                                '₪${customer.balance.toStringAsFixed(2)}',
                                                style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                                              )
                                            : null,
                                        onTap: () => onSelected(customer),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                          onSelected: (Customer customer) {
                            setState(() => _selectedCustomerId = customer.id);
                          },
                        ),
                        // Show selected customer badge
                        if (_selectedCustomerId != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Chip(
                              avatar: const Icon(Icons.person, size: 18),
                              label: Text(
                                widget.customers.firstWhere((c) => c.id == _selectedCustomerId).name,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              backgroundColor: AppColors.primary.withOpacity(0.1),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () {
                                setState(() => _selectedCustomerId = null);
                              },
                            ),
                          ),
                        const SizedBox(height: 16),

                        // Payment method
                        Text(
                          loc.get('paymentMethod'),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<String>(
                          segments: [
                            ButtonSegment(
                              value: 'cash',
                              label: Text(loc.get('cash')),
                              icon: const Icon(Icons.money),
                            ),
                            ButtonSegment(
                              value: 'card',
                              label: Text(loc.get('card')),
                              icon: const Icon(Icons.credit_card),
                            ),
                          ],
                          selected: {_paymentMethod},
                          onSelectionChanged: (Set<String> selection) {
                            setState(() {
                              _paymentMethod = selection.first;
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        // Discount
                        TextFormField(
                          controller: _discountController,
                          decoration: InputDecoration(
                            labelText: loc.get('discountAmount'),
                            prefixIcon: const Icon(Icons.discount),
                            prefixText: '₪',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                          ],
                          onChanged: (value) {
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 16),

                        // Payment type toggle (Full / Partial)
                        Text(
                          loc.get('paymentType'),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<bool>(
                          segments: [
                            ButtonSegment(
                              value: true,
                              label: Text(loc.get('fullPayment')),
                              icon: const Icon(Icons.check_circle, size: 18),
                            ),
                            ButtonSegment(
                              value: false,
                              label: Text(loc.get('partialPayment')),
                              icon: const Icon(Icons.hourglass_bottom, size: 18),
                            ),
                          ],
                          selected: {_isFullPayment},
                          onSelectionChanged: (Set<bool> selection) {
                            setState(() {
                              _isFullPayment = selection.first;
                              if (_isFullPayment) {
                                _paidAmountController.clear();
                              } else {
                                _paidAmountController.text = total.toStringAsFixed(2);
                              }
                            });
                          },
                        ),

                        // Paid amount field (only if partial payment)
                        if (!_isFullPayment) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _paidAmountController,
                            decoration: InputDecoration(
                              labelText: loc.get('paidAmount'),
                              prefixIcon: const Icon(Icons.payments),
                              prefixText: '₪',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              helperText: '${loc.get('remaining')}: ₪${(total - (double.tryParse(_paidAmountController.text) ?? 0)).toStringAsFixed(2)}',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                            ],
                            onChanged: (value) {
                              setState(() {});
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // Actions
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(loc.get('cancel')),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _checkout,
                        icon: const Icon(Icons.check, size: 18),
                        label: Text(loc.get('completeSale')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
}
