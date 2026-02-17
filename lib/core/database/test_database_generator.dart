import 'dart:io';
import 'dart:math';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Generates a test database with fake data for testing purposes.
/// This creates a separate test_data.db file without affecting the production d.db
class TestDatabaseGenerator {
  static const String testDbName = 'test_data.db';
  static Database? _testDatabase;
  
  final Random _random = Random();
  
  // Electrical product names
  final List<String> _productNames = [
    'LED Light Bulb 9W',
    'LED Light Bulb 12W',
    'LED Light Bulb 15W',
    'Fluorescent Tube 36W',
    'Halogen Lamp 50W',
    'Extension Cord 3m',
    'Extension Cord 5m',
    'Extension Cord 10m',
    'Power Strip 4-way',
    'Power Strip 6-way',
    'Wall Socket Single',
    'Wall Socket Double',
    'Wall Switch Single',
    'Wall Switch Double',
    'Dimmer Switch',
    'Motion Sensor',
    'Smoke Detector',
    'CO Detector',
    'Electrical Tape Black',
    'Electrical Tape White',
    'Electrical Tape Red',
    'Wire 1.5mm Red',
    'Wire 1.5mm Blue',
    'Wire 1.5mm Green',
    'Wire 2.5mm Red',
    'Wire 2.5mm Blue',
    'Wire 2.5mm Green',
    'Wire 4mm Red',
    'Wire 4mm Blue',
    'Circuit Breaker 10A',
    'Circuit Breaker 16A',
    'Circuit Breaker 20A',
    'Circuit Breaker 32A',
    'Fuse Box 4-way',
    'Fuse Box 8-way',
    'Fuse Box 12-way',
    'Junction Box Small',
    'Junction Box Medium',
    'Junction Box Large',
    'Cable Tray 1m',
    'Cable Tray 2m',
    'Cable Clips 100pcs',
    'Wire Connectors Pack',
    'Terminal Block',
    'Multi-meter Digital',
    'Voltage Tester',
    'Wire Stripper',
    'Crimping Tool',
    'Soldering Iron 40W',
    'Soldering Iron 60W',
    'Solder Wire 100g',
    'Heat Shrink Tube Kit',
    'Cable Tie 100pcs',
    'Cable Tie 200pcs',
    'Ceiling Fan 56"',
    'Ceiling Fan 48"',
    'Table Fan 16"',
    'Wall Fan 18"',
    'Exhaust Fan 6"',
    'Exhaust Fan 8"',
    'Doorbell Wired',
    'Doorbell Wireless',
    'Intercom System',
    'CCTV Camera Indoor',
    'CCTV Camera Outdoor',
    'DVR 4 Channel',
    'DVR 8 Channel',
    'UPS 600VA',
    'UPS 1000VA',
    'UPS 1500VA',
    'Voltage Stabilizer 1KVA',
    'Voltage Stabilizer 3KVA',
    'Timer Switch',
    'Photo Sensor',
    'Emergency Light',
    'Exit Sign LED',
    'Spotlight LED 10W',
    'Spotlight LED 30W',
    'Spotlight LED 50W',
    'Strip Light LED 5m',
    'Panel Light LED Round',
    'Panel Light LED Square',
    'Downlight LED 7W',
    'Downlight LED 12W',
    'Track Light LED',
    'Street Light LED 30W',
    'Street Light LED 50W',
    'Garden Light Solar',
    'Wall Light Outdoor',
    'Chandelier Modern',
    'Chandelier Classic',
    'Pendant Light',
    'Desk Lamp LED',
    'Floor Lamp',
    'Night Light',
    'Smart Bulb WiFi',
    'Smart Switch WiFi',
    'Smart Plug WiFi',
    'USB Wall Charger',
    'USB Extension Cord',
    'Surge Protector',
  ];
  
  final List<String> _suppliers = [
    'ElectroMax Trading',
    'Bright Solutions',
    'PowerTech Supplies',
    'LightWorld Co.',
    'Cable Masters',
    'Switch & Socket Ltd',
    'SafeGuard Electric',
    'GreenLight Industries',
    'TechPower Distribution',
    'ElectroParts Hub',
  ];
  
