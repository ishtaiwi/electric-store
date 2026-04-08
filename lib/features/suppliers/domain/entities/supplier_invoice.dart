import 'package:equatable/equatable.dart';

enum InvoicePaymentStatus {
  paid,
  partiallyPaid,
  unpaid,
}

class SupplierInvoice extends Equatable {
  final int? id;
  final int supplierId;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final double totalAmount;
  final double paidAmount;
  final String? filePath;
  final String? fileName;
  final String? fileType; // 'pdf' or 'image'
  final String? notes;
  final DateTime? createdDate;

  const SupplierInvoice({
    this.id,
    required this.supplierId,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.totalAmount,
    this.paidAmount = 0,
    this.filePath,
    this.fileName,
    this.fileType,
    this.notes,
    this.createdDate,
  });

  double get remainingAmount => totalAmount - paidAmount;

  InvoicePaymentStatus get paymentStatus {
    if (paidAmount >= totalAmount) return InvoicePaymentStatus.paid;
    if (paidAmount > 0) return InvoicePaymentStatus.partiallyPaid;
    return InvoicePaymentStatus.unpaid;
  }

  bool get isPaid => paymentStatus == InvoicePaymentStatus.paid;
  bool get isPartiallyPaid => paymentStatus == InvoicePaymentStatus.partiallyPaid;
  bool get isUnpaid => paymentStatus == InvoicePaymentStatus.unpaid;

  factory SupplierInvoice.fromMap(Map<String, dynamic> map) {
    return SupplierInvoice(
      id: map['id'] as int?,
      supplierId: map['supplier_id'] as int,
      invoiceNumber: map['invoice_number'] as String,
      invoiceDate: DateTime.parse(map['invoice_date'] as String),
      totalAmount: (map['total_amount'] as num).toDouble(),
      paidAmount: (map['paid_amount'] as num?)?.toDouble() ?? 0,
      filePath: map['file_path'] as String?,
      fileName: map['file_name'] as String?,
      fileType: map['file_type'] as String?,
      notes: map['notes'] as String?,
      createdDate: map['created_date'] != null
          ? DateTime.parse(map['created_date'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'supplier_id': supplierId,
      'invoice_number': invoiceNumber,
      'invoice_date': invoiceDate.toIso8601String(),
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'file_path': filePath,
      'file_name': fileName,
      'file_type': fileType,
      'notes': notes,
    };
  }

  SupplierInvoice copyWith({
    int? id,
    int? supplierId,
    String? invoiceNumber,
    DateTime? invoiceDate,
    double? totalAmount,
    double? paidAmount,
    String? filePath,
    String? fileName,
    String? fileType,
    String? notes,
    DateTime? createdDate,
  }) {
    return SupplierInvoice(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      fileType: fileType ?? this.fileType,
      notes: notes ?? this.notes,
      createdDate: createdDate ?? this.createdDate,
    );
  }

  bool get hasFile => filePath != null && filePath!.isNotEmpty;
  bool get isPdf => fileType?.toLowerCase() == 'pdf';
  bool get isImage => fileType != null && !isPdf;

  @override
  List<Object?> get props => [
        id, supplierId, invoiceNumber, invoiceDate, totalAmount,
        paidAmount, filePath, fileName, fileType, notes, createdDate,
      ];
}
