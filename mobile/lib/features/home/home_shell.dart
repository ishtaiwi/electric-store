import 'package:flutter/material.dart';

import '../../data/auth_product_repos.dart';
import '../../data/customer_repository.dart';
import '../../data/models.dart';
import '../../data/sales_repository.dart';
import '../customers/customers_page.dart';
import '../products/products_page.dart';
import '../sales/sales_page.dart';
import '../sales/trial_invoices_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.user,
    required this.products,
    required this.customers,
    required this.sales,
    required this.onLogout,
  });

  final AppUser user;
  final ProductRepository products;
  final CustomerRepository customers;
  final SalesRepository sales;
  final VoidCallback onLogout;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  /// A tab is only built the first time it is opened, so logging in does not
  /// fire the network requests of all three screens at once.
  final Set<int> _visited = {0};

  static const _titles = ['المنتجات', 'بيع', 'العملاء'];

  Widget _pageAt(int i) {
    switch (i) {
      case 0:
        return ProductsPage(repository: widget.products, user: widget.user);
      case 1:
        return SalesPage(
          sales: widget.sales,
          products: widget.products,
          user: widget.user,
        );
      default:
        return CustomersPage(repository: widget.customers, user: widget.user);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = List<Widget>.generate(
      _titles.length,
      (i) => _visited.contains(i) ? _pageAt(i) : const SizedBox.shrink(),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          if (_index == 1)
            IconButton(
              tooltip: 'الفواتير التجريبية',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TrialInvoicesPage(sales: widget.sales),
                  ),
                );
              },
              icon: const Icon(Icons.history),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                widget.user.fullName ?? widget.user.username,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
          IconButton(
            tooltip: 'تسجيل الخروج',
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() {
          _index = i;
          _visited.add(i);
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'المنتجات',
          ),
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale),
            label: 'بيع',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'العملاء',
          ),
        ],
      ),
    );
  }
}
