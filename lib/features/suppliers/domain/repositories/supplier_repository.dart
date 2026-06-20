import '../entities/supplier.dart';
import '../entities/supplier_attachment.dart';
import '../entities/supplier_invoice.dart';
import '../entities/supplier_payment.dart';

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

  // Supplier Invoice operations
  Future<List<SupplierInvoice>> getInvoicesBySupplier(int supplierId);
  Future<SupplierInvoice?> getInvoiceById(int invoiceId);
  Future<int> createInvoice(SupplierInvoice invoice);
  Future<int> updateInvoice(SupplierInvoice invoice);
  Future<int> deleteInvoice(int invoiceId);

  // Supplier Payment operations
  Future<List<SupplierPayment>> getPaymentsByInvoice(int invoiceId);
  Future<List<SupplierPayment>> getPaymentsBySupplier(int supplierId);
  Future<int> recordPayment(SupplierPayment payment);
  Future<int> deletePayment(int paymentId);

  // Financial insights
  Future<double> getSupplierOutstandingBalance(int supplierId);
  Future<double> getGlobalOutstandingBalance();
  Future<Map<String, dynamic>> getSupplierFinancialSummary(int supplierId);
  Future<List<Map<String, dynamic>>> getAllSuppliersOutstanding();
}
