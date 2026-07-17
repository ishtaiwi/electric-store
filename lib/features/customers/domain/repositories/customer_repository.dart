import '../entities/customer.dart';
import '../entities/customer_ledger.dart';
import '../entities/customer_ledger_filters.dart';
import '../entities/customer_payment.dart';

abstract class CustomerRepository {
  Future<List<Customer>> getAllCustomers();
  Future<List<Customer>> getCustomersPaginated({int limit = 50, int offset = 0});
  Future<int> getCustomersCount();
  Future<List<Customer>> searchCustomersPaginated(
    String query, {
    int limit = 50,
    int offset = 0,
  });
  Future<Customer?> getCustomerById(int id);
  Future<List<Customer>> searchCustomers(String query);
  Future<List<Customer>> getCustomersWithDebt();
  Future<int> createCustomer(Customer customer);
  Future<int> updateCustomer(Customer customer);
  Future<int> deleteCustomer(int id);
  Future<double> getCustomerBalance(int customerId);
  Future<List<Map<String, dynamic>>> getCustomerTransactions(int customerId);

  // Payment management
  Future<int> recordPayment(CustomerPayment payment);
  Future<int> updatePayment(CustomerPayment payment);
  Future<List<CustomerPayment>> getPaymentsByCustomer(int customerId);
  Future<List<CustomerPayment>> getPaymentsByInvoice(int invoiceId);
  Future<int> deletePayment(int paymentId);
  Future<int> recordAccountDiscount({
    required int customerId,
    required double amount,
    String? notes,
    DateTime? discountDate,
  });

  /// Returns an account invoice id used to anchor ledger payments/discounts.
  /// Creates a zero-amount account invoice when the customer has none yet.
  Future<int> getOrCreateAccountAnchorInvoice(
    int customerId, {
    String? customerName,
  });
  Future<Map<String, dynamic>> getCustomerFinancialSummary(int customerId);
  Future<CustomerLedger> getCustomerLedger(int customerId, {CustomerLedgerFilters? filters});
}
