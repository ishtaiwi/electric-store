import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_strings.dart';
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

        return AlertDialog(
          title: const Text(AppStrings.checkout),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order summary
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${LocalizationService().get('subtotal')}:'),
                          Text('₪${subtotal.toStringAsFixed(2)}'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${LocalizationService().get('discount')}:', style: const TextStyle(color: AppColors.success)),
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
                            '${LocalizationService().get('total')}:',
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
                    // Always include walk-in option at the top
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
                        labelText: LocalizationService().get('customerOptional'),
                        prefixIcon: const Icon(Icons.person),
                        hintText: LocalizationService().get('searchOrSelectCustomer'),
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
                      alignment: LocalizationService().isArabic ? AlignmentDirectional.topEnd : AlignmentDirectional.topStart,
                      child: Material(
                        elevation: 4,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200, maxWidth: 368),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length + 1, // +1 for walk-in option
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                // Walk-in customer option
                                return ListTile(
                                  leading: const Icon(Icons.person_outline),
                                  title: Text(LocalizationService().get('walkInCustomer')),
                                  onTap: () {
                                    setState(() => _selectedCustomerId = null);
                                    // Close autocomplete dropdown by removing focus
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
                  LocalizationService().get('paymentMethod'),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'cash',
                      label: Text(LocalizationService().get('cash')),
                      icon: const Icon(Icons.money),
                    ),
                    ButtonSegment(
                      value: 'card',
                      label: Text(LocalizationService().get('card')),
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
                    labelText: LocalizationService().get('discountAmount'),
                    prefixIcon: const Icon(Icons.discount),
                    prefixText: '₪',
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
                  LocalizationService().get('paymentType'),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: true,
                      label: Text(LocalizationService().get('fullPayment')),
                      icon: const Icon(Icons.check_circle, size: 18),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text(LocalizationService().get('partialPayment')),
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
                      labelText: LocalizationService().get('paidAmount'),
                      prefixIcon: const Icon(Icons.payments),
                      prefixText: '₪',
                      helperText: '${LocalizationService().get('remaining')}: ₪${(total - (double.tryParse(_paidAmountController.text) ?? 0)).toStringAsFixed(2)}',
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(AppStrings.cancel),
            ),
            ElevatedButton.icon(
              onPressed: _checkout,
              icon: const Icon(Icons.check),
              label: Text(LocalizationService().get('completeSale')),
            ),
          ],
        );
      },
    );
  }
}
