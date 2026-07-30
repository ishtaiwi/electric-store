/// Keys used in store_settings for Supabase hybrid sync.
class SupabaseConfigKeys {
  static const url = 'supabase_url';
  static const anonKey = 'supabase_anon_key';
  static const syncEnabled = 'supabase_sync_enabled';
  static const lastSyncAt = 'supabase_last_sync_at';
  static const autoSync = 'supabase_auto_sync';
}

/// Tables synced between local SQLite and Supabase (FK-safe order).
const List<String> supabaseSyncTables = [
  'users',
  'suppliers',
  'customers',
  'products',
  'invoices',
  'sales',
  'customer_payments',
  'discounts',
  'inventory_adjustments',
  'cancelled_sales',
  'expenses',
  'additional_income',
  'budget',
  'store_settings',
  'price_lists',
  'price_list_items',
  'supplier_attachments',
  'supplier_invoices',
  'supplier_payments',
  'audit_logs',
];

/// Settings keys that must stay on the device only (not overwritten on pull).
const Set<String> localOnlySettingKeys = {
  SupabaseConfigKeys.url,
  SupabaseConfigKeys.anonKey,
  SupabaseConfigKeys.syncEnabled,
  SupabaseConfigKeys.lastSyncAt,
  SupabaseConfigKeys.autoSync,
};
