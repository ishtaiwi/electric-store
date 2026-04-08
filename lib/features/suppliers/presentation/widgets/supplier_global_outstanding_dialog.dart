import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/supplier_bloc.dart';

class SupplierGlobalOutstandingDialog extends StatefulWidget {
  const SupplierGlobalOutstandingDialog({super.key});

  @override
  State<SupplierGlobalOutstandingDialog> createState() => _SupplierGlobalOutstandingDialogState();
}

class _SupplierGlobalOutstandingDialogState extends State<SupplierGlobalOutstandingDialog> {
  @override
  void initState() {
    super.initState();
    context.read<SupplierBloc>().add(SupplierLoadAllOutstanding());
  }

  @override
  Widget build(BuildContext context) {
    final loc = LocalizationService();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 650,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      loc.get('supplierOutstandingBalances'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: BlocBuilder<SupplierBloc, SupplierState>(
                builder: (context, state) {
                  double globalOutstanding = 0;
                  List<Map<String, dynamic>> allOutstanding = [];

                  if (state is SupplierLoaded) {
                    globalOutstanding = state.globalOutstanding ?? 0;
                    allOutstanding = state.allSuppliersOutstanding ?? [];
                  }

                  return Column(
                    children: [
                      // Global total card
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: globalOutstanding > 0
                                ? [AppColors.error.withOpacity(0.8), AppColors.error]
                                : [AppColors.success.withOpacity(0.8), AppColors.success],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              loc.get('globalOutstanding'),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              LocalizationService().formatCurrency(globalOutstanding),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Suppliers list
                      Expanded(
                        child: allOutstanding.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle_outline,
                                        size: 48, color: AppColors.success),
                                    const SizedBox(height: 8),
                                    Text(
                                      loc.get('noOutstandingBalances'),
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: allOutstanding.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = allOutstanding[index];
                                  final name = item['name'] as String? ?? '';
                                  final phone = item['phone'] as String?;
                                  final totalInvoiced =
                                      (item['total_invoiced'] as num?)?.toDouble() ?? 0;
                                  final totalPaid =
                                      (item['total_paid'] as num?)?.toDouble() ?? 0;
                                  final outstanding =
                                      (item['outstanding'] as num?)?.toDouble() ?? 0;

                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: AppColors.error.withOpacity(0.1),
                                      child: Icon(Icons.person, color: AppColors.error),
                                    ),
                                    title: Text(
                                      name,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (phone != null && phone.isNotEmpty)
                                          Text(phone,
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.textSecondary)),
                                        Row(
                                          children: [
                                            Text(
                                              '${loc.get('totalInvoiced')}: ${LocalizationService().formatCurrency(totalInvoiced)}',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              '${loc.get('totalPaid')}: ${LocalizationService().formatCurrency(totalPaid)}',
                                              style: TextStyle(
                                                  fontSize: 12, color: AppColors.success),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          loc.get('outstandingBalance'),
                                          style: TextStyle(
                                              fontSize: 10, color: AppColors.textSecondary),
                                        ),
                                        Text(
                                          LocalizationService().formatCurrency(outstanding),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: AppColors.error,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
