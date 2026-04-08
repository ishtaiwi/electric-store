# Electrical Store — Functional Features

> A Flutter desktop (Windows) point-of-sale and inventory management application for an electrical supplies store.  
> Built with Clean Architecture, BLoC state management, SQLite database, Arabic/English bilingual support (RTL), and Israeli New Shekel (₪) currency.

---

## Table of Contents

1. [Authentication](#1-authentication)
2. [Dashboard](#2-dashboard)
3. [Products Management](#3-products-management)
4. [Point of Sale (Sales)](#4-point-of-sale-sales)
5. [All Sales (Sales History)](#5-all-sales-sales-history)
6. [Customers Management](#6-customers-management)
7. [Invoices Management](#7-invoices-management)
8. [Expenses Management](#8-expenses-management)
9. [Suppliers Management](#9-suppliers-management)
10. [Price Lists](#10-price-lists)
11. [Reports & Analytics](#11-reports--analytics)
12. [Backup & Restore](#12-backup--restore)
13. [Settings](#13-settings)
14. [AI Chatbot Assistant](#14-ai-chatbot-assistant)
15. [Smart Search](#15-smart-search)
16. [PDF Generation & Printing](#16-pdf-generation--printing)
17. [Audit Logging](#17-audit-logging)
18. [Caching](#18-caching)
19. [Security](#19-security)
20. [Validation](#20-validation)
21. [Error Handling](#21-error-handling)
22. [Localization (i18n)](#22-localization-i18n)
23. [Database](#23-database)
24. [Installer](#24-installer)

---

## 1. Authentication

- **Login** with username and password (SHA-256 hashed)
- Automatic migration of legacy plaintext passwords to SHA-256
- **Role-based access control** — three roles: Admin, Manager, Cashier
- Default users: `admin/admin123`, `manager/manager123`, `cashier1/cashier123`
- Password change with old password verification
- Session management (Authenticated / Unauthenticated states)
- Audit logging on login, failed login, logout, and user management actions

---

## 2. Dashboard

- **Navigation rail** sidebar with 11 tabs (Dashboard, Sales, All Sales, Products, Customers, Invoices, Expenses, Suppliers, Price Lists, Backup, Settings)
- `IndexedStack` for instant page switching with lazy data loading
- User profile display with role and logout option
- Time-based greeting with localized date/time

### Dashboard Widgets

| Widget | Details |
|---|---|
| **Quick Access Cards** | 10 navigation shortcuts (Sales, All Sales, Products, Customers, Invoices, Expenses, Suppliers, Price Lists, Backup, Settings) |
| **Alerts** | Low stock count, out of stock count, total customer debts |
| **Today's Summary** | Today's sales total, today's profit, today's invoice count |
| **Quick Actions** | New Sale, Add Product, Add Customer, View Invoices |

---

## 3. Products Management

- **Full CRUD** — Create, read, update, delete products
- **DataTable** with columns: Name, Barcode, Notes, Price, Cost Price, Quantity, Status, Actions
- **Search** by name, barcode, or notes
- **Low stock filter** — toggle to show only low/out-of-stock items
- **Stock adjustment** — Stock In / Stock Out / Return with quantity validation and reason tracking
- Inventory adjustment history records
- **Pagination** — 50 products per page with "Load More"
- Profit and profit margin calculation per product
- Automatic cache invalidation on create/update/delete
- Audit logging on all product operations
- Fast in-memory list updates without full DB reload

### Product Fields

`name`, `barcode`, `quantity`, `price`, `costPrice`, `note`, `supplier`, `supplier_id` (FK), `minStock`, `lastUpdated`  
Computed: `profit`, `profitMargin`, `isLowStock`, `isOutOfStock`

---

## 4. Point of Sale (Sales)

- **Split-view layout** — Left: product search & table / Right: shopping cart
- **Barcode-first search** with auto-focus
- **Debounced smart search** with fuzzy, N-gram, and phonetic matching
- Click product row or submit barcode to add to cart (quantity 1)
- **Cart management** — quantity +/−, edit custom price, remove items
- **Custom products** — add unlisted items with manual pricing (no stock deduction)
- **Discount** — flat amount discount proportionally allocated across items
- **Customer selection** — autocomplete search with walk-in option
- **Payment method** — Cash / Card (segmented button)
- **Payment type** — Full / Partial payment; partial requires specifying paid amount
- Credit sales require customer selection
- **Checkout** — DB transaction creates invoice + sale items + updates product stock
- UUID-based invoice numbering
- **Cancel sale** — reverses stock deductions
- Cross-BLoC instant updates (Invoice & Product BLoCs) after checkout
- **Today's invoices** — quick view of invoices created today

---

## 5. All Sales (Sales History)

- **Dedicated tab** for viewing all sales records (separate from POS)
- **DataTable** with comprehensive sales information
- **Search** by invoice number, customer name, or product details
- **Debounced search** with 400ms delay for performance
- **Pagination** with infinite scroll (load more on scroll)
- **Refresh** functionality to reload data
- **Total records count** display
- **Status bar** showing filtered counts and totals
- Fast in-memory filtering without full DB reload

---

## 6. Customers Management

- **Full CRUD** — Create, read, update, delete customers
- **DataTable** with columns: Name, Phone, Email, Balance (color-coded), Actions
- **Search** by name, phone, or email
- **Debt filter** — toggle to show only customers with outstanding debts
- **Account statement** — full-page view of all invoices per customer with expandable item details
- **Balance tracking** — invoice debts + balance adjustments
- **Record payment** — partial or full payment on individual invoices
- **Customer profile dialog** — tabbed view with profile info + invoice list
- **Delete invoice** from customer context
- **Create invoice** directly for a specific customer
- **PDF export** — customer account statement with all invoices and items (multi-page)
- Summary stats: total purchases, total paid, total remaining, paid/unpaid invoice counts

---

## 7. Invoices Management

- **DataTable** listing with filtering controls
- **Date range picker** — defaults to current month
- **Payment method filter** — dropdown (Cash/Card/All)
- **Search** by invoice number or customer name
- **Payment status chips** — Paid (green), Partial (amber), Unpaid (red)
- **Update paid amount** — record partial/full payments inline
- **Update notes** — add/edit invoice notes
- **Delete invoice** with confirmation dialog
- **Print invoice** — direct print via PDF
- **Save PDF** — export invoice PDF with "Open Folder" action
- **Pagination** support
- Persistent state across BLoC state transitions
- Fast cross-BLoC events (`InvoiceAdded` / `InvoiceUpdated`)

---

## 8. Expenses Management

- **Full CRUD** — Create, read, update, delete expenses
- **DataTable** with columns: Date, Category, Description, Amount, Actions
- **Date range filter** — defaults to current month
- **Category filter** — Utilities, Rent, Salaries, Supplies, Maintenance, Shipping, Other (localized labels + icons)
- **Total display** — running total of filtered expenses in ₪
- **Expense count** display
- Fast in-memory updates without full DB reload

### Expense Fields

`category`, `description`, `amount`, `expenseDate`, `paymentMethod` (cash/card), `receiptNumber`, `supplier`, `notes`, `userId`

---

## 9. Suppliers Management

- **Full CRUD** — Create, read, update, delete suppliers
- **DataTable** with columns: Name, Phone, Address, Notes, Actions
- **Search** by name, phone, or address
- **Supplier attachments** — attach PDF or image files to suppliers with comments
- Attachment management dialog with file type detection
- Integration with products — `supplier_id` foreign key in products table
- Supplier count display
- Fast in-memory updates without full DB reload

### Supplier Financial Management

- **Supplier invoices** — upload and store supplier invoices as images or PDFs with invoice number, date, and total amount
- **Payment tracking** — track payment status per invoice: Fully Paid, Partially Paid, Unpaid
- **Record payments** — enter paid amount with auto-calculated remaining balance; supports multiple partial payments per invoice
- **Payment status auto-update** — invoice status and balance update automatically on each payment
- **Financial insights** — total outstanding balance per supplier and globally across all suppliers
- **Account statement** — detailed view per supplier: all invoices, paid amounts, remaining balances, last payment, current balance
- **Global outstanding balances** — overview of all suppliers with outstanding debts, total outstanding across all suppliers
- **Invoice file management** — attached files copied to app-managed directory; cleaned up on delete
- **Cascade deletion** — deleting a supplier removes all associated invoices, payments, and invoice files

### Supplier Fields

`name`, `phone`, `address`, `note`, `createdDate`

### Supplier Attachment Fields

`supplierId`, `filePath`, `fileName`, `fileType` (pdf/image), `comment`, `uploadDate`

### Supplier Invoice Fields

`supplierId`, `invoiceNumber`, `invoiceDate`, `totalAmount`, `paidAmount`, `filePath`, `fileName`, `fileType`, `notes`, `createdDate`  
Computed: `remainingAmount`, `paymentStatus` (paid/partiallyPaid/unpaid)

### Supplier Payment Fields

`supplierInvoiceId`, `amount`, `paymentDate`, `notes`, `createdDate`

---

## 10. Price Lists

- **Full CRUD** — Create, read, update, delete price lists
- **DataTable** with columns: Title, Customer Name, Item Count, Date, Actions
- **Item management** — each price list contains multiple items (product name, quantity, unit price, total price, notes)
- **Customer association** — optional customer linking per price list
- **Search** by title or customer name (client-side filtering)
- **Save PDF** — export price list to PDF
- **Print** — direct print via PDF service
- Auto-calculated totals: `totalAmount`, `itemCount`

---

## 11. Reports & Analytics

| Report | Data Provided |
|---|---|
| **Dashboard Stats** | Today's sales/profit, monthly sales/profit, product count, low/out stock counts, customer count, today's invoice count, inventory value, total customer debts |
| **Daily Sales Report** | Per-sale breakdown: product name, quantity, sale price, total, profit, invoice #, customer name |
| **Profit Report** | Revenue, gross profit, total expenses, lost profit (cancelled), net profit, profit margin % |
| **Inventory Report** | All products with stock status (in_stock / low_stock / out_of_stock), stock value |
| **Customer Debts** | Customers with outstanding balances, invoice count, last purchase date |
| **Best Selling Products** | Top N products by total sold, with revenue and profit |
| **Sales by Category** | Category-grouped sales: quantity sold, revenue, profit |
| **Monthly Sales Trend** | Month-by-month revenue, profit, invoice count for a given year |
| **Combined Report** | All 7 sub-reports loaded together for a date range |

- Dashboard stats use **parallel DB queries** (9 queries simultaneously) for performance
- **30-second cache** for dashboard stats with explicit invalidation

---

## 12. Backup & Restore

- **Create Backup** — user picks destination folder → creates `.zip` backup file
- **Restore from File** — user picks `.db` file → confirmation dialog with warning → restores database
- **Backup history** — scans backup directory for `.zip` files, sorted by date with file sizes
- **Delete backup** — remove old backup files
- Loading indicators during backup/restore operations
- Audit logging on backup/restore actions

---

## 13. Settings

| Section | Fields |
|---|---|
| **Store Information** | Store name (required), Address |
| **Contact Information** | Phone, Email (validated) |
| **Financial Settings** | Tax rate % (0–100 validation), Currency code |
| **Language** | Segmented button: English / العربية with instant live toggle |
| **User Management** | User list with add/delete; Add: username (unique validation), full name, password + confirm; Delete: prevents deleting last admin |
| **System Information** | Read-only: App version, Database info, Platform |

---

## 14. AI Chatbot Assistant

- **Floating overlay** — toggled via FAB on dashboard; backdrop dismissible
- Chat interface with user/bot message bubbles and avatars
- **Typing indicator** with animated dots
- **Quick action chips**: "مبيعات اليوم", "منتجات قليلة", "إجمالي الديون", "مساعدة"
- Clear/reset chat functionality
- Selectable text for copying bot responses

### Natural Language Understanding (14 Intents)

| Intent | Example Queries | Response |
|---|---|---|
| Greeting | مرحبا, hello | Welcome message |
| Customer Balance | رصيد العميل أحمد | Customer's debt from DB |
| Customer Info | معلومات محمد | Full customer record |
| Product Stock | كمية كشاف 50 واط | Product stock quantity |
| Product Price | سعر سلك 2.5 | Product selling price |
| Product Search | ابحث عن مفتاح | Matching products list |
| Today's Sales | مبيعات اليوم | Today's total sales |
| Month Sales | مبيعات الشهر | Current month's sales |
| Top Products | أكثر المنتجات مبيعاً | Top 5 best sellers |
| Low Stock | منتجات قليلة | Low/out of stock products |
| Total Debt | إجمالي الديون | Total customer debts |
| Invoice Info | فاتورة رقم 123 | Invoice details |
| Help | مساعدة | Available commands list |
| Unknown | (anything else) | Fallback suggestion message |

### NLU Engine

- Arabic + English regex-based intent detection
- **Entity extraction** — wattage (Arabic number words: واحد→1, عشرين→20, etc.), brand names with variation handling, product type synonyms
- **Direct DB queries** — real-time data from SQLite for every response
- **Currency formatting** — ₪ with 2 decimal places

---

## 15. Smart Search

Four-strategy search pipeline:

1. **Exact token matching** — direct string containment
2. **Fuzzy matching** — edit distance / Levenshtein
3. **N-gram matching** — character trigram similarity
4. **Phonetic matching** — Arabic letter normalization (ا/أ/إ/آ, ه/ة, ي/ى)

Additional capabilities:
- Learns from database — builds brand/product-type dictionaries dynamically
- Arabic synonym dictionaries for electrical products (كشاف, سلك, مفتاح, etc.)
- Brand variation handling
- Arabic number word parsing
- Wattage, size, and color extraction from queries

---

## 16. PDF Generation & Printing

- **Invoice PDF** — store header, bill-to section, items table, totals with discount, notes, footer
- **Customer Statement PDF** — multi-page with all invoices and items per customer
- **Price List PDF** — price list with items table and totals
- Arabic font loading from Windows system fonts (Tahoma, Arial, Segoe UI)
- Direct **print** and **save-to-file** support

---

## 17. Audit Logging

- Dedicated `audit_logs` table (created dynamically)
- Logs all significant actions:
  - Login / Logout / Failed login
  - CRUD operations on all entities (products, customers, invoices, expenses, etc.)
  - Backup / Restore operations
  - Settings changes
  - Stock adjustments
  - System errors
- Filtering support by action, entity, user, and date range

---

## 18. Caching

- **In-memory cache** with configurable TTL:
  - Default: 5 minutes
  - Short: 1 minute
  - Long: 30 minutes
- Key pattern-based invalidation
- Dedicated cache keys for products, customers, dashboard stats, etc.
- Automatic invalidation on data mutations

---

## 19. Security

- **SHA-256 password hashing** with salt
- Input sanitization
- Email, phone, and numeric validation
- Data masking for logging (sensitive data protection)

---

## 20. Validation

- Field-level validation for all entities:
  - **Products** — name, barcode format, price, quantity, min stock
  - **Customers** — name, phone, email
  - **Invoices** — amounts, dates, customer references
  - **Expenses** — category, amount, date
  - **Sales items** — quantity, pricing
- Localized error messages

---

## 21. Error Handling

- Custom `AppException` with types: Database, Network, Validation, Auth, Authorization, NotFound, Conflict, Unknown
- `Result<T>` wrapper for safe error propagation
- Central error handling with listeners
- User-friendly error messages

---

## 22. Localization (i18n)

- **Full Arabic and English** support
- Complete string dictionaries covering all UI text
- **RTL / LTR** text direction handling
- Currency formatting (₪ ILS)
- Instant language toggle via `ChangeNotifier`
- Arabic is the default language

---

## 23. Database

**Engine:** SQLite v10 with WAL journaling, foreign keys, 20MB cache, normal synchronous mode, 256MB memory-mapped I/O.

| Table | Purpose |
|---|---|
| `suppliers` | Supplier records — name, phone, address, note |
| `supplier_attachments` | Supplier file attachments — PDF/image files with comments |
| `products` | Product catalog — name, barcode, price, cost price, quantity, min stock, supplier, supplier_id (FK), notes |
| `customers` | Customer records — name, phone, email, address, balance adjustment |
| `users` | System users — username, hashed password, role, full name |
| `invoices` | Sale invoices — invoice number, customer, totals, discount, profit, paid amount, payment method, notes |
| `sales` | Invoice line items — product, quantity, sale/cost price, discount, profit, note |
| `discounts` | Discount records per invoice |
| `inventory_adjustments` | Stock adjustment history — product, type, quantity, reason |
| `cancelled_sales` | Cancelled sale records with reversal tracking |
| `expenses` | Business expenses — category, amount, date, receipt, supplier, notes |
| `additional_income` | Non-sale income records (UI not yet implemented) |
| `budget` | Budget tracking (UI not yet implemented) |
| `store_settings` | Key-value store settings (store name, currency, tax rate) |
| `price_lists` | Named price lists with optional customer |
| `price_list_items` | Price list line items |
| `supplier_invoices` | Supplier invoice records — invoice number, date, total/paid amounts, file attachment |
| `supplier_payments` | Individual payment records against supplier invoices |
| `audit_logs` | Full audit trail |

### Migrations

- v1 → v2: Added `paid_amount` to invoices
- v2 → v3: Added `balance_adjustment` to customers
- v3 → v4: Added customer index on invoices
- v4 → v5: Added `price_lists` and `price_list_items` tables
- v5 → v6: Added `notes` to invoices
- v6 → v7: Added `suppliers` and `supplier_attachments` tables, added `supplier_id` FK to products
- v7 → v8: Added comprehensive performance indexes (20+ new indexes)
- v8 → v9: Added `note` column to sales table
- v9 → v10: Added `supplier_invoices` and `supplier_payments` tables with indexes

---

## 24. Installer

- **Inno Setup** based Windows installer
- App: "Electrical Store" v1.0.0, Windows x64
- Bundled DLLs: `flutter_windows.dll`, `pdfium.dll`, `printing_plugin.dll`, `sqlite3.dll`
- Desktop and Quick Launch shortcuts
- Database file cleanup on uninstall
