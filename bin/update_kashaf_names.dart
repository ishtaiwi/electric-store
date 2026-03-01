import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  
  final dbPath = r'c:\Users\osama\Desktop\electricalStore\d.db';
  final db = await openDatabase(dbPath);
  
  // Map of id -> new formatted name
  // Format: كشاف [ماركة] [نوع] [قدرة] واط
  final updates = {
    // ليبر الالماني sona series
    29: 'كشاف ليبر الالماني sona 50 واط',
    30: 'كشاف ليبر الالماني sona 100 واط',
    31: 'كشاف ليبر الالماني sona 150 واط',
    32: 'كشاف ليبر الالماني sona 200 واط',
    
    // فيتايا
    556: 'كشاف فيتايا اسود 300 واط',
    400: 'كشاف فيتايا 100 واط',
    399: 'كشاف فيتايا 50 واط',
    395: 'كشاف فيتايا عين حركة 50 واط',
    
    // well max
    33: 'كشاف well max 100 واط',
    293: 'كشاف well max 200 واط',
    291: 'كشاف well max 50 واط',
    
    // جرس - already good format
    538: 'كشاف جرس 200 واط',
    
    // سبسان sepsan
    564: 'كشاف سبسان sepsan 300 واط',
    565: 'كشاف سبسان sepsan 400 واط',
    
    // طاقة شمسية lovirto
    442: 'كشاف طاقة شمسية lovirto 100 واط',
    443: 'كشاف طاقة شمسية lovirto 200 واط',
    444: 'كشاف طاقة شمسية lovirto 300 واط',
    445: 'كشاف طاقة شمسية lovirto 400 واط',
    
    // طاقة شمسية ليبر الالماني
    449: 'كشاف طاقة شمسية ليبر الالماني 100 واط',
    165: 'كشاف طاقة شمسية ليبر الالماني 200 واط',
    451: 'كشاف طاقة شمسية ليبر الالماني 300 واط',
    450: 'كشاف طاقة شمسية ليبر الالماني 400 واط',
    
    // لوتيكا
    290: 'كشاف لوتيكا 200 واط',
    491: 'كشاف لوتيكا 300 واط',
    492: 'كشاف لوتيكا 400 واط',
    
    // ليبر ثلاث طقات cct
    529: 'كشاف ليبر ثلاث طقات cct 50 واط',
    527: 'كشاف ليبر ثلاث طقات cct 80 واط',
    
    // ليد سكني ليبر اليسون
    380: 'كشاف ليد سكني ليبر اليسون alison',
    
    // ليد مطري ليبر
    526: 'كشاف ليد مطري ليبر',
    
    // مغناطيس cct
    480: 'كشاف مغناطيس cct 10 واط',
    481: 'كشاف مغناطيس cct 20 واط',
    
    // مغناطيس ليبر - differentiate by size (based on price)
    237: 'كشاف مغناطيس ليبر كبير', // price 50
    258: 'كشاف مغناطيس ليبر كبير', // price 50
    247: 'كشاف مغناطيس ليبر صغير', // price 40
    257: 'كشاف مغناطيس ليبر صغير', // price 40
  };
  
  print('Updating product names...');
  print('=' * 80);
  
  int successCount = 0;
  for (var entry in updates.entries) {
    final id = entry.key;
    final newName = entry.value;
    
    // Get old name first
    final oldResult = await db.rawQuery('SELECT name FROM products WHERE id = ?', [id]);
    if (oldResult.isEmpty) {
      print('ID $id: NOT FOUND');
      continue;
    }
    final oldName = oldResult.first['name'];
    
    // Update
    final result = await db.rawUpdate(
      'UPDATE products SET name = ? WHERE id = ?',
      [newName, id]
    );
    
    if (result > 0) {
      print('ID $id: "$oldName" -> "$newName"');
      successCount++;
    } else {
      print('ID $id: FAILED to update');
    }
  }
  
  print('=' * 80);
  print('Updated $successCount products successfully');
  
  await db.close();
}
