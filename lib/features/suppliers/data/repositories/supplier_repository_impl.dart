import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/services/cache_service.dart';
import '../../../../core/services/audit_logger_service.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/entities/supplier_attachment.dart';
import '../../domain/entities/supplier_invoice.dart';
import '../../domain/entities/supplier_payment.dart';
import '../../domain/repositories/supplier_repository.dart';

class SupplierRepositoryImpl implements SupplierRepository {
  final DatabaseHelper _databaseHelper;
  final CacheService _cache = CacheService();
  final AuditLoggerService _auditLogger = AuditLoggerService();

  SupplierRepositoryImpl(this._databaseHelper);

  void _invalidateCache() {
    _cache.invalidate(CacheKeys.suppliers);
    _cache.invalidatePattern('supplier_');
    _cache.invalidate(CacheKeys.globalSupplierOutstanding);
  }

  void _invalidateInvoiceCache(int supplierId) {
    _cache.invalidate(CacheKeys.supplierInvoices(supplierId));
    _cache.invalidate(CacheKeys.supplierFinancialSummary(supplierId));
    _cache.invalidate(CacheKeys.globalSupplierOutstanding);
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

    // Delete supplier invoice files and payment records
    final invoices = await getInvoicesBySupplier(id);
    for (final inv in invoices) {
      // Delete payment records for this invoice
      await db.delete('supplier_payments', where: 'supplier_invoice_id = ?', whereArgs: [inv.id]);
      // Delete invoice file if exists
      if (inv.filePath != null) {
        final invFile = File(inv.filePath!);
        if (await invFile.exists()) {
          await invFile.delete();
        }
      }
    }
    // Delete invoice records
    await db.delete('supplier_invoices', where: 'supplier_id = ?', whereArgs: [id]);

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

  // ─── Helper: Get invoice files directory ───
  Future<Directory> _getInvoiceFilesDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'electrical_store', 'supplier_invoice_files'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
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

  // ─── Supplier Invoice Operations ───

  @override
  Future<List<SupplierInvoice>> getInvoicesBySupplier(int supplierId) async {
    final cached = _cache.get<List<SupplierInvoice>>(CacheKeys.supplierInvoices(supplierId));
    if (cached != null) return cached;

    final db = await _databaseHelper.database;
    final result = await db.query(
      'supplier_invoices',
      where: 'supplier_id = ?',
      whereArgs: [supplierId],
      orderBy: 'invoice_date DESC',
    );
    final invoices = result.map((map) => SupplierInvoice.fromMap(map)).toList();
    _cache.set(CacheKeys.supplierInvoices(supplierId), invoices, duration: CacheService.shortDuration);
    return invoices;
  }

  @override
  Future<SupplierInvoice?> getInvoiceById(int invoiceId) async {
    final db = await _databaseHelper.database;
    final result = await db.query(
      'supplier_invoices',
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
    if (result.isEmpty) return null;
    return SupplierInvoice.fromMap(result.first);
  }

  @override
  Future<int> createInvoice(SupplierInvoice invoice) async {
    final db = await _databaseHelper.database;

    String? savedFilePath = invoice.filePath;
    // Copy file to app-managed directory if present
    if (invoice.filePath != null && invoice.filePath!.isNotEmpty) {
      final sourceFile = File(invoice.filePath!);
      if (await sourceFile.exists()) {
        final invoiceFilesDir = await _getInvoiceFilesDir();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final destFileName = '${invoice.supplierId}_${timestamp}_${invoice.fileName ?? 'invoice'}';
        final destPath = p.join(invoiceFilesDir.path, destFileName);
        await sourceFile.copy(destPath);
        savedFilePath = destPath;
      }
    }

    final savedInvoice = invoice.copyWith(filePath: savedFilePath);
    final id = await db.insert('supplier_invoices', savedInvoice.toMap());

    await _auditLogger.log(
      action: AuditAction.supplierInvoiceCreated,
      entityType: 'supplier_invoice',
      entityId: id,
      details: 'Created supplier invoice #${invoice.invoiceNumber} for supplier ID ${invoice.supplierId}, amount: ${invoice.totalAmount}',
    );

    _invalidateInvoiceCache(invoice.supplierId);
    return id;
  }

  @override
  Future<int> updateInvoice(SupplierInvoice invoice) async {
    final db = await _databaseHelper.database;
    final result = await db.update(
      'supplier_invoices',
      invoice.toMap(),
      where: 'id = ?',
      whereArgs: [invoice.id],
    );

    if (result > 0) {
      await _auditLogger.log(
        action: AuditAction.supplierInvoiceUpdated,
        entityType: 'supplier_invoice',
        entityId: invoice.id,
        details: 'Updated supplier invoice #${invoice.invoiceNumber}',
      );
    }

    _invalidateInvoiceCache(invoice.supplierId);
    return result;
  }

  @override
  Future<int> deleteInvoice(int invoiceId) async {
    final db = await _databaseHelper.database;

    // Get invoice for audit and cache invalidation
    final result = await db.query('supplier_invoices', where: 'id = ?', whereArgs: [invoiceId]);
    final invoice = result.isNotEmpty ? SupplierInvoice.fromMap(result.first) : null;

    // Delete associated payment records
    await db.delete('supplier_payments', where: 'supplier_invoice_id = ?', whereArgs: [invoiceId]);

    // Delete invoice file if exists
    if (invoice?.filePath != null) {
      final file = File(invoice!.filePath!);
      if (await file.exists()) {
        await file.delete();
      }
    }

    final deleteResult = await db.delete('supplier_invoices', where: 'id = ?', whereArgs: [invoiceId]);

    if (deleteResult > 0 && invoice != null) {
      await _auditLogger.log(
        action: AuditAction.supplierInvoiceDeleted,
        entityType: 'supplier_invoice',
        entityId: invoiceId,
        details: 'Deleted supplier invoice #${invoice.invoiceNumber} from supplier ID ${invoice.supplierId}',
      );
      _invalidateInvoiceCache(invoice.supplierId);
    }

    return deleteResult;
  }

  // ─── Supplier Payment Operations ───

  @override
  Future<List<SupplierPayment>> getPaymentsByInvoice(int invoiceId) async {
    final db = await _databaseHelper.database;
    final result = await db.query(
      'supplier_payments',
      where: 'supplier_invoice_id = ?',
      whereArgs: [invoiceId],
      orderBy: 'payment_date DESC',
    );
    return result.map((map) => SupplierPayment.fromMap(map)).toList();
  }

  @override
  Future<List<SupplierPayment>> getPaymentsBySupplier(int supplierId) async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT sp.* FROM supplier_payments sp
      INNER JOIN supplier_invoices si ON sp.supplier_invoice_id = si.id
      WHERE si.supplier_id = ?
      ORDER BY sp.payment_date DESC
    ''', [supplierId]);
    return result.map((map) => SupplierPayment.fromMap(map)).toList();
  }

  @override
  Future<int> recordPayment(SupplierPayment payment) async {
    final db = await _databaseHelper.database;

    // Get current invoice
    final invoiceResult = await db.query(
      'supplier_invoices',
      where: 'id = ?',
      whereArgs: [payment.supplierInvoiceId],
    );
    if (invoiceResult.isEmpty) {
      throw Exception('Invoice not found');
    }

    final invoice = SupplierInvoice.fromMap(invoiceResult.first);
    final newPaidAmount = invoice.paidAmount + payment.amount;

    // Insert payment record
    final paymentId = await db.insert('supplier_payments', payment.toMap());

    // Update invoice paid_amount
    await db.update(
      'supplier_invoices',
      {'paid_amount': newPaidAmount},
      where: 'id = ?',
      whereArgs: [payment.supplierInvoiceId],
    );

    await _auditLogger.log(
      action: AuditAction.supplierPaymentRecorded,
      entityType: 'supplier_payment',
      entityId: paymentId,
      details: 'Recorded payment of ${payment.amount} for invoice #${invoice.invoiceNumber} (supplier ID ${invoice.supplierId})',
    );

    _invalidateInvoiceCache(invoice.supplierId);
    return paymentId;
  }

  @override
  Future<int> deletePayment(int paymentId) async {
    final db = await _databaseHelper.database;

    // Get payment record
    final paymentResult = await db.query('supplier_payments', where: 'id = ?', whereArgs: [paymentId]);
    if (paymentResult.isEmpty) return 0;

    final payment = SupplierPayment.fromMap(paymentResult.first);

    // Get invoice to update paid_amount
    final invoiceResult = await db.query(
      'supplier_invoices',
      where: 'id = ?',
      whereArgs: [payment.supplierInvoiceId],
    );

    if (invoiceResult.isNotEmpty) {
      final invoice = SupplierInvoice.fromMap(invoiceResult.first);
      final newPaidAmount = (invoice.paidAmount - payment.amount).clamp(0.0, invoice.totalAmount);

      await db.update(
        'supplier_invoices',
        {'paid_amount': newPaidAmount},
        where: 'id = ?',
        whereArgs: [payment.supplierInvoiceId],
      );

      _invalidateInvoiceCache(invoice.supplierId);
    }

    return await db.delete('supplier_payments', where: 'id = ?', whereArgs: [paymentId]);
  }

  // ─── Financial Insights ───

  @override
  Future<double> getSupplierOutstandingBalance(int supplierId) async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(total_amount - paid_amount), 0) as outstanding FROM supplier_invoices WHERE supplier_id = ?',
      [supplierId],
    );
    return (result.first['outstanding'] as num?)?.toDouble() ?? 0;
  }

  @override
  Future<double> getGlobalOutstandingBalance() async {
    final cached = _cache.get<double>(CacheKeys.globalSupplierOutstanding);
    if (cached != null) return cached;

    final db = await _databaseHelper.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(total_amount - paid_amount), 0) as outstanding FROM supplier_invoices',
    );
    final value = (result.first['outstanding'] as num?)?.toDouble() ?? 0;
    _cache.set(CacheKeys.globalSupplierOutstanding, value, duration: CacheService.shortDuration);
    return value;
  }

  @override
  Future<Map<String, dynamic>> getSupplierFinancialSummary(int supplierId) async {
    final cached = _cache.get<Map<String, dynamic>>(CacheKeys.supplierFinancialSummary(supplierId));
    if (cached != null) return cached;

    final db = await _databaseHelper.database;

    // Get totals from invoices
    final invoiceTotals = await db.rawQuery('''
      SELECT
        COUNT(*) as total_invoices,
        COALESCE(SUM(total_amount), 0) as total_amount,
        COALESCE(SUM(paid_amount), 0) as total_paid,
        COALESCE(SUM(total_amount - paid_amount), 0) as total_outstanding
      FROM supplier_invoices
      WHERE supplier_id = ?
    ''', [supplierId]);

    // Get last payment
    final lastPayment = await db.rawQuery('''
      SELECT sp.amount, sp.payment_date
      FROM supplier_payments sp
      INNER JOIN supplier_invoices si ON sp.supplier_invoice_id = si.id
      WHERE si.supplier_id = ?
      ORDER BY sp.payment_date DESC
      LIMIT 1
    ''', [supplierId]);

    // Count by status
    final overpaidCount = await db.rawQuery(
      'SELECT COUNT(*) as c FROM supplier_invoices WHERE supplier_id = ? AND paid_amount > total_amount',
      [supplierId],
    );
    final paidCount = await db.rawQuery(
      'SELECT COUNT(*) as c FROM supplier_invoices WHERE supplier_id = ? AND paid_amount = total_amount AND total_amount > 0',
      [supplierId],
    );
    final partialCount = await db.rawQuery(
      'SELECT COUNT(*) as c FROM supplier_invoices WHERE supplier_id = ? AND paid_amount > 0 AND paid_amount < total_amount',
      [supplierId],
    );
    final unpaidCount = await db.rawQuery(
      'SELECT COUNT(*) as c FROM supplier_invoices WHERE supplier_id = ? AND paid_amount = 0 AND total_amount > 0',
      [supplierId],
    );

    final row = invoiceTotals.first;
    final summary = {
      'total_invoices': row['total_invoices'] ?? 0,
      'total_amount': (row['total_amount'] as num?)?.toDouble() ?? 0,
      'total_paid': (row['total_paid'] as num?)?.toDouble() ?? 0,
      'total_outstanding': (row['total_outstanding'] as num?)?.toDouble() ?? 0,
      'overpaid_count': (overpaidCount.first['c'] as num?)?.toInt() ?? 0,
      'paid_count': (paidCount.first['c'] as num?)?.toInt() ?? 0,
      'partial_count': (partialCount.first['c'] as num?)?.toInt() ?? 0,
      'unpaid_count': (unpaidCount.first['c'] as num?)?.toInt() ?? 0,
      'last_payment_amount': lastPayment.isNotEmpty ? (lastPayment.first['amount'] as num?)?.toDouble() : null,
      'last_payment_date': lastPayment.isNotEmpty ? lastPayment.first['payment_date'] : null,
    };

    _cache.set(CacheKeys.supplierFinancialSummary(supplierId), summary, duration: CacheService.shortDuration);
    return summary;
  }

  @override
  Future<List<Map<String, dynamic>>> getAllSuppliersOutstanding() async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT
        s.id,
        s.name,
        s.phone,
        COALESCE(SUM(si.total_amount), 0) as total_invoiced,
        COALESCE(SUM(si.paid_amount), 0) as total_paid,
        COALESCE(SUM(si.total_amount - si.paid_amount), 0) as outstanding
      FROM suppliers s
      LEFT JOIN supplier_invoices si ON s.id = si.supplier_id
      GROUP BY s.id, s.name, s.phone
      HAVING outstanding != 0
      ORDER BY outstanding DESC
    ''');
    return result;
  }
}
