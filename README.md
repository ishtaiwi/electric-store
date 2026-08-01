# Electrical Store

Point-of-sale and inventory management system for electrical tools and supplies.

| | |
|---|---|
| **Package** | `electrical_store` |
| **Version** | `1.0.0+1` |
| **Platforms** | Windows desktop (primary) · Android / iOS companion app |
| **Architecture** | Offline-first SQLite on desktop · Supabase for cloud sync and mobile |

---

## Overview

Electrical Store is a Flutter application designed for day-to-day shop operations: sales, stock, customers, invoices, suppliers, expenses, reporting, and backups.

The system is split into three layers:

| Layer | Responsibility |
|-------|----------------|
| **Windows desktop** | Primary workstation. Runs offline against local SQLite (`d.db`). |
| **Supabase** | Cloud mirror (PostgreSQL + Storage) used for multi-PC sync and the mobile app. |
| **Mobile app** | Lightweight client on Supabase for products, customers, and trial invoices. |

**Recommended multi-device setup:** one desktop acts as the **uploader** (source of truth); a second desktop **downloads** from the cloud; mobile reads and writes shared cloud data while keeping trial sales isolated from desktop operations.

---

## Features

### Desktop

- **Point of sale** — barcode entry, cart, discounts, cash / card / partial / credit payment
- **Inventory** — products with cost and sell price, brands and categories, images, low-stock alerts, stock adjustments
- **Customers** — balances, ledger, cash and cheque payments
- **Invoices & sales history** — payment status, PDF print and export
- **Suppliers** — invoices, payments, file attachments
- **Expenses & price lists** — categorized expenses and printable price quotes
- **Reports** — sales, profit, stock, receivables, top products
- **Backup & restore** — full database backup and recovery
- **Settings** — store profile, language (Arabic / English, RTL), user management, cloud sync modes
- **Assistants** — local chatbot and fuzzy Arabic product search

Currency defaults to **ILS (₪)**.

### Mobile (`mobile/`)

- Authentication against the shared `users` table
- Product browsing and editing, including image upload to Storage
- Customers, account statements, and payments
- Trial invoices that do not affect desktop stock or balances

### Roles

| Role | Typical access |
|------|----------------|
| Admin | Full access, user management |
| Manager | Operational management |
| Cashier | Sales-focused access |

Passwords are stored with SHA-256 hashing and salt. Legacy plaintext passwords are migrated automatically on login.

---

## Cloud sync (multi-desktop)

Sync behaviour is configured in **Settings**. Both modes start **off** and persist until changed.

| Mode | Intended device | Behaviour |
|------|-----------------|-----------|
| **Upload** | Primary desktop | Pushes local changes to Supabase automatically (on write + periodic) |
| **Download** | Secondary desktop | Pulls cloud changes automatically (realtime + periodic); full pull on enable |
| **Off** | Any device | No automatic sync |

Manual actions remain available at any time:

- **Upload data to Supabase**
- **Download data from Supabase** (replaces local desktop tables with the cloud copy)

Do not enable Upload on more than one desktop. The secondary machine should use Download only.

### Synced tables

`users`, `suppliers`, `customers`, `product_brands`, `product_categories`, `products`, `invoices`, `sales`, `customer_payments`, `discounts`, `inventory_adjustments`, `cancelled_sales`, `expenses`, `additional_income`, `budget`, `store_settings`, `price_lists`, `price_list_items`, `supplier_attachments`, `supplier_invoices`, `supplier_payments`

### Mobile-only data

- `mobile_trial_invoices` / `mobile_trial_sales` — trial sales without stock or balance impact
- Performance views such as `mobile_products` and `mobile_customer_balances`

### Product images

- Uploaded from mobile into the `product-images` Storage bucket
- Public URL stored on `products.image_url`
- Sync never deletes Storage objects
- Desktop upload preserves an existing cloud `image_url` when the local row has no image

Device-local sync preferences (mode, last sync timestamp) are preserved across downloads.

---

## Getting started

### Prerequisites

- Flutter SDK (Dart 3+)
- Windows 10+ for the desktop app
- A [Supabase](https://supabase.com) project
- Python 3.10+ (optional, for one-time SQLite → Supabase migration)
- Android Studio / Xcode when building the mobile app

### Configure secrets

1. Copy `.env.example` to `.env` and set `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and (for migration scripts only) `SUPABASE_SERVICE_ROLE_KEY`.
2. Generate embedded secret files used by the apps:

```powershell
python supabase/generate_secrets.py
```

This creates gitignored `supabase_secrets.dart` files for desktop and mobile.

### Apply database schema

In the Supabase SQL Editor, run as needed:

| Script | Purpose |
|--------|---------|
| `supabase/schema.sql` | Core tables and RLS |
| `supabase/add_product_brand_category.sql` | Brand / category tables and view updates |
| `supabase/add_product_images.sql` | `image_url` column and Storage bucket |
| `supabase/mobile_trial_invoices.sql` | Mobile trial invoice tables |
| `supabase/mobile_performance.sql` | Mobile performance views and indexes |

### Optional initial data migration

```powershell
cd supabase
pip install -r requirements.txt
python migrate_from_sqlite.py --db ..\d.db
```

### Run desktop

```powershell
flutter pub get
flutter run -d windows
```

On the primary PC, enable **Upload** in Settings. On a secondary PC, enable **Download** (or run a manual download once).

### Run mobile

```powershell
python supabase/generate_secrets.py
cd mobile
flutter pub get
flutter run
```

### Windows release build

```powershell
flutter build windows --release
.\build_installer.ps1
```

The installer is defined in `installer.iss` (Inno Setup).

---

## Tech stack

| Area | Technology |
|------|------------|
| UI & app | Flutter, Dart 3+ |
| State & DI | flutter_bloc, GetIt, equatable |
| Local database | sqflite + FFI (Windows) |
| Cloud | supabase_flutter (Postgres, Realtime, Storage) |
| Documents | pdf, printing |
| Files | file_picker, archive |
| Security | crypto, salted password hashing |
| Packaging | Inno Setup |

---

## Project structure

```
electricalStore/
├── lib/                  # Windows desktop application
│   ├── main.dart
│   ├── core/
│   │   ├── config/       # Generated secrets (local)
│   │   ├── database/     # SQLite access
│   │   ├── di/           # Dependency injection
│   │   ├── services/     # Sync, localization, PDF, search, chatbot
│   │   └── supabase/     # Sync table list and client helpers
│   └── features/         # auth, products, sales, customers, ...
├── mobile/               # Companion mobile application
├── supabase/             # Schema, migrations, Python utilities
├── windows/              # Windows runner and build files
├── installer.iss         # Inno Setup script
├── build_installer.ps1
├── .env.example
└── README.md
```

Desktop flow: login → `DashboardPage` → feature tabs via `IndexedStack`.

---

## Security

- Keep `.env`, generated `supabase_secrets.dart`, and the service-role key out of version control.
- Treat the anon key as an internal shop credential; do not publish it publicly.
- Enable Upload on a single primary desktop only, so prune/upload cannot wipe cloud data from a secondary machine.
- Product image files remain in Storage even when desktop rows temporarily lack an `image_url`.

---

## License

Private project. All rights reserved.