  final List<String> _customerNames = [
    'Ahmed Hassan',
    'Mohamed Ali',
    'Fatima Zahra',
    'Omar Khalid',
    'Sara Ibrahim',
    'Youssef Mahmoud',
    'Layla Ahmed',
    'Karim Mostafa',
    'Nour El-Din',
    'Hana Mohamed',
    'Tarek Saeed',
    'Dina Ashraf',
    'Khaled Nabil',
    'Mariam Hussein',
    'Amir Fawzi',
    'Rania Youssef',
    'Sherif Adel',
    'Mona Gamal',
    'Hassan Mahmoud',
    'Noura Salem',
    'Waleed Farouk',
    'Yasmin Hani',
    'Sameh Ramadan',
    'Aya Mohsen',
    'Mahmoud Shaker',
    'Salma Wahba',
    'Hazem Tawfik',
    'Lina Bassam',
    'Amr Sami',
    'Jana Emad',
  ];
  
  final List<String> _expenseCategories = [
    'Rent',
    'Electricity',
    'Water',
    'Salaries',
    'Transportation',
    'Maintenance',
    'Supplies',
    'Marketing',
    'Insurance',
    'Miscellaneous',
  ];

  /// Generate test database at specified path
  Future<String> generateTestDatabase(String basePath) async {
    final testDbPath = join(basePath, testDbName);
    
    // Delete existing test database if exists
    final testFile = File(testDbPath);
    if (await testFile.exists()) {
      await testFile.delete();
    }
    
    // Create and open database
    _testDatabase = await openDatabase(
      testDbPath,
      version: 2,
      onCreate: _createTables,
      onConfigure: _onConfigure,
    );
    
    // Generate fake data
    await _generateUsers();
    await _generateProducts();
    await _generateCustomers();
    await _generateInvoicesAndSales();
    await _generateExpenses();
    await _generateDiscounts();
    await _generateStoreSettings();
    
    await _testDatabase!.close();
    _testDatabase = null;
    
    return testDbPath;
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA journal_mode = WAL');
    await db.execute('PRAGMA synchronous = NORMAL');
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _createTables(Database db, int version) async {
    // Products table
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        barcode TEXT UNIQUE,
        quantity INTEGER NOT NULL DEFAULT 0,
        price REAL NOT NULL DEFAULT 0,
        cost_price REAL NOT NULL DEFAULT 0,
        note TEXT,
        supplier TEXT,
        min_stock INTEGER DEFAULT 5,
        last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Customers table
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Users table
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'cashier',
        full_name TEXT,
        created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Invoices table
    await db.execute('''
      CREATE TABLE invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT UNIQUE NOT NULL,
        customer_id INTEGER REFERENCES customers(id),
        total_amount REAL NOT NULL DEFAULT 0,
        discount_amount REAL DEFAULT 0,
        final_amount REAL NOT NULL DEFAULT 0,
        paid_amount REAL NOT NULL DEFAULT 0,
        total_profit REAL DEFAULT 0,
        payment_method TEXT DEFAULT 'cash',
        created_by INTEGER REFERENCES users(id),
        created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        sale_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Sales table
    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER REFERENCES products(id),
        barcode TEXT,
        product_name TEXT,
        quantity INTEGER NOT NULL,
        cost_price REAL NOT NULL DEFAULT 0,
        sale_price REAL NOT NULL,
        total_amount REAL NOT NULL,
        profit REAL NOT NULL DEFAULT 0,
        sale_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        customer_id INTEGER REFERENCES customers(id),
        discount_amount REAL DEFAULT 0,
        final_amount REAL NOT NULL,
        invoice_id INTEGER REFERENCES invoices(id)
      )
    ''');

    // Discounts table
    await db.execute('''
      CREATE TABLE discounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        discount_type TEXT NOT NULL,
        discount_value REAL NOT NULL,
        min_amount REAL DEFAULT 0,
        valid_from TIMESTAMP,
        valid_to TIMESTAMP,
        is_active INTEGER DEFAULT 1,
        created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Inventory adjustments table
    await db.execute('''
      CREATE TABLE inventory_adjustments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL REFERENCES products(id),
        adjustment_type TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        reason TEXT,
        user_id INTEGER REFERENCES users(id),
        adjustment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Cancelled sales table
    await db.execute('''
      CREATE TABLE cancelled_sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        original_sale_id INTEGER NOT NULL REFERENCES sales(id),
        product_id INTEGER NOT NULL REFERENCES products(id),
        barcode TEXT,
        product_name TEXT,
        quantity INTEGER NOT NULL,
        cost_price REAL NOT NULL,
        sale_price REAL NOT NULL,
        total_amount REAL NOT NULL,
        profit REAL NOT NULL,
        cancel_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        cancelled_by INTEGER REFERENCES users(id),
        reason TEXT
      )
    ''');

    // Expenses table
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        description TEXT NOT NULL,
        amount REAL NOT NULL,
        expense_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        payment_method TEXT DEFAULT 'cash',
        receipt_number TEXT,
        supplier TEXT,
        notes TEXT,
        user_id INTEGER REFERENCES users(id)
      )
    ''');

    // Additional income table
    await db.execute('''
      CREATE TABLE additional_income (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source TEXT NOT NULL,
        description TEXT NOT NULL,
        amount REAL NOT NULL,
        income_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        payment_method TEXT DEFAULT 'cash',
        receipt_number TEXT,
        notes TEXT,
        user_id INTEGER REFERENCES users(id)
      )
    ''');

    // Budget table
    await db.execute('''
      CREATE TABLE budget (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        monthly_limit REAL NOT NULL,
        year INTEGER NOT NULL,
        month INTEGER NOT NULL,
        current_spent REAL DEFAULT 0,
        notes TEXT,
        created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(category, year, month)
      )
    ''');

    // Store settings table
    await db.execute('''
      CREATE TABLE store_settings (
        id INTEGER PRIMARY KEY,
        setting_key TEXT UNIQUE NOT NULL,
        setting_value TEXT NOT NULL,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Create indexes
    await db.execute('CREATE INDEX idx_products_barcode ON products(barcode)');
    await db.execute('CREATE INDEX idx_products_name ON products(name)');
    await db.execute('CREATE INDEX idx_sales_date ON sales(sale_date)');
    await db.execute('CREATE INDEX idx_sales_barcode ON sales(barcode)');
    await db.execute('CREATE INDEX idx_customers_phone ON customers(phone)');
    await db.execute('CREATE INDEX idx_users_username ON users(username)');
    await db.execute('CREATE INDEX idx_invoices_date ON invoices(created_date)');
  }

  Future<void> _generateUsers() async {
    final users = [
      {'username': 'admin', 'password': 'admin123', 'role': 'admin', 'full_name': 'مدير النظام'},
      {'username': 'manager', 'password': 'manager123', 'role': 'manager', 'full_name': 'مدير المتجر'},
      {'username': 'cashier1', 'password': 'cashier123', 'role': 'cashier', 'full_name': 'كاشير 1'},
      {'username': 'cashier2', 'password': 'cashier456', 'role': 'cashier', 'full_name': 'كاشير 2'},
      {'username': 'testuser', 'password': 'test123', 'role': 'cashier', 'full_name': 'Test User'},
    ];
    
    for (final user in users) {
      await _testDatabase!.insert('users', user);
    }
  }

  Future<void> _generateProducts() async {
    // Generate 150 products
    final Set<String> usedBarcodes = {};
    
    for (int i = 0; i < _productNames.length; i++) {
      final costPrice = _randomPrice(5, 100);
      final profit = costPrice * (_random.nextDouble() * 0.5 + 0.2); // 20-70% profit margin
      final salePrice = costPrice + profit;
      final quantity = _random.nextInt(200) + 5;
      
      String barcode;
      do {
        barcode = _generateBarcode();
      } while (usedBarcodes.contains(barcode));
      usedBarcodes.add(barcode);
      
      await _testDatabase!.insert('products', {
        'name': _productNames[i],
        'barcode': barcode,
        'quantity': quantity,
        'price': _roundToTwo(salePrice),
        'cost_price': _roundToTwo(costPrice),
        'note': _random.nextBool() ? 'High quality product' : null,
        'supplier': _suppliers[_random.nextInt(_suppliers.length)],
        'min_stock': _random.nextInt(10) + 3,
        'last_updated': _randomDate(365).toIso8601String(),
      });
    }
    
    // Add more products with variations
    final variations = ['Small', 'Medium', 'Large', 'Pro', 'Economy', 'Premium'];
    for (int i = 0; i < 50; i++) {
      final baseName = _productNames[_random.nextInt(_productNames.length)];
      final variation = variations[_random.nextInt(variations.length)];
      final productName = '$baseName - $variation';
      
      final costPrice = _randomPrice(5, 150);
      final profit = costPrice * (_random.nextDouble() * 0.5 + 0.2);
      final salePrice = costPrice + profit;
      final quantity = _random.nextInt(150) + 1;
      
      String barcode;
      do {
        barcode = _generateBarcode();
      } while (usedBarcodes.contains(barcode));
      usedBarcodes.add(barcode);
      
      await _testDatabase!.insert('products', {
        'name': productName,
        'barcode': barcode,
        'quantity': quantity,
        'price': _roundToTwo(salePrice),
        'cost_price': _roundToTwo(costPrice),
        'note': null,
        'supplier': _suppliers[_random.nextInt(_suppliers.length)],
        'min_stock': _random.nextInt(10) + 3,
        'last_updated': _randomDate(365).toIso8601String(),
      });
    }
  }

  Future<void> _generateCustomers() async {
    for (int i = 0; i < _customerNames.length; i++) {
      await _testDatabase!.insert('customers', {
        'name': _customerNames[i],
        'phone': _generatePhone(),
        'email': '${_customerNames[i].toLowerCase().replaceAll(' ', '.')}@email.com',
        'address': _generateAddress(),
        'created_date': _randomDate(365 * 2).toIso8601String(),
      });
    }
  }

  Future<void> _generateInvoicesAndSales() async {
    // Get all products
    final products = await _testDatabase!.query('products');
    final customers = await _testDatabase!.query('customers');
    
    // Generate 200 invoices over the last 90 days
    for (int i = 0; i < 200; i++) {
      final invoiceDate = _randomDate(90);
      final customerId = _random.nextBool() ? customers[_random.nextInt(customers.length)]['id'] as int : null;
      final userId = _random.nextInt(4) + 1; // User IDs 1-4
      final invoiceNumber = 'INV-${invoiceDate.year}${invoiceDate.month.toString().padLeft(2, '0')}${invoiceDate.day.toString().padLeft(2, '0')}-${(i + 1).toString().padLeft(4, '0')}';
      
      // Generate 1-5 items per invoice
      final itemCount = _random.nextInt(5) + 1;
      double totalAmount = 0;
      double totalProfit = 0;
      
      // Determine payment method and paid amount
      final paymentMethod = ['cash', 'card'][_random.nextInt(2)];
      
      // Insert invoice first
      final invoiceId = await _testDatabase!.insert('invoices', {
        'invoice_number': invoiceNumber,
        'customer_id': customerId,
        'total_amount': 0,
        'discount_amount': 0,
        'final_amount': 0,
        'paid_amount': 0,
        'total_profit': 0,
        'payment_method': paymentMethod,
        'created_by': userId,
        'created_date': invoiceDate.toIso8601String(),
        'sale_date': invoiceDate.toIso8601String(),
      });
      
      // Generate sales for this invoice
      for (int j = 0; j < itemCount; j++) {
        final product = products[_random.nextInt(products.length)];
        final quantity = _random.nextInt(5) + 1;
        final salePrice = product['price'] as double;
        final costPrice = product['cost_price'] as double;
        final itemTotal = salePrice * quantity;
        final itemProfit = (salePrice - costPrice) * quantity;
        
        await _testDatabase!.insert('sales', {
          'product_id': product['id'],
          'barcode': product['barcode'],
          'product_name': product['name'],
          'quantity': quantity,
          'cost_price': costPrice,
          'sale_price': salePrice,
          'total_amount': itemTotal,
          'profit': itemProfit,
          'sale_date': invoiceDate.toIso8601String(),
          'customer_id': customerId,
          'discount_amount': 0,
          'final_amount': itemTotal,
          'invoice_id': invoiceId,
        });
        
        totalAmount += itemTotal;
        totalProfit += itemProfit;
      }
      
      // Apply random discount sometimes
      final discountAmount = _random.nextInt(10) == 0 ? totalAmount * 0.05 : 0.0;
      final finalAmount = totalAmount - discountAmount;
      
      // Determine paid amount (80% fully paid, 15% partial, 5% unpaid)
      double paidAmount;
      final paymentRoll = _random.nextInt(100);
      if (paymentRoll < 80) {
        paidAmount = finalAmount; // Fully paid
      } else if (paymentRoll < 95) {
        paidAmount = finalAmount * (0.3 + _random.nextDouble() * 0.6); // 30-90% paid
      } else {
        paidAmount = 0; // Unpaid
      }
      
      // Update invoice totals
      await _testDatabase!.update(
        'invoices',
        {
          'total_amount': _roundToTwo(totalAmount),
          'discount_amount': _roundToTwo(discountAmount),
          'final_amount': _roundToTwo(finalAmount),
          'paid_amount': _roundToTwo(paidAmount),
          'total_profit': _roundToTwo(totalProfit),
        },
        where: 'id = ?',
        whereArgs: [invoiceId],
      );
    }
  }

  Future<void> _generateExpenses() async {
    // Generate 50 expenses over the last 90 days
    for (int i = 0; i < 50; i++) {
      final category = _expenseCategories[_random.nextInt(_expenseCategories.length)];
      final expenseDate = _randomDate(90);
      
      await _testDatabase!.insert('expenses', {
        'category': category,
        'description': _getExpenseDescription(category),
        'amount': _randomPrice(50, 2000),
        'expense_date': expenseDate.toIso8601String(),
        'payment_method': ['cash', 'card', 'bank_transfer'][_random.nextInt(3)],
        'receipt_number': 'REC-${_random.nextInt(99999).toString().padLeft(5, '0')}',
        'supplier': category == 'Supplies' ? _suppliers[_random.nextInt(_suppliers.length)] : null,
        'notes': _random.nextBool() ? 'Regular expense' : null,
        'user_id': _random.nextInt(4) + 1,
      });
    }
  }

  Future<void> _generateDiscounts() async {
    final discounts = [
      {'name': 'New Customer Discount', 'discount_type': 'percentage', 'discount_value': 5.0, 'min_amount': 100.0, 'is_active': 1},
      {'name': 'Bulk Purchase Discount', 'discount_type': 'percentage', 'discount_value': 10.0, 'min_amount': 500.0, 'is_active': 1},
      {'name': 'Loyalty Discount', 'discount_type': 'percentage', 'discount_value': 7.5, 'min_amount': 200.0, 'is_active': 1},
      {'name': 'Fixed Coupon 20', 'discount_type': 'fixed', 'discount_value': 20.0, 'min_amount': 150.0, 'is_active': 1},
      {'name': 'Special Offer', 'discount_type': 'percentage', 'discount_value': 15.0, 'min_amount': 1000.0, 'is_active': 0},
    ];
    
    for (final discount in discounts) {
      await _testDatabase!.insert('discounts', discount);
    }
  }

  Future<void> _generateStoreSettings() async {
    final settings = [
      {'setting_key': 'store_name', 'setting_value': 'Test Electrical Store'},
      {'setting_key': 'currency', 'setting_value': 'USD'},
      {'setting_key': 'tax_rate', 'setting_value': '0'},
      {'setting_key': 'store_phone', 'setting_value': '+1-555-0123'},
      {'setting_key': 'store_address', 'setting_value': '123 Test Street, Test City'},
      {'setting_key': 'receipt_footer', 'setting_value': 'Thank you for your purchase!'},
    ];
    
    for (final setting in settings) {
      await _testDatabase!.insert('store_settings', setting);
    }
  }

  // Helper methods
  String _generateBarcode() {
    final prefix = '978';
    final middle = _random.nextInt(999999999).toString().padLeft(9, '0');
    return '$prefix$middle';
  }

  String _generatePhone() {
    return '+1-${_random.nextInt(999).toString().padLeft(3, '0')}-${_random.nextInt(999).toString().padLeft(3, '0')}-${_random.nextInt(9999).toString().padLeft(4, '0')}';
  }

  String _generateAddress() {
    final streets = ['Main St', 'Oak Ave', 'Park Blvd', 'Market St', 'Broadway', 'First Ave', 'Second St', 'El-Nasr St', 'Al-Tahrir Sq', 'Industrial Zone'];
    final cities = ['Cairo', 'Alexandria', 'Giza', 'Luxor', 'Aswan', 'New York', 'Los Angeles', 'Chicago'];
    return '${_random.nextInt(999) + 1} ${streets[_random.nextInt(streets.length)]}, ${cities[_random.nextInt(cities.length)]}';
  }

  double _randomPrice(double min, double max) {
    return _roundToTwo(min + _random.nextDouble() * (max - min));
  }

  double _roundToTwo(double value) {
    return (value * 100).round() / 100;
  }

  DateTime _randomDate(int daysBack) {
    final now = DateTime.now();
    final daysAgo = _random.nextInt(daysBack);
    return now.subtract(Duration(days: daysAgo, hours: _random.nextInt(24), minutes: _random.nextInt(60)));
  }

  String _getExpenseDescription(String category) {
    final descriptions = {
      'Rent': ['Monthly rent payment', 'Shop rent', 'Storage rent'],
      'Electricity': ['Monthly electricity bill', 'Electricity payment'],
      'Water': ['Water bill payment', 'Monthly water'],
      'Salaries': ['Employee salary', 'Staff payment', 'Monthly wages'],
      'Transportation': ['Delivery cost', 'Shipping fee', 'Transport expense'],
      'Maintenance': ['Shop repair', 'Equipment maintenance', 'Fixing AC'],
      'Supplies': ['Office supplies', 'Packaging materials', 'Cleaning supplies'],
      'Marketing': ['Advertising', 'Flyers printing', 'Social media ads'],
      'Insurance': ['Shop insurance', 'Annual insurance premium'],
      'Miscellaneous': ['Various expenses', 'Other costs', 'Petty cash'],
    };
    final list = descriptions[category] ?? ['General expense'];
    return list[_random.nextInt(list.length)];
  }
}
