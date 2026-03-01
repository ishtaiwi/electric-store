import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  
  final dbPath = r'c:\Users\osama\Desktop\electricalStore\d.db';
  final db = await openDatabase(dbPath);
  
  // Check if notes column exists
  final tableInfo = await db.rawQuery('PRAGMA table_info(invoices)');
  final hasNotesColumn = tableInfo.any((col) => col['name'] == 'notes');
  
  if (hasNotesColumn) {
    print('Notes column already exists in invoices table.');
  } else {
    print('Adding notes column to invoices table...');
    await db.execute('ALTER TABLE invoices ADD COLUMN notes TEXT');
    print('Successfully added notes column!');
  }
  
  await db.close();
}
