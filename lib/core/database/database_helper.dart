import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  
  /// Custom database path - set this before accessing the database
  /// to use an existing database file
  static String? customDbPath;
  
  /// Flag to use test database instead of production
  static bool useTestDatabase = false;
  static const String testDbName = 'test_data.db';

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path;
    
    // Determine which database file name to use
    final dbFileName = useTestDatabase ? testDbName : 'd.db';
    
    // Fast path: Check common locations first
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final exeDbPath = join(exeDir, dbFileName);
    final cwdDbPath = join(Directory.current.path, dbFileName);
    final projectDbPath = 'c:\\Users\\osama\\Desktop\\electricalStore\\$dbFileName';
    
    // Check paths in parallel for faster startup
    final pathChecks = await Future.wait([
      customDbPath != null ? File(customDbPath!).exists() : Future.value(false),
      File(exeDbPath).exists(),
      File(cwdDbPath).exists(),
      File(projectDbPath).exists(),
    ]);
    
    if (customDbPath != null && pathChecks[0]) {
      path = customDbPath!;
    } else if (pathChecks[1]) {
      path = exeDbPath;
    } else if (pathChecks[2]) {
      path = cwdDbPath;
    } else if (pathChecks[3]) {
      path = projectDbPath;
    } else {
      // Fall back to documents directory with new database
      final directory = await getApplicationDocumentsDirectory();
      path = join(directory.path, 'electrical_store', dbFileName);
      
      // Ensure directory exists
      final dbDir = Directory(dirname(path));
      if (!await dbDir.exists()) {
        await dbDir.create(recursive: true);
      }
    }

    final dbExists = await File(path).exists();
    
    return await openDatabase(
      path,
      version: 12,
      onCreate: dbExists ? null : _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migration: v1 -> v2: Add paid_amount column to invoices
    if (oldVersion < 2) {
      // Check if column already exists
      final tableInfo = await db.rawQuery('PRAGMA table_info(invoices)');
      final hasColumn = tableInfo.any((col) => col['name'] == 'paid_amount');
      if (!hasColumn) {
        await db.execute('ALTER TABLE invoices ADD COLUMN paid_amount REAL DEFAULT 0');
        // Update existing invoices: set paid_amount = final_amount (fully paid)
        await db.execute('UPDATE invoices SET paid_amount = final_amount');
      }
    }
    // Migration: v2 -> v3: Add balance_adjustment column to customers
    if (oldVersion < 3) {
      final tableInfo = await db.rawQuery('PRAGMA table_info(customers)');
      final hasColumn = tableInfo.any((col) => col['name'] == 'balance_adjustment');
      if (!hasColumn) {
        await db.execute('ALTER TABLE customers ADD COLUMN balance_adjustment REAL DEFAULT 0');
      }
    }
    // Migration: v3 -> v4: Add index on invoices.customer_id for faster debt queries
    if (oldVersion < 4) {
      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_invoices_customer ON invoices(customer_id)');
      } catch (_) {
        // Index might already exist
      }
    }
    // Migration: v4 -> v5: Add price_lists and price_list_items tables
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS price_lists (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          customer_id INTEGER REFERENCES customers(id),
          notes TEXT,
          created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS price_list_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          price_list_id INTEGER NOT NULL REFERENCES price_lists(id),
          product_id INTEGER REFERENCES products(id),
          product_name TEXT NOT NULL,
          quantity INTEGER NOT NULL DEFAULT 1,
          unit_price REAL NOT NULL DEFAULT 0,
          total_price REAL NOT NULL DEFAULT 0,
          notes TEXT
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_price_list_items_list ON price_list_items(price_list_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_price_lists_customer ON price_lists(customer_id)');
    }
    // Migration: v5 -> v6: Add notes column to invoices table
    if (oldVersion < 6) {
      final tableInfo = await db.rawQuery('PRAGMA table_info(invoices)');
      final hasColumn = tableInfo.any((col) => col['name'] == 'notes');
      if (!hasColumn) {
        await db.execute('ALTER TABLE invoices ADD COLUMN notes TEXT');
      }
    }
    // Migration: v6 -> v7: Add suppliers, supplier_attachments tables and supplier_id to products
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS suppliers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          phone TEXT,
          address TEXT,
          note TEXT,
          created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS supplier_attachments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          supplier_id INTEGER NOT NULL REFERENCES suppliers(id),
          file_path TEXT NOT NULL,
          file_name TEXT NOT NULL,
          file_type TEXT NOT NULL DEFAULT 'pdf',
          comment TEXT,
          upload_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_supplier_attachments_supplier ON supplier_attachments(supplier_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_suppliers_name ON suppliers(name)');
      // Add supplier_id FK column to products
      final productInfo = await db.rawQuery('PRAGMA table_info(products)');
      final hasSupplierIdCol = productInfo.any((col) => col['name'] == 'supplier_id');
      if (!hasSupplierIdCol) {
        await db.execute('ALTER TABLE products ADD COLUMN supplier_id INTEGER REFERENCES suppliers(id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_products_supplier ON products(supplier_id)');
      }
    }
    // Migration: v7 -> v8: Add comprehensive indexes for performance
    if (oldVersion < 8) {
      await _createPerformanceIndexes(db);
    }
    // Migration: v8 -> v9: Add note column to sales table
    if (oldVersion < 9) {
      final tableInfo = await db.rawQuery('PRAGMA table_info(sales)');
      final hasColumn = tableInfo.any((col) => col['name'] == 'note');
      if (!hasColumn) {
        await db.execute('ALTER TABLE sales ADD COLUMN note TEXT');
      }
    }
    // Migration: v9 -> v10: Add supplier_invoices and supplier_payments tables
    if (oldVersion < 10) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS supplier_invoices (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          supplier_id INTEGER NOT NULL REFERENCES suppliers(id),
          invoice_number TEXT NOT NULL,
          invoice_date TEXT NOT NULL,
          total_amount REAL NOT NULL DEFAULT 0,
          paid_amount REAL NOT NULL DEFAULT 0,
          file_path TEXT,
          file_name TEXT,
          file_type TEXT,
          notes TEXT,
          created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS supplier_payments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          supplier_invoice_id INTEGER NOT NULL REFERENCES supplier_invoices(id),
          amount REAL NOT NULL,
          payment_date TEXT NOT NULL,
          notes TEXT,
          created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_supplier_invoices_supplier ON supplier_invoices(supplier_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_supplier_invoices_number ON supplier_invoices(invoice_number)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_supplier_payments_invoice ON supplier_payments(supplier_invoice_id)');
    }
    // Migration: v10 -> v11: Add payment_method and cheque_number to supplier_payments
    if (oldVersion < 11) {
      final tableInfo = await db.rawQuery('PRAGMA table_info(supplier_payments)');
      final hasPaymentMethod = tableInfo.any((col) => col['name'] == 'payment_method');
      if (!hasPaymentMethod) {
        await db.execute("ALTER TABLE supplier_payments ADD COLUMN payment_method TEXT DEFAULT 'cash'");
      }
      final hasChequeNumber = tableInfo.any((col) => col['name'] == 'cheque_number');
      if (!hasChequeNumber) {
        await db.execute('ALTER TABLE supplier_payments ADD COLUMN cheque_number TEXT');
      }
    }
    // Migration: v11 -> v12: Add customer_payments table
    if (oldVersion < 12) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS customer_payments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          invoice_id INTEGER NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
          customer_id INTEGER NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
          amount REAL NOT NULL,
          payment_date TEXT NOT NULL,
          payment_method TEXT DEFAULT 'cash',
          cheque_number TEXT,
          notes TEXT,
          created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_customer_payments_invoice ON customer_payments(invoice_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_customer_payments_customer ON customer_payments(customer_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_customer_payments_date ON customer_payments(payment_date)');
      
      // Migrate existing paid amounts into customer_payments records
      // For invoices that have paid_amount > 0, create a legacy payment entry
      await db.execute('''
        INSERT INTO customer_payments (invoice_id, customer_id, amount, payment_date, payment_method, notes)
        SELECT i.id, i.customer_id, i.paid_amount, COALESCE(i.created_date, datetime('now')), i.payment_method, 'Migrated from legacy payment'
        FROM invoices i
        WHERE i.paid_amount > 0 AND i.customer_id IS NOT NULL
      ''');
    }
  }

  /// Creates all performance-critical indexes.
  /// Called from both _onCreate and migration v7->v8.
  Future<void> _createPerformanceIndexes(Database db) async {
    final indexes = [
      // ── Sales table ──
      'CREATE INDEX IF NOT EXISTS idx_sales_invoice ON sales(invoice_id)',
      'CREATE INDEX IF NOT EXISTS idx_sales_customer ON sales(customer_id)',
      'CREATE INDEX IF NOT EXISTS idx_sales_product ON sales(product_id)',
      'CREATE INDEX IF NOT EXISTS idx_sales_date_invoice ON sales(sale_date, invoice_id)',
      // ── Invoices table ──
      'CREATE INDEX IF NOT EXISTS idx_invoices_sale_date ON invoices(sale_date)',
      'CREATE INDEX IF NOT EXISTS idx_invoices_number ON invoices(invoice_number)',
      'CREATE INDEX IF NOT EXISTS idx_invoices_payment ON invoices(payment_method)',
      'CREATE INDEX IF NOT EXISTS idx_invoices_customer_date ON invoices(customer_id, created_date)',
      // ── Products table ──
      'CREATE INDEX IF NOT EXISTS idx_products_quantity ON products(quantity)',
      'CREATE INDEX IF NOT EXISTS idx_products_low_stock ON products(quantity, min_stock)',
      'CREATE INDEX IF NOT EXISTS idx_products_search ON products(name, barcode)',
      // ── Expenses table ──
      'CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(expense_date)',
      'CREATE INDEX IF NOT EXISTS idx_expenses_category ON expenses(category)',
      'CREATE INDEX IF NOT EXISTS idx_expenses_category_date ON expenses(category, expense_date)',
      // ── Cancelled sales table ──
      'CREATE INDEX IF NOT EXISTS idx_cancelled_sales_product ON cancelled_sales(product_id)',
      // ── Inventory adjustments table ──
      'CREATE INDEX IF NOT EXISTS idx_inventory_adj_product ON inventory_adjustments(product_id)',
      'CREATE INDEX IF NOT EXISTS idx_inventory_adj_product_date ON inventory_adjustments(product_id, adjustment_date)',
      // ── Budget table ──
      'CREATE INDEX IF NOT EXISTS idx_budget_year_month ON budget(year, month)',
      // ── Additional income table ──
      'CREATE INDEX IF NOT EXISTS idx_additional_income_date ON additional_income(income_date)',
      // ── Customers table ──
      'CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(name)',
      // ── Suppliers table ──
      'CREATE INDEX IF NOT EXISTS idx_suppliers_phone ON suppliers(phone)',
    ];
    for (final sql in indexes) {
      try {
        await db.execute(sql);
      } catch (_) {
        // Index may already exist
      }
    }
    // Run ANALYZE so the query planner uses the new indexes
    try {
      await db.execute('ANALYZE');
    } catch (_) {}
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA journal_mode = WAL');
    await db.execute('PRAGMA synchronous = NORMAL');
    await db.execute('PRAGMA cache_size = -20000');  // 20MB cache
    await db.execute('PRAGMA temp_store = MEMORY');
    await db.execute('PRAGMA foreign_keys = ON');
    await db.execute('PRAGMA mmap_size = 268435456');  // 256MB memory-mapped I/O
    await db.execute('PRAGMA page_size = 4096');
    await db.execute('PRAGMA optimize');
  }

  Future<void> _onCreate(Database db, int version) async {
    // Suppliers table (must be before products for FK)
    await db.execute('''
      CREATE TABLE suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        note TEXT,
        created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Supplier attachments table
    await db.execute('''
      CREATE TABLE supplier_attachments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_id INTEGER NOT NULL REFERENCES suppliers(id),
        file_path TEXT NOT NULL,
        file_name TEXT NOT NULL,
        file_type TEXT NOT NULL DEFAULT 'pdf',
        comment TEXT,
        upload_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Supplier invoices table
    await db.execute('''
      CREATE TABLE supplier_invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_id INTEGER NOT NULL REFERENCES suppliers(id),
        invoice_number TEXT NOT NULL,
        invoice_date TEXT NOT NULL,
        total_amount REAL NOT NULL DEFAULT 0,
        paid_amount REAL NOT NULL DEFAULT 0,
        file_path TEXT,
        file_name TEXT,
        file_type TEXT,
        notes TEXT,
        created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Supplier payments table
    await db.execute('''
      CREATE TABLE supplier_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_invoice_id INTEGER NOT NULL REFERENCES supplier_invoices(id),
        amount REAL NOT NULL,
        payment_date TEXT NOT NULL,
        payment_method TEXT DEFAULT 'cash',
        cheque_number TEXT,
        notes TEXT,
        created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Customer payments table
    await db.execute('''
      CREATE TABLE customer_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
        customer_id INTEGER NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
        amount REAL NOT NULL,
        payment_date TEXT NOT NULL,
        payment_method TEXT DEFAULT 'cash',
        cheque_number TEXT,
        notes TEXT,
        created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

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
        supplier_id INTEGER REFERENCES suppliers(id),
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
        balance_adjustment REAL DEFAULT 0,
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
        notes TEXT,
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
        invoice_id INTEGER REFERENCES invoices(id),
        note TEXT
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

    // Price lists table (does NOT affect inventory)
    await db.execute('''
      CREATE TABLE price_lists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        customer_id INTEGER REFERENCES customers(id),
        notes TEXT,
        created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Price list items table
    await db.execute('''
      CREATE TABLE price_list_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        price_list_id INTEGER NOT NULL REFERENCES price_lists(id),
        product_id INTEGER REFERENCES products(id),
        product_name TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        unit_price REAL NOT NULL DEFAULT 0,
        total_price REAL NOT NULL DEFAULT 0,
        notes TEXT
      )
    ''');

    // Create core indexes
    await db.execute('CREATE INDEX idx_products_barcode ON products(barcode)');
    await db.execute('CREATE INDEX idx_products_name ON products(name)');
    await db.execute('CREATE INDEX idx_sales_date ON sales(sale_date)');
    await db.execute('CREATE INDEX idx_sales_barcode ON sales(barcode)');
    await db.execute('CREATE INDEX idx_customers_phone ON customers(phone)');
    await db.execute('CREATE INDEX idx_users_username ON users(username)');
    await db.execute('CREATE INDEX idx_inventory_adjustments_date ON inventory_adjustments(adjustment_date)');
    await db.execute('CREATE INDEX idx_invoices_date ON invoices(created_date)');
    await db.execute('CREATE INDEX idx_invoices_customer ON invoices(customer_id)');
    await db.execute('CREATE INDEX idx_cancelled_sales_date ON cancelled_sales(cancel_date)');
    await db.execute('CREATE INDEX idx_cancelled_sales_original ON cancelled_sales(original_sale_id)');
    await db.execute('CREATE INDEX idx_price_list_items_list ON price_list_items(price_list_id)');
    await db.execute('CREATE INDEX idx_price_lists_customer ON price_lists(customer_id)');
    await db.execute('CREATE INDEX idx_suppliers_name ON suppliers(name)');
    await db.execute('CREATE INDEX idx_supplier_attachments_supplier ON supplier_attachments(supplier_id)');
    await db.execute('CREATE INDEX idx_products_supplier ON products(supplier_id)');
    await db.execute('CREATE INDEX idx_supplier_invoices_supplier ON supplier_invoices(supplier_id)');
    await db.execute('CREATE INDEX idx_supplier_invoices_number ON supplier_invoices(invoice_number)');
    await db.execute('CREATE INDEX idx_supplier_payments_invoice ON supplier_payments(supplier_invoice_id)');

    // Create performance indexes (sales, invoices, expenses, etc.)
    await _createPerformanceIndexes(db);

    // Insert default users
    await db.insert('users', {
      'username': 'admin',
      'password': 'admin123',
      'role': 'admin',
      'full_name': 'مدير النظام',
    });

    await db.insert('users', {
      'username': 'manager',
      'password': 'manager123',
      'role': 'manager',
      'full_name': 'مدير المتجر',
    });

    await db.insert('users', {
      'username': 'cashier1',
      'password': 'cashier123',
      'role': 'cashier',
      'full_name': 'كاشير 1',
    });

    // Insert default store settings
    await db.insert('store_settings', {
      'setting_key': 'store_name',
      'setting_value': 'Electrical Store',
    });

    await db.insert('store_settings', {
      'setting_key': 'currency',
      'setting_value': 'USD',
    });

    await db.insert('store_settings', {
      'setting_key': 'tax_rate',
      'setting_value': '0',
    });
  }

  Future<String> getDatabasePath() async {
    final directory = await getApplicationDocumentsDirectory();
    final dbFileName = useTestDatabase ? testDbName : 'd.db';
    return join(directory.path, 'electrical_store', dbFileName);
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  Future<void> resetDatabase() async {
    final path = await getDatabasePath();
    await close();
    await deleteDatabase(path);
    _database = await _initDatabase();
  }
  
  /// Switch to test database mode
  /// Call this before accessing the database for the first time
  static Future<void> switchToTestDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    useTestDatabase = true;
  }
  
  /// Switch to production database mode
  /// Call this before accessing the database for the first time
  static Future<void> switchToProductionDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    useTestDatabase = false;
  }
  
  /// Check if test database exists in the project directory
  static Future<bool> testDatabaseExists() async {
    const projectDbPath = 'c:\\Users\\osama\\Desktop\\electricalStore\\$testDbName';
    return await File(projectDbPath).exists();
  }
}
