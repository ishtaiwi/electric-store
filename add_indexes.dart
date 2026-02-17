import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

void main() async {
  // Initialize sqflite for desktop
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final dbPath = 'c:\\Users\\osama\\Desktop\\electricalStore\\d.db';
  
  if (!await File(dbPath).exists()) {
    print('Database not found at: $dbPath');
    return;
  }

  print('Opening database: $dbPath');
  final db = await openDatabase(dbPath);

  try {
    print('Creating indexes for performance optimization...');
    
    // Create indexes on products table for faster searches
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_name ON products(name)');
    print('Created index: idx_products_name');
    
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode)');
    print('Created index: idx_products_barcode');
    
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_quantity ON products(quantity)');
    print('Created index: idx_products_quantity');
    
    // Create composite index for common searches
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_search ON products(name, barcode, note)');
    print('Created index: idx_products_search');
    
    // Create indexes on sales table
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_product_id ON sales(product_id)');
    print('Created index: idx_sales_product_id');
    
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_date ON sales(sale_date)');
    print('Created index: idx_sales_date');
    
    // Create indexes on invoices table
    await db.execute('CREATE INDEX IF NOT EXISTS idx_invoices_date ON invoices(created_date)');
    print('Created index: idx_invoices_date');
    
    await db.execute('CREATE INDEX IF NOT EXISTS idx_invoices_customer ON invoices(customer_id)');
    print('Created index: idx_invoices_customer');
    
    // Analyze the database for query optimizer
    await db.execute('ANALYZE');
    print('Database analyzed for optimal query planning');
    
    // Vacuum to optimize storage
    await db.execute('VACUUM');
    print('Database vacuumed for optimal storage');

    print('\nAll indexes created successfully!');
    print('Database performance should now be significantly improved.');
  } catch (e) {
    print('Error: $e');
  } finally {
    await db.close();
  }
}
