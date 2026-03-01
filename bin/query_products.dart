import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  
  final dbPath = r'c:\Users\osama\Desktop\electricalStore\d.db';
  final db = await openDatabase(dbPath);
  
  final results = await db.rawQuery(
    "SELECT id, name FROM products WHERE name LIKE '%كشاف%' ORDER BY name"
  );
  
  print('Products with "كشاف" in name:');
  print('=' * 80);
  for (var row in results) {
    print('ID: ${row['id']}, Name: ${row['name']}');
  }
  print('=' * 80);
  print('Total: ${results.length} products');
  
  await db.close();
}
