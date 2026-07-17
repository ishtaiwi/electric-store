-- ============================================================
-- Electrical Store Management System - Database Schema
-- Source of truth: live database d.db (PRAGMA user_version = 14)
-- Synced from existing DB + app create/migrate paths
-- ============================================================

-- ============================================================
-- PRAGMA Configuration
-- ============================================================
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA cache_size = -20000;  -- 20MB cache (negative = KiB)
PRAGMA temp_store = MEMORY;
PRAGMA foreign_keys = ON;
PRAGMA mmap_size = 268435456;  -- 256MB memory-mapped I/O
PRAGMA page_size = 4096;

-- ============================================================
-- TABLES
-- (order respects foreign keys)
-- ============================================================

-- Users table
-- System users (admin, manager, cashier)
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'cashier',
    full_name TEXT,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Suppliers table
CREATE TABLE suppliers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    phone TEXT,
    address TEXT,
    note TEXT,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Customers table
CREATE TABLE customers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    phone TEXT,
    email TEXT,
    address TEXT,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    balance_adjustment REAL DEFAULT 0
);

-- Products table
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
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    supplier_id INTEGER REFERENCES suppliers(id)
);

-- Invoices table
CREATE TABLE invoices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    invoice_number TEXT UNIQUE NOT NULL,
    customer_id INTEGER REFERENCES customers(id),
    total_amount REAL NOT NULL,
    discount_amount REAL DEFAULT 0,
    final_amount REAL NOT NULL,
    payment_method TEXT DEFAULT 'cash',
    created_by INTEGER REFERENCES users(id),
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total_profit REAL DEFAULT 0,
    sale_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    paid_amount REAL DEFAULT 0,
    notes TEXT,
    customer_name TEXT
);

-- Sales table (line items)
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
    customer_id INTEGER,
    discount_amount REAL DEFAULT 0,
    final_amount REAL NOT NULL DEFAULT 0,
    invoice_id INTEGER,
    note TEXT
);

-- Customer payments (ledger credits against invoices)
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
);

-- Discounts table
CREATE TABLE discounts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    discount_type TEXT NOT NULL,
    discount_value REAL NOT NULL,
    min_amount REAL DEFAULT 0,
    valid_from TIMESTAMP,
    valid_to TIMESTAMP,
    is_active BOOLEAN DEFAULT 1,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Inventory adjustments table
CREATE TABLE inventory_adjustments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id INTEGER NOT NULL REFERENCES products(id),
    adjustment_type TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    reason TEXT,
    user_id INTEGER REFERENCES users(id),
    adjustment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Cancelled sales table
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
);

-- Expenses table
CREATE TABLE expenses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    category TEXT NOT NULL,
    description TEXT NOT NULL,
    amount REAL NOT NULL,
    expense_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    payment_method TEXT DEFAULT 'نقدي',
    receipt_number TEXT,
    supplier TEXT,
    notes TEXT,
    user_id INTEGER REFERENCES users(id)
);

-- Additional income table
CREATE TABLE additional_income (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source TEXT NOT NULL,
    description TEXT NOT NULL,
    amount REAL NOT NULL,
    income_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    payment_method TEXT DEFAULT 'نقدي',
    receipt_number TEXT,
    notes TEXT,
    user_id INTEGER REFERENCES users(id)
);

-- Budget table
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
);

-- Store settings (key-value)
CREATE TABLE store_settings (
    id INTEGER PRIMARY KEY,
    setting_key TEXT UNIQUE NOT NULL,
    setting_value TEXT NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Price lists
CREATE TABLE price_lists (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    customer_id INTEGER REFERENCES customers(id),
    notes TEXT,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Price list items
CREATE TABLE price_list_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    price_list_id INTEGER NOT NULL REFERENCES price_lists(id),
    product_id INTEGER REFERENCES products(id),
    product_name TEXT NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    unit_price REAL NOT NULL DEFAULT 0,
    total_price REAL NOT NULL DEFAULT 0,
    notes TEXT
);

-- Supplier attachments
CREATE TABLE supplier_attachments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    supplier_id INTEGER NOT NULL REFERENCES suppliers(id),
    file_path TEXT NOT NULL,
    file_name TEXT NOT NULL,
    file_type TEXT NOT NULL DEFAULT 'pdf',
    comment TEXT,
    upload_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Supplier invoices
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
);

-- Supplier payments
CREATE TABLE supplier_payments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    supplier_invoice_id INTEGER NOT NULL REFERENCES supplier_invoices(id),
    amount REAL NOT NULL,
    payment_date TEXT NOT NULL,
    notes TEXT,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    payment_method TEXT DEFAULT 'cash',
    cheque_number TEXT
);

-- Audit logs (created at runtime by AuditLoggerService)
CREATE TABLE audit_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    action TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id INTEGER,
    entity_name TEXT,
    user_id INTEGER,
    user_name TEXT,
    old_value TEXT,
    new_value TEXT,
    details TEXT,
    ip_address TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- INDEXES
