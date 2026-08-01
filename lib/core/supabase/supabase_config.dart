/// How this desktop participates in cloud sync.
enum DesktopSyncMode {
  /// No automatic sync.
  off,

  /// Main PC: push local → Supabase on every change.
  upload,

  /// Secondary PC: pull Supabase → local when cloud data changes.
  download,
}

extension DesktopSyncModeX on DesktopSyncMode {
  String get storageValue => name;

  static DesktopSyncMode parse(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'upload':
        return DesktopSyncMode.upload;
      case 'download':
        return DesktopSyncMode.download;
      case 'off':
        return DesktopSyncMode.off;
      default:
        return DesktopSyncMode.off;
    }
  }
}

/// Keys used in store_settings for Supabase hybrid sync.
class SupabaseConfigKeys {
  static const url = 'supabase_url';
  static const anonKey = 'supabase_anon_key';
  static const syncEnabled = 'supabase_sync_enabled';
  static const lastSyncAt = 'supabase_last_sync_at';
  static const autoSync = 'supabase_auto_sync';
  static const syncMode = 'supabase_sync_mode';
}

/// Tables synced between local SQLite and Supabase (FK-safe order).
const List<String> supabaseSyncTables = [
  'users',
  'suppliers',
  'customers',
  'product_brands',
  'product_categories',
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
];

/// Tables that use UNIQUE(name) — soft pull clears them first to avoid conflicts.
const Set<String> softPullReplaceTables = {
  'product_brands',
  'product_categories',
};

/// Settings keys that must stay on the device only (not overwritten on pull).
const Set<String> localOnlySettingKeys = {
  SupabaseConfigKeys.url,
  SupabaseConfigKeys.anonKey,
  SupabaseConfigKeys.syncEnabled,
  SupabaseConfigKeys.lastSyncAt,
  SupabaseConfigKeys.autoSync,
  SupabaseConfigKeys.syncMode,
};
