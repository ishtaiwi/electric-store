import '../entities/customer.dart';
import '../entities/customer_payment.dart';

abstract class CustomerRepository {
  Future<List<Customer>> getAllCustomers();
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
  Future<List<CustomerPayment>> getPaymentsByCustomer(int customerId);
  Future<List<CustomerPayment>> getPaymentsByInvoice(int invoiceId);
  Future<int> deletePayment(int paymentId);
  Future<Map<String, dynamic>> getCustomerFinancialSummary(int customerId);
}
