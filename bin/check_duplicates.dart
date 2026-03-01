import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  
  final dbPath = r'c:\Users\osama\Desktop\electricalStore\d.db';
  final db = await openDatabase(dbPath);
  
  final results = await db.rawQuery(
    "SELECT * FROM products WHERE id IN (237, 247, 257, 258)"
  );
  
  print('Checking duplicate "كشاف مغناطيس ليبر" products:');
  print('=' * 100);
  for (var row in results) {
    print('ID: ${row['id']}');
    for (var key in row.keys) {
      if (key != 'id') {
        print('  $key: ${row[key]}');
      }
    }
    print('-' * 50);
  }
  
  await db.close();
}
