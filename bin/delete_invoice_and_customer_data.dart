import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

Future<void> main() async {
  // Initialize FFI for desktop
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final dbPath = p.join(Directory.current.path, 'd.db');
  final dbFile = File(dbPath);

  if (!dbFile.existsSync()) {
    print('Database file not found at: $dbPath');
    exit(1);
  }

  print('Opening database: $dbPath');
  final db = await openDatabase(dbPath);

  // Show counts BEFORE deletion
  final invoicesBefore = (await db.rawQuery('SELECT COUNT(*) as c FROM invoices')).first['c'];
  final salesBefore = (await db.rawQuery('SELECT COUNT(*) as c FROM sales')).first['c'];
  final cancelledBefore = (await db.rawQuery('SELECT COUNT(*) as c FROM cancelled_sales')).first['c'];
  final customersBefore = (await db.rawQuery('SELECT COUNT(*) as c FROM customers')).first['c'];

  print('\n--- BEFORE deletion ---');
  print('Invoices:        $invoicesBefore');
  print('Sales:           $salesBefore');
  print('Cancelled Sales: $cancelledBefore');
  print('Customers:       $customersBefore');

  // Delete all invoice and customer data
  print('\nDeleting all invoice and customer data...');

  await db.transaction((txn) async {
    await txn.delete('cancelled_sales');
    await txn.delete('sales');
    await txn.delete('invoices');
    await txn.delete('customers');
    // Reset auto-increment counters
    await txn.rawDelete(
      "DELETE FROM sqlite_sequence WHERE name IN ('invoices', 'sales', 'cancelled_sales', 'customers')",
    );
  });

  // Show counts AFTER deletion
  final invoicesAfter = (await db.rawQuery('SELECT COUNT(*) as c FROM invoices')).first['c'];
  final salesAfter = (await db.rawQuery('SELECT COUNT(*) as c FROM sales')).first['c'];
  final cancelledAfter = (await db.rawQuery('SELECT COUNT(*) as c FROM cancelled_sales')).first['c'];
  final customersAfter = (await db.rawQuery('SELECT COUNT(*) as c FROM customers')).first['c'];

  print('\n--- AFTER deletion ---');
  print('Invoices:        $invoicesAfter');
  print('Sales:           $salesAfter');
  print('Cancelled Sales: $cancelledAfter');
  print('Customers:       $customersAfter');

  print('\nAll invoice and customer data deleted successfully!');

  await db.close();
}
