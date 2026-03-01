import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/customer.dart';
import '../bloc/customer_bloc.dart';
import '../widgets/customer_form_dialog.dart';
import 'customer_account_statement_page.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final _searchController = TextEditingController();
  bool _showDebtOnly = false;
  
  // Store customers locally to prevent disappearing on state changes
  List<Customer> _customers = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCustomerDialog({Customer? customer}) {
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<CustomerBloc>(),
        child: CustomerFormDialog(customer: customer),
      ),
    );
  }

  void _confirmDelete(Customer customer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.confirmDelete),
        content: Text('${LocalizationService().get('confirmDeleteItem')} "${customer.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              this.context.read<CustomerBloc>().add(CustomerDelete(customer.id!));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
  }

  void _showAccountStatement(Customer customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: this.context.read<CustomerBloc>(),
          child: CustomerAccountStatementPage(customer: customer),
        ),
      ),
    ).then((_) {
      // Auto-refresh customers after returning from account statement
      // (payments or deletions may have changed balances)
      this.context.read<CustomerBloc>().add(CustomerRefresh());
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CustomerBloc, CustomerState>(
      listener: (context, state) {
        if (state is CustomerOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.success,
            ),
          );
        } else if (state is CustomerError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      builder: (context, state) {
        // Update cached customers when list is loaded
        if (state is CustomerLoaded) {
          _customers = state.customers;
        }

        List<Customer> customers = _customers;

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
                    LocalizationService().get('customers'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showCustomerDialog(),
                    icon: const Icon(Icons.person_add),
                    label: Text(LocalizationService().get('addCustomer')),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Filters
              Row(
                children: [
                  // Search
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: LocalizationService().get('searchCustomers'),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  context.read<CustomerBloc>().add(CustomerLoadAll());
                                },
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        if (value.isEmpty) {
                          context.read<CustomerBloc>().add(CustomerLoadAll());
                        } else {
                          context.read<CustomerBloc>().add(CustomerSearch(value));
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Debt filter
                  FilterChip(
                    label: Text(LocalizationService().get('withDebt')),
                    selected: _showDebtOnly,
                    onSelected: (selected) {
                      setState(() => _showDebtOnly = selected);
                      if (selected) {
                        context.read<CustomerBloc>().add(CustomerLoadWithDebt());
                      } else {
                        context.read<CustomerBloc>().add(CustomerLoadAll());
                      }
                    },
                    selectedColor: AppColors.error.withOpacity(0.2),
                    checkmarkColor: AppColors.error,
                  ),
                  const SizedBox(width: 8),

                  // Refresh
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _showDebtOnly = false);
                      context.read<CustomerBloc>().add(CustomerRefresh());
                    },
                    tooltip: LocalizationService().get('refresh'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Customers count
              Text(
                '${customers.length} customers',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 8),

              // Data Table
              Expanded(
                child: state is CustomerLoading && _customers.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : Card(
                        child: DataTable2(
                          columnSpacing: 16,
                          horizontalMargin: 16,
                          minWidth: 700,
                          headingRowColor: WidgetStateProperty.all(
                            AppColors.primary.withOpacity(0.1),
                          ),
                          columns: [
                            DataColumn2(label: Text(LocalizationService().get('name')), size: ColumnSize.L),
                            DataColumn2(label: Text(LocalizationService().get('phone')), size: ColumnSize.M),
                            DataColumn2(label: Text(LocalizationService().get('email')), size: ColumnSize.M),
                            DataColumn2(label: Text(LocalizationService().get('balance')), numeric: true),
                            DataColumn2(label: Text(LocalizationService().get('actions')), size: ColumnSize.L),
                          ],
                          rows: customers.map((customer) {
                            return DataRow2(
                              cells: [
                                DataCell(Text(customer.name)),
                                DataCell(Text(customer.phone ?? '-')),
                                DataCell(Text(customer.email ?? '-')),
                                DataCell(
                                  Text(
                                    '₪${customer.balance.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: customer.balance > 0
                                          ? AppColors.error
                                          : AppColors.success,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.receipt_long, size: 20),
                                        onPressed: () => _showAccountStatement(customer),
                                        tooltip: LocalizationService().get('accountStatement'),
                                        color: AppColors.info,
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 20),
                                        onPressed: () => _showCustomerDialog(customer: customer),
                                        tooltip: LocalizationService().get('edit'),
                                        color: AppColors.primary,
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, size: 20),
                                        onPressed: () => _confirmDelete(customer),
                                        tooltip: LocalizationService().get('delete'),
                                        color: AppColors.error,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                          empty: Center(
                            child: Text(LocalizationService().get('noCustomersFound')),
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
