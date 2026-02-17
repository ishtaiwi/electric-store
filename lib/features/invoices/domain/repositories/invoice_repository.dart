import '../entities/invoice.dart';
import '../entities/sale_item.dart';

abstract class InvoiceRepository {
  Future<List<Invoice>> getAllInvoices();
  Future<Invoice?> getInvoiceById(int id);
  Future<Invoice?> getInvoiceByNumber(String invoiceNumber);
  Future<List<Invoice>> getInvoicesByCustomer(int customerId);
  Future<List<Invoice>> getInvoicesByDateRange(DateTime start, DateTime end);
  Future<List<Invoice>> getInvoicesToday();
  Future<List<SaleItem>> getInvoiceItems(int invoiceId);
  Future<int> deleteInvoice(int id);
  
  // Payment update
  Future<int> updateInvoicePaidAmount(int invoiceId, double paidAmount);
  
  // Pagination support
  Future<List<Invoice>> getInvoicesPaginated({int limit = 50, int offset = 0});
  Future<int> getInvoicesCount();
}
