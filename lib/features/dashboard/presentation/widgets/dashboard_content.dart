import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../reports/presentation/bloc/report_bloc.dart';

class DashboardContent extends StatelessWidget {
  final Function(int)? onNavigate;
  
  const DashboardContent({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;
    final l10n = LocalizationService();
    final now = DateTime.now();
    final greeting = _getGreeting(now);

    return BlocBuilder<ReportBloc, ReportState>(
      builder: (context, state) {
        Map<String, dynamic> stats = {};
        if (state is ReportDashboardLoaded) {
          stats = state.stats;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Header
              _buildWelcomeHeader(context, user, greeting, now, l10n),
              const SizedBox(height: 32),

              // Quick Access Section
              _buildSectionTitle(context, l10n.get('quickAccess'), Icons.apps),
              const SizedBox(height: 16),
              _buildQuickAccessGrid(context, l10n),
              const SizedBox(height: 32),

              // Alerts & Statistics Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Alerts Section
                  Expanded(
                    flex: 1,
                    child: _buildAlertsSection(context, stats, l10n, state is ReportLoading),
                  ),
                  const SizedBox(width: 24),
                  // Today's Summary
                  Expanded(
                    flex: 1,
                    child: _buildTodaySummary(context, stats, l10n, state is ReportLoading),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Quick Actions Section
              _buildSectionTitle(context, l10n.get('quickActions'), Icons.flash_on),
              const SizedBox(height: 16),
              _buildQuickActions(context, l10n),
            ],
          ),
        );
      },
    );
  }

  String _getGreeting(DateTime now) {
    final hour = now.hour;
    if (hour < 12) {
      return LocalizationService().get('goodMorning');
    } else if (hour < 17) {
      return LocalizationService().get('goodAfternoon');
    } else {
      return LocalizationService().get('goodEvening');
    }
  }

  Widget _buildWelcomeHeader(BuildContext context, dynamic user, String greeting, DateTime now, LocalizationService l10n) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, ${user?.fullName ?? 'User'}!',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('EEEE, MMMM d, y').format(now),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('hh:mm a').format(now),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.electrical_services,
              size: 48,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAccessGrid(BuildContext context, LocalizationService l10n) {
    final items = [
      _QuickAccessItem(
        icon: Icons.point_of_sale,
        label: l10n.get('sales'),
        color: AppColors.success,
        pageIndex: 1,
        description: l10n.get('newSale'),
      ),
      _QuickAccessItem(
        icon: Icons.inventory_2,
        label: l10n.get('products'),
        color: AppColors.primary,
        pageIndex: 3,
        description: l10n.get('manageInventory'),
      ),
      _QuickAccessItem(
        icon: Icons.people,
        label: l10n.get('customers'),
        color: AppColors.info,
        pageIndex: 4,
        description: l10n.get('customerManagement'),
      ),
      _QuickAccessItem(
        icon: Icons.receipt_long,
        label: l10n.get('invoices'),
        color: AppColors.secondary,
        pageIndex: 5,
        description: l10n.get('viewInvoices'),
      ),
      _QuickAccessItem(
        icon: Icons.money_off,
        label: l10n.get('expenses'),
        color: AppColors.error,
        pageIndex: 6,
        description: l10n.get('trackExpenses'),
      ),
      _QuickAccessItem(
        icon: Icons.local_shipping,
        label: l10n.get('suppliers'),
        color: Colors.orange,
        pageIndex: 7,
        description: l10n.get('suppliers'),
      ),
      _QuickAccessItem(
        icon: Icons.list_alt,
        label: l10n.get('priceLists'),
        color: Colors.purple,
        pageIndex: 8,
        description: l10n.get('priceLists'),
      ),
      _QuickAccessItem(
        icon: Icons.backup,
        label: l10n.get('backup'),
        color: Colors.teal,
        pageIndex: 9,
        description: l10n.get('backupData'),
      ),
      _QuickAccessItem(
        icon: Icons.settings,
        label: l10n.get('settings'),
        color: Colors.grey,
        pageIndex: 10,
        description: l10n.get('systemSettings'),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.5,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _QuickAccessCard(item: item, onNavigate: onNavigate);
      },
    );
  }

