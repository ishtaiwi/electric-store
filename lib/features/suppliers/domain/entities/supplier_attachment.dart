import 'package:equatable/equatable.dart';

class SupplierAttachment extends Equatable {
  final int? id;
  final int supplierId;
  final String filePath;
  final String fileName;
  final String fileType; // 'pdf' or 'image'
  final String? comment;
  final DateTime? uploadDate;

  const SupplierAttachment({
    this.id,
    required this.supplierId,
    required this.filePath,
    required this.fileName,
    required this.fileType,
    this.comment,
    this.uploadDate,
  });

  factory SupplierAttachment.fromMap(Map<String, dynamic> map) {
    return SupplierAttachment(
      id: map['id'] as int?,
      supplierId: map['supplier_id'] as int,
      filePath: map['file_path'] as String,
      fileName: map['file_name'] as String,
      fileType: map['file_type'] as String,
      comment: map['comment'] as String?,
      uploadDate: map['upload_date'] != null
          ? DateTime.parse(map['upload_date'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'supplier_id': supplierId,
      'file_path': filePath,
      'file_name': fileName,
      'file_type': fileType,
      'comment': comment,
    };
  }

  SupplierAttachment copyWith({
    int? id,
    int? supplierId,
    String? filePath,
    String? fileName,
    String? fileType,
    String? comment,
    DateTime? uploadDate,
  }) {
    return SupplierAttachment(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      fileType: fileType ?? this.fileType,
      comment: comment ?? this.comment,
      uploadDate: uploadDate ?? this.uploadDate,
    );
  }

  bool get isPdf => fileType.toLowerCase() == 'pdf';
  bool get isImage => !isPdf;

  @override
  List<Object?> get props => [id, supplierId, filePath, fileName, fileType, comment, uploadDate];
}
