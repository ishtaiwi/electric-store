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
  
  // Full invoice update (add/remove/edit items with inventory tracking)
  Future<Invoice?> updateInvoice({
    required int invoiceId,
    required List<SaleItem> updatedItems,
    double discountAmount = 0,
    String? paymentMethod,
    String? customerName,
    int? customerId,
    double? paidAmount,
  });
  
  // Payment update
  Future<int> updateInvoicePaidAmount(int invoiceId, double paidAmount);
  
  // Notes update
  Future<int> updateInvoiceNotes(int invoiceId, String? notes);

  /// Update note on a single sale line item (`sales.note`).
  Future<int> updateSaleItemNote(int saleId, String? note);

  Future<Invoice?> updateInvoiceDiscount(int invoiceId, double discountAmount);
  
  // Pagination support
  Future<List<Invoice>> getInvoicesPaginated({int limit = 50, int offset = 0});
  Future<int> getInvoicesCount();
}
