import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/services/cache_service.dart';
import '../../../../core/services/audit_logger_service.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/entities/supplier_attachment.dart';
import '../../domain/repositories/supplier_repository.dart';

class SupplierRepositoryImpl implements SupplierRepository {
  final DatabaseHelper _databaseHelper;
  final CacheService _cache = CacheService();
  final AuditLoggerService _auditLogger = AuditLoggerService();

  SupplierRepositoryImpl(this._databaseHelper);

  void _invalidateCache() {
    _cache.invalidate(CacheKeys.suppliers);
    _cache.invalidatePattern('supplier_');
  }

  // ─── Helper: Get attachments directory ───
  Future<Directory> _getAttachmentsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'electrical_store', 'supplier_attachments'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  // ─── Supplier CRUD ───

  @override
  Future<List<Supplier>> getAllSuppliers() async {
    final cached = _cache.get<List<Supplier>>(CacheKeys.suppliers);
    if (cached != null) return cached;

    final db = await _databaseHelper.database;
    final result = await db.query('suppliers', orderBy: 'name ASC');
    final suppliers = result.map((map) => Supplier.fromMap(map)).toList();

    _cache.set(CacheKeys.suppliers, suppliers, duration: const Duration(minutes: 5));
    return suppliers;
  }

  @override
  Future<Supplier?> getSupplierById(int id) async {
    final cacheKey = CacheKeys.supplierById(id);
    final cached = _cache.get<Supplier>(cacheKey);
    if (cached != null) return cached;

    final db = await _databaseHelper.database;
    final result = await db.query(
      'suppliers',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    final supplier = Supplier.fromMap(result.first);

    _cache.set(cacheKey, supplier, duration: CacheService.shortDuration);
    return supplier;
  }

  @override
  Future<List<Supplier>> searchSuppliers(String query) async {
    final db = await _databaseHelper.database;
    final result = await db.query(
      'suppliers',
      where: 'name LIKE ? OR phone LIKE ? OR address LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'name ASC',
    );
    return result.map((map) => Supplier.fromMap(map)).toList();
  }

  @override
  Future<int> createSupplier(Supplier supplier) async {
    final db = await _databaseHelper.database;
    final id = await db.insert('suppliers', supplier.toMap());

    await _auditLogger.log(
      action: AuditAction.supplierCreated,
      entityType: 'supplier',
      entityId: id,
      details: 'Created supplier: ${supplier.name}',
    );

    _invalidateCache();
    return id;
  }

  @override
  Future<int> updateSupplier(Supplier supplier) async {
    final db = await _databaseHelper.database;

    final oldResult = await db.query('suppliers', where: 'id = ?', whereArgs: [supplier.id]);
    final oldSupplier = oldResult.isNotEmpty ? Supplier.fromMap(oldResult.first) : null;

    final result = await db.update(
      'suppliers',
      supplier.toMap(),
      where: 'id = ?',
      whereArgs: [supplier.id],
    );

    if (result > 0 && oldSupplier != null) {
      await _auditLogger.log(
        action: AuditAction.supplierUpdated,
        entityType: 'supplier',
        entityId: supplier.id,
        details: 'Updated supplier: ${oldSupplier.name} -> ${supplier.name}',
      );
    }

    _invalidateCache();
    return result;
  }

  @override
  Future<int> deleteSupplier(int id) async {
    final db = await _databaseHelper.database;

    // Get supplier for audit
    final result = await db.query('suppliers', where: 'id = ?', whereArgs: [id]);
    final supplier = result.isNotEmpty ? Supplier.fromMap(result.first) : null;

    // Delete all attachment files first
    final attachments = await getAttachmentsBySupplier(id);
    for (final att in attachments) {
      final file = File(att.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    // Delete attachment records
    await db.delete('supplier_attachments', where: 'supplier_id = ?', whereArgs: [id]);

    // Unlink products that reference this supplier
    await db.rawUpdate(
      'UPDATE products SET supplier_id = NULL WHERE supplier_id = ?',
      [id],
    );

    // Delete the supplier
    final deleteResult = await db.delete('suppliers', where: 'id = ?', whereArgs: [id]);

    if (deleteResult > 0 && supplier != null) {
      await _auditLogger.log(
        action: AuditAction.supplierDeleted,
        entityType: 'supplier',
        entityId: id,
        details: 'Deleted supplier: ${supplier.name}',
      );
    }

    _invalidateCache();
    return deleteResult;
  }

  // ─── Attachment Operations ───

  @override
  Future<List<SupplierAttachment>> getAttachmentsBySupplier(int supplierId) async {
    final db = await _databaseHelper.database;
    final result = await db.query(
      'supplier_attachments',
      where: 'supplier_id = ?',
      whereArgs: [supplierId],
      orderBy: 'upload_date DESC',
    );
    return result.map((map) => SupplierAttachment.fromMap(map)).toList();
  }

  @override
  Future<int> addAttachment(SupplierAttachment attachment) async {
    final db = await _databaseHelper.database;

    // Copy file to app-managed directory
    final sourceFile = File(attachment.filePath);
    if (!await sourceFile.exists()) {
      throw Exception('Source file does not exist: ${attachment.filePath}');
    }

    final attachmentsDir = await _getAttachmentsDir();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final destFileName = '${attachment.supplierId}_${timestamp}_${attachment.fileName}';
    final destPath = p.join(attachmentsDir.path, destFileName);

    await sourceFile.copy(destPath);

    // Save record with the copied file path
    final savedAttachment = attachment.copyWith(filePath: destPath);
    final id = await db.insert('supplier_attachments', savedAttachment.toMap());

    await _auditLogger.log(
      action: AuditAction.create,
      entityType: 'supplier_attachment',
      entityId: id,
      details: 'Added attachment "${attachment.fileName}" to supplier ID ${attachment.supplierId}',
    );

    return id;
  }

  @override
  Future<int> updateAttachmentComment(int attachmentId, String comment) async {
    final db = await _databaseHelper.database;
    return await db.update(
      'supplier_attachments',
      {'comment': comment},
      where: 'id = ?',
      whereArgs: [attachmentId],
    );
  }

  @override
  Future<int> deleteAttachment(int attachmentId) async {
    final db = await _databaseHelper.database;

    // Get attachment to delete associated file
    final result = await db.query(
      'supplier_attachments',
      where: 'id = ?',
      whereArgs: [attachmentId],
    );

    if (result.isNotEmpty) {
      final attachment = SupplierAttachment.fromMap(result.first);
      final file = File(attachment.filePath);
      if (await file.exists()) {
        await file.delete();
      }

      await _auditLogger.log(
        action: AuditAction.delete,
        entityType: 'supplier_attachment',
        entityId: attachmentId,
        details: 'Deleted attachment "${attachment.fileName}" from supplier ID ${attachment.supplierId}',
      );
    }

    return await db.delete(
      'supplier_attachments',
      where: 'id = ?',
      whereArgs: [attachmentId],
    );
  }
}