  Widget _buildAlertsSection(BuildContext context, Map<String, dynamic> stats, LocalizationService l10n, bool isLoading) {
    final lowStockCount = stats['lowStockCount'] ?? 0;
    final totalDebts = stats['totalDebts'] ?? 0.0;
    final outOfStockCount = stats['outOfStockCount'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active, color: AppColors.warning),
              const SizedBox(width: 8),
              Text(
                l10n.get('alerts'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 20),
          _AlertItem(
            icon: Icons.warning_amber,
            title: l10n.get('lowStockItems'),
            value: '$lowStockCount ${l10n.get('items')}',
            color: lowStockCount > 0 ? AppColors.warning : AppColors.success,
            isAlert: lowStockCount > 0,
          ),
          const SizedBox(height: 12),
          _AlertItem(
            icon: Icons.remove_shopping_cart,
            title: l10n.get('outOfStock'),
            value: '$outOfStockCount ${l10n.get('items')}',
            color: outOfStockCount > 0 ? AppColors.error : AppColors.success,
            isAlert: outOfStockCount > 0,
          ),
          const SizedBox(height: 12),
          _AlertItem(
            icon: Icons.account_balance_wallet,
            title: l10n.get('customerDebts'),
            value: '₪${_formatNumber(totalDebts)}',
            color: totalDebts > 0 ? AppColors.error : AppColors.success,
            isAlert: totalDebts > 0,
          ),
        ],
      ),
    );
  }

  Widget _buildTodaySummary(BuildContext context, Map<String, dynamic> stats, LocalizationService l10n, bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.today, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                l10n.get('todaySummary'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: () {
                  context.read<ReportBloc>().add(ReportLoadDashboard());
                },
                tooltip: l10n.get('refresh'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SummaryItem(
            icon: Icons.point_of_sale,
            title: l10n.get('todaySales'),
            value: '₪${_formatNumber(stats['todaySales'])}',
            color: AppColors.success,
          ),
          const SizedBox(height: 12),
          _SummaryItem(
            icon: Icons.trending_up,
            title: l10n.get('todayProfit'),
            value: '₪${_formatNumber(stats['todayProfit'])}',
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          _SummaryItem(
            icon: Icons.receipt,
            title: l10n.get('todayInvoices'),
            value: '${stats['todayInvoiceCount'] ?? 0}',
            color: AppColors.info,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, LocalizationService l10n) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionButton(
            icon: Icons.add_shopping_cart,
            label: l10n.get('newSale'),
            color: AppColors.success,
            onTap: () => onNavigate?.call(1),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.add_box,
            label: l10n.get('addProduct'),
            color: AppColors.primary,
            onTap: () => onNavigate?.call(3),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.person_add,
            label: l10n.get('addCustomer'),
            color: AppColors.info,
            onTap: () => onNavigate?.call(4),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.receipt_long,
            label: l10n.get('viewInvoices'),
            color: AppColors.secondary,
            onTap: () => onNavigate?.call(5),
          ),
        ),
      ],
    );
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '0.00';
    final number = value is num ? value.toDouble() : 0.0;
    return NumberFormat('#,##0.00').format(number);
  }
}

class _QuickAccessItem {
  final IconData icon;
  final String label;
  final Color color;
  final int pageIndex;
  final String description;

  _QuickAccessItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.pageIndex,
    required this.description,
  });
}

class _QuickAccessCard extends StatefulWidget {
  final _QuickAccessItem item;
  final Function(int)? onNavigate;

  const _QuickAccessCard({required this.item, this.onNavigate});

  @override
  State<_QuickAccessCard> createState() => _QuickAccessCardState();
}

class _QuickAccessCardState extends State<_QuickAccessCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => widget.onNavigate?.call(widget.item.pageIndex),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _isHovered ? widget.item.color.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered ? widget.item.color : Colors.grey.withOpacity(0.2),
              width: _isHovered ? 2 : 1,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: widget.item.color.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.item.color.withOpacity(_isHovered ? 0.2 : 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.item.icon,
                  color: widget.item.color,
                  size: _isHovered ? 32 : 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.item.label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: _isHovered ? widget.item.color : AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                widget.item.description,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final bool isAlert;

  const _AlertItem({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    required this.isAlert,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAlert ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: isAlert ? Border.all(color: color.withOpacity(0.3)) : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isAlert ? color : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (isAlert)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _SummaryItem({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: _isHovered ? widget.color : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.color, width: 2),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: widget.color.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                color: _isHovered ? Colors.white : widget.color,
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _isHovered ? Colors.white : widget.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
