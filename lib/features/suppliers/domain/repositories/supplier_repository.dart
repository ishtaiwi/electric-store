import '../entities/supplier.dart';
import '../entities/supplier_attachment.dart';

abstract class SupplierRepository {
  // Supplier CRUD
  Future<List<Supplier>> getAllSuppliers();
  Future<Supplier?> getSupplierById(int id);
  Future<List<Supplier>> searchSuppliers(String query);
  Future<int> createSupplier(Supplier supplier);
  Future<int> updateSupplier(Supplier supplier);
  Future<int> deleteSupplier(int id);

  // Attachment operations
  Future<List<SupplierAttachment>> getAttachmentsBySupplier(int supplierId);
  Future<int> addAttachment(SupplierAttachment attachment);
  Future<int> updateAttachmentComment(int attachmentId, String comment);
  Future<int> deleteAttachment(int attachmentId);
}
