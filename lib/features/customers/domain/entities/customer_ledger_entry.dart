import 'package:equatable/equatable.dart';
import '../../../invoices/domain/entities/sale_item.dart';
import 'customer_payment.dart';

enum LedgerDocumentType {
  openingBalance,
  salesInvoice,
  paymentReceipt,
  salesReturn,
  manualAdjustment,
  accountDiscount,
}

class CustomerLedgerEntry extends Equatable {
  final int? invoiceId;
  final int? paymentId;
  final DateTime date;
  final String documentNumber;
  final LedgerDocumentType documentType;
  final double debit;
  final double credit;
  final double runningBalance;
  final String? notes;
  final String? invoiceNumber;
  final CustomerPaymentMethod? paymentMethod;
  final String? chequeNumber;
  final List<SaleItem>? lineItems;

  const CustomerLedgerEntry({
    this.invoiceId,
    this.paymentId,
    required this.date,
    required this.documentNumber,
    required this.documentType,
    this.debit = 0,
    this.credit = 0,
    this.runningBalance = 0,
    this.notes,
    this.invoiceNumber,
    this.paymentMethod,
    this.chequeNumber,
    this.lineItems,
  });

  bool get isOpeningBalance => documentType == LedgerDocumentType.openingBalance;
  bool get isSalesInvoice => documentType == LedgerDocumentType.salesInvoice;
  bool get isPayment => documentType == LedgerDocumentType.paymentReceipt;
  bool get isDiscount => documentType == LedgerDocumentType.accountDiscount;
  bool get isManualAdjustment => documentType == LedgerDocumentType.manualAdjustment;
  bool get isExpandable => isSalesInvoice && invoiceId != null;
  bool get showLineItems => isSalesInvoice && invoiceId != null;

  CustomerLedgerEntry copyWith({
    int? invoiceId,
    int? paymentId,
    DateTime? date,
    String? documentNumber,
    LedgerDocumentType? documentType,
    double? debit,
    double? credit,
    double? runningBalance,
    String? notes,
    String? invoiceNumber,
    CustomerPaymentMethod? paymentMethod,
    String? chequeNumber,
    List<SaleItem>? lineItems,
  }) {
    return CustomerLedgerEntry(
      invoiceId: invoiceId ?? this.invoiceId,
      paymentId: paymentId ?? this.paymentId,
      date: date ?? this.date,
      documentNumber: documentNumber ?? this.documentNumber,
      documentType: documentType ?? this.documentType,
      debit: debit ?? this.debit,
      credit: credit ?? this.credit,
      runningBalance: runningBalance ?? this.runningBalance,
      notes: notes ?? this.notes,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      chequeNumber: chequeNumber ?? this.chequeNumber,
      lineItems: lineItems ?? this.lineItems,
    );
  }

  @override
  List<Object?> get props => [
        invoiceId,
        paymentId,
        date,
        documentNumber,
        documentType,
        debit,
        credit,
        runningBalance,
        notes,
      ];
}