-- ============================================================

-- Core indexes
CREATE INDEX idx_products_barcode ON products(barcode);
CREATE INDEX idx_products_name ON products(name);
CREATE INDEX idx_sales_date ON sales(sale_date);
CREATE INDEX idx_sales_barcode ON sales(barcode);
CREATE INDEX idx_customers_phone ON customers(phone);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_inventory_adjustments_date ON inventory_adjustments(adjustment_date);
CREATE INDEX idx_invoices_date ON invoices(created_date);
CREATE INDEX idx_invoices_customer ON invoices(customer_id);
CREATE INDEX idx_cancelled_sales_date ON cancelled_sales(cancel_date);
CREATE INDEX idx_cancelled_sales_original ON cancelled_sales(original_sale_id);

-- Feature indexes
CREATE INDEX idx_price_list_items_list ON price_list_items(price_list_id);
CREATE INDEX idx_price_lists_customer ON price_lists(customer_id);
CREATE INDEX idx_suppliers_name ON suppliers(name);
CREATE INDEX idx_supplier_attachments_supplier ON supplier_attachments(supplier_id);
CREATE INDEX idx_products_supplier ON products(supplier_id);
CREATE INDEX idx_supplier_invoices_supplier ON supplier_invoices(supplier_id);
CREATE INDEX idx_supplier_invoices_number ON supplier_invoices(invoice_number);
CREATE INDEX idx_supplier_payments_invoice ON supplier_payments(supplier_invoice_id);
CREATE INDEX idx_customer_payments_invoice ON customer_payments(invoice_id);
CREATE INDEX idx_customer_payments_customer ON customer_payments(customer_id);
CREATE INDEX idx_customer_payments_date ON customer_payments(payment_date);

-- Performance indexes (v8+)
CREATE INDEX idx_sales_invoice ON sales(invoice_id);
CREATE INDEX idx_sales_customer ON sales(customer_id);
CREATE INDEX idx_sales_product ON sales(product_id);
CREATE INDEX idx_sales_product_id ON sales(product_id);
CREATE INDEX idx_sales_date_invoice ON sales(sale_date, invoice_id);
CREATE INDEX idx_invoices_sale_date ON invoices(sale_date);
CREATE INDEX idx_invoices_number ON invoices(invoice_number);
CREATE INDEX idx_invoices_payment ON invoices(payment_method);
CREATE INDEX idx_invoices_customer_date ON invoices(customer_id, created_date);
CREATE INDEX idx_products_quantity ON products(quantity);
CREATE INDEX idx_products_low_stock ON products(quantity, min_stock);
CREATE INDEX idx_products_search ON products(name, barcode, note);
CREATE INDEX idx_expenses_date ON expenses(expense_date);
CREATE INDEX idx_expenses_category ON expenses(category);
CREATE INDEX idx_expenses_category_date ON expenses(category, expense_date);
CREATE INDEX idx_cancelled_sales_product ON cancelled_sales(product_id);
CREATE INDEX idx_inventory_adj_product ON inventory_adjustments(product_id);
CREATE INDEX idx_inventory_adj_product_date ON inventory_adjustments(product_id, adjustment_date);
CREATE INDEX idx_budget_year_month ON budget(year, month);
CREATE INDEX idx_additional_income_date ON additional_income(income_date);
CREATE INDEX idx_customers_name ON customers(name);
CREATE INDEX idx_suppliers_phone ON suppliers(phone);

-- Scalability indexes (v14)
CREATE INDEX idx_invoices_customer_sale_date ON invoices(customer_id, sale_date, id);
CREATE INDEX idx_customer_payments_customer_date ON customer_payments(customer_id, payment_date);
CREATE INDEX idx_sales_customer_invoice ON sales(customer_id, invoice_id);

-- Audit log indexes
CREATE INDEX idx_audit_logs_timestamp ON audit_logs(timestamp);
CREATE INDEX idx_audit_logs_action ON audit_logs(action);
CREATE INDEX idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_logs_user ON audit_logs(user_id);

-- ============================================================
-- DEFAULT DATA
-- ============================================================

INSERT INTO users (username, password, role, full_name) VALUES ('admin', 'admin123', 'admin', 'مدير النظام');
INSERT INTO users (username, password, role, full_name) VALUES ('manager', 'manager123', 'manager', 'مدير المتجر');
INSERT INTO users (username, password, role, full_name) VALUES ('cashier1', 'cashier123', 'cashier', 'كاشير 1');

INSERT INTO store_settings (setting_key, setting_value) VALUES ('store_name', 'Electrical Store');
INSERT INTO store_settings (setting_key, setting_value) VALUES ('currency', 'USD');
INSERT INTO store_settings (setting_key, setting_value) VALUES ('tax_rate', '0');
