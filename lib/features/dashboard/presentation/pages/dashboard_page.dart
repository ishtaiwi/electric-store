import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../widgets/chatbot_widget.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../products/presentation/bloc/product_bloc.dart';
import '../../../products/presentation/pages/products_page.dart';
import '../../../sales/presentation/bloc/sales_bloc.dart';
import '../../../sales/presentation/pages/sales_page.dart';
import '../../../customers/presentation/bloc/customer_bloc.dart';
import '../../../customers/presentation/pages/customers_page.dart';
import '../../../invoices/presentation/bloc/invoice_bloc.dart';
import '../../../invoices/presentation/pages/invoices_page.dart';
import '../../../reports/presentation/bloc/report_bloc.dart';
import '../../../expenses/presentation/bloc/expense_bloc.dart';
import '../../../expenses/presentation/pages/expenses_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../backup/presentation/pages/backup_page.dart';
import '../../../price_lists/presentation/bloc/price_list_bloc.dart';
import '../../../price_lists/presentation/pages/price_lists_page.dart';
import '../../../suppliers/presentation/bloc/supplier_bloc.dart';
import '../../../suppliers/presentation/pages/suppliers_page.dart';
import '../widgets/dashboard_content.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;
  
  // Singleton blocs - loaded once, cached forever
  late final ProductBloc _productBloc;
  late final SalesBloc _salesBloc;
  late final CustomerBloc _customerBloc;
  late final InvoiceBloc _invoiceBloc;
  late final ReportBloc _reportBloc;
  late final ExpenseBloc _expenseBloc;
  late final PriceListBloc _priceListBloc;
  late final SupplierBloc _supplierBloc;
  
  // All pages pre-built for IndexedStack (instant switching)
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // Get all singleton blocs
    _productBloc = di.sl<ProductBloc>();
    _salesBloc = di.sl<SalesBloc>();
    _customerBloc = di.sl<CustomerBloc>();
    _invoiceBloc = di.sl<InvoiceBloc>();
    _reportBloc = di.sl<ReportBloc>();
    _expenseBloc = di.sl<ExpenseBloc>();
    _priceListBloc = di.sl<PriceListBloc>();
    _supplierBloc = di.sl<SupplierBloc>();
    
    // Build all pages once (widgets only, no data loading yet)
    _pages = _buildAllPages();
    
    // Defer all data loading to after the first frame renders
    // This prevents the UI from freezing after login
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  void _loadInitialData() {
    // Load dashboard data first (user sees this immediately)
    _reportBloc.add(ReportLoadDashboard());
    
    // Pre-load sales products after a short delay (most common next action)
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_salesBloc.state is SalesInitial) {
        _salesBloc.add(SalesLoadProducts());
      }
    });
  }
  
  /// Load data for specific tab on demand
  void _loadDataForTab(int tabIndex) {
    switch (tabIndex) {
      case 0: // Dashboard
        // Dashboard data already loaded
        break;
      case 1: // Sales
        if (_salesBloc.state is SalesInitial) {
          _salesBloc.add(SalesLoadProducts());
        }
        if (_customerBloc.state is CustomerInitial) {
          _customerBloc.add(CustomerLoadAll());
        }
        break;
      case 2: // Products
        if (_productBloc.state is ProductInitial) {
          _productBloc.add(ProductLoadAll());
        }
        break;
      case 3: // Customers
        if (_customerBloc.state is CustomerInitial) {
          _customerBloc.add(CustomerLoadAll());
        }
        break;
      case 4: // Invoices
        if (_invoiceBloc.state is InvoiceInitial) {
          _invoiceBloc.add(InvoiceLoadAll());
        }
        break;
      case 5: // Expenses
        if (_expenseBloc.state is ExpenseInitial) {
          _expenseBloc.add(ExpenseLoadAll());
        }
        break;
      case 6: // Suppliers
        if (_supplierBloc.state is SupplierInitial) {
          _supplierBloc.add(SupplierLoadAll());
        }
        break;
      case 7: // Price Lists
        if (_priceListBloc.state is PriceListInitial) {
          _priceListBloc.add(PriceListLoadAll());
        }
        break;
    }
  }

  List<Widget> _buildAllPages() {
    return [
      // 0: Dashboard
      BlocProvider.value(
        value: _reportBloc,
        child: DashboardContent(
          onNavigate: (navIndex) {
            setState(() {
              _selectedIndex = navIndex;
            });
          },
        ),
      ),
      // 1: Sales
      BlocProvider.value(
        value: _salesBloc,
        child: const SalesPage(),
      ),
      // 2: Products
      BlocProvider.value(
        value: _productBloc,
        child: const ProductsPage(),
      ),
      // 3: Customers
      BlocProvider.value(
        value: _customerBloc,
        child: const CustomersPage(),
      ),
      // 4: Invoices
      BlocProvider.value(
        value: _invoiceBloc,
        child: const InvoicesPage(),
      ),
      // 5: Expenses
      BlocProvider.value(
        value: _expenseBloc,
        child: const ExpensesPage(),
      ),
      // 6: Suppliers
      BlocProvider.value(
        value: _supplierBloc,
        child: const SuppliersPage(),
      ),
      // 7: Price Lists
      BlocProvider.value(
        value: _priceListBloc,
        child: const PriceListsPage(),
      ),
      // 8: Backup
      const BackupPage(),
      // 9: Settings
      const SettingsPage(),
    ];
  }

  List<NavigationItem> get _navigationItems => [
    NavigationItem(
      icon: Icons.dashboard,
      label: LocalizationService().get('dashboard'),
    ),
    NavigationItem(
      icon: Icons.point_of_sale,
      label: LocalizationService().get('sales'),
    ),
    NavigationItem(
      icon: Icons.inventory_2,
      label: LocalizationService().get('products'),
    ),
    NavigationItem(
      icon: Icons.people,
      label: LocalizationService().get('customers'),
    ),
    NavigationItem(
      icon: Icons.receipt_long,
      label: LocalizationService().get('invoices'),
    ),
    NavigationItem(
      icon: Icons.money_off,
      label: LocalizationService().get('expenses'),
    ),
    NavigationItem(
      icon: Icons.local_shipping,
      label: LocalizationService().get('suppliers'),
    ),
    NavigationItem(
      icon: Icons.list_alt,
      label: LocalizationService().get('priceLists'),
    ),
    NavigationItem(
      icon: Icons.backup,
      label: LocalizationService().get('backup'),
    ),
    NavigationItem(
      icon: Icons.settings,
      label: LocalizationService().get('settings'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => ChatbotOverlay.show(context),
        backgroundColor: AppColors.primary,
        tooltip: LocalizationService().get('aiAssistant'),
        child: const Icon(Icons.smart_toy, color: Colors.white),
      ),
      body: Row(
        children: [
          // Navigation Rail
          NavigationRail(
            extended: true,
            minExtendedWidth: 200,
            backgroundColor: AppColors.primary,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              // Lazy load data when switching to specific tabs
              _loadDataForTab(index);
              setState(() {
                _selectedIndex = index;
              });
            },
            leading: Column(
              children: [
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.electrical_services,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  LocalizationService().get('appName'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 16),
              ],
            ),
            trailing: SizedBox(
              width: 180,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Divider(color: Colors.white24, height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.white.withOpacity(0.2),
                          child: Text(
                            user?.fullName?.substring(0, 1).toUpperCase() ?? 'U',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.fullName ?? 'User',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                user?.role ?? '',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout, color: Colors.white),
                          onPressed: () {
                            context.read<AuthBloc>().add(AuthLogoutRequested());
                          },
                          tooltip: LocalizationService().get('logout'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            destinations: _navigationItems.map((item) {
              return NavigationRailDestination(
                icon: Icon(item.icon, color: Colors.white70),
                selectedIcon: Icon(item.icon, color: Colors.white),
                label: Text(
                  item.label,
                  style: const TextStyle(color: Colors.white),
                ),
              );
            }).toList(),
            selectedLabelTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelTextStyle: TextStyle(
              color: Colors.white.withOpacity(0.7),
            ),
            indicatorColor: Colors.white.withOpacity(0.2),
          ),

          // Main Content - IndexedStack for instant page switching
          Expanded(
            child: Container(
              color: AppColors.background,
              child: IndexedStack(
                index: _selectedIndex,
                children: _pages,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final String label;

  NavigationItem({required this.icon, required this.label});
}
