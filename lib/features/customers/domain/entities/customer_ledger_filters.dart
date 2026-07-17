import 'package:equatable/equatable.dart';
import 'customer_ledger_entry.dart';

class CustomerLedgerFilters extends Equatable {
  final DateTime? fromDate;
  final DateTime? toDate;
  final LedgerDocumentType? documentType;
  final String? invoiceNumber;
  final String? receiptNumber;

  const CustomerLedgerFilters({
    this.fromDate,
    this.toDate,
    this.documentType,
    this.invoiceNumber,
    this.receiptNumber,
  });

  CustomerLedgerFilters copyWith({
    DateTime? fromDate,
    DateTime? toDate,
    LedgerDocumentType? documentType,
    String? invoiceNumber,
    String? receiptNumber,
    bool clearFromDate = false,
    bool clearToDate = false,
    bool clearDocumentType = false,
    bool clearInvoiceNumber = false,
    bool clearReceiptNumber = false,
  }) {
    return CustomerLedgerFilters(
      fromDate: clearFromDate ? null : (fromDate ?? this.fromDate),
      toDate: clearToDate ? null : (toDate ?? this.toDate),
      documentType: clearDocumentType ? null : (documentType ?? this.documentType),
      invoiceNumber: clearInvoiceNumber ? null : (invoiceNumber ?? this.invoiceNumber),
      receiptNumber: clearReceiptNumber ? null : (receiptNumber ?? this.receiptNumber),
    );
  }

  bool get hasActiveFilters =>
      fromDate != null ||
      toDate != null ||
      documentType != null ||
      (invoiceNumber != null && invoiceNumber!.isNotEmpty) ||
      (receiptNumber != null && receiptNumber!.isNotEmpty);

  @override
  List<Object?> get props => [fromDate, toDate, documentType, invoiceNumber, receiptNumber];
}
