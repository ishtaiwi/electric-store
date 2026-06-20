import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/services/localization_service.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/entities/supplier_attachment.dart';
import '../../domain/entities/supplier_invoice.dart';
import '../../domain/entities/supplier_payment.dart';
import '../../domain/repositories/supplier_repository.dart';

// ─── Events ───

abstract class SupplierEvent extends Equatable {
  const SupplierEvent();
  @override
  List<Object?> get props => [];
}

class SupplierLoadAll extends SupplierEvent {}

class SupplierRefresh extends SupplierEvent {}

class SupplierCreate extends SupplierEvent {
  final Supplier supplier;
  const SupplierCreate(this.supplier);
  @override
  List<Object?> get props => [supplier];
}

class SupplierUpdate extends SupplierEvent {
  final Supplier supplier;
  const SupplierUpdate(this.supplier);
  @override
  List<Object?> get props => [supplier];
}

class SupplierDelete extends SupplierEvent {
  final int id;
  const SupplierDelete(this.id);
  @override
  List<Object?> get props => [id];
}

class SupplierLoadAttachments extends SupplierEvent {
  final int supplierId;
  const SupplierLoadAttachments(this.supplierId);
  @override
  List<Object?> get props => [supplierId];
}

class SupplierAddAttachment extends SupplierEvent {
  final SupplierAttachment attachment;
  const SupplierAddAttachment(this.attachment);
  @override
  List<Object?> get props => [attachment];
}

class SupplierUpdateAttachmentComment extends SupplierEvent {
  final int attachmentId;
  final String comment;
  final int supplierId;
  const SupplierUpdateAttachmentComment({
    required this.attachmentId,
    required this.comment,
    required this.supplierId,
  });
  @override
  List<Object?> get props => [attachmentId, comment, supplierId];
}

class SupplierDeleteAttachment extends SupplierEvent {
  final int attachmentId;
  final int supplierId;
  const SupplierDeleteAttachment({required this.attachmentId, required this.supplierId});
  @override
  List<Object?> get props => [attachmentId, supplierId];
}

// ─── Invoice Events ───

class SupplierLoadInvoices extends SupplierEvent {
  final int supplierId;
  const SupplierLoadInvoices(this.supplierId);
  @override
  List<Object?> get props => [supplierId];
}

class SupplierCreateInvoice extends SupplierEvent {
  final SupplierInvoice invoice;
  const SupplierCreateInvoice(this.invoice);
  @override
  List<Object?> get props => [invoice];
}

class SupplierUpdateInvoice extends SupplierEvent {
  final SupplierInvoice invoice;
  const SupplierUpdateInvoice(this.invoice);
  @override
  List<Object?> get props => [invoice];
}

class SupplierDeleteInvoice extends SupplierEvent {
  final int invoiceId;
  final int supplierId;
  const SupplierDeleteInvoice({required this.invoiceId, required this.supplierId});
  @override
  List<Object?> get props => [invoiceId, supplierId];
}

class SupplierRecordPayment extends SupplierEvent {
  final SupplierPayment payment;
  final int supplierId;
  const SupplierRecordPayment({required this.payment, required this.supplierId});
  @override
  List<Object?> get props => [payment, supplierId];
}

class SupplierDeletePayment extends SupplierEvent {
  final int paymentId;
  final int supplierId;
  const SupplierDeletePayment({required this.paymentId, required this.supplierId});
  @override
  List<Object?> get props => [paymentId, supplierId];
}

class SupplierLoadFinancialSummary extends SupplierEvent {
  final int supplierId;
  const SupplierLoadFinancialSummary(this.supplierId);
  @override
  List<Object?> get props => [supplierId];
}

class SupplierLoadPayments extends SupplierEvent {
  final int supplierId;
  const SupplierLoadPayments(this.supplierId);
  @override
  List<Object?> get props => [supplierId];
}

class SupplierLoadGlobalOutstanding extends SupplierEvent {}

class SupplierLoadAllOutstanding extends SupplierEvent {}

// ─── States ───

abstract class SupplierState extends Equatable {
  const SupplierState();
  @override
  List<Object?> get props => [];
}

class SupplierInitial extends SupplierState {}

class SupplierLoading extends SupplierState {}

class SupplierLoaded extends SupplierState {
  final List<Supplier> suppliers;
  final List<SupplierAttachment> attachments;
  final int? selectedSupplierId;
  final List<SupplierInvoice> invoices;
  final List<SupplierPayment> payments;
  final Map<String, dynamic>? financialSummary;
  final double? globalOutstanding;
  final List<Map<String, dynamic>>? allSuppliersOutstanding;

  const SupplierLoaded({
    required this.suppliers,
    this.attachments = const [],
    this.selectedSupplierId,
    this.invoices = const [],
    this.payments = const [],
    this.financialSummary,
    this.globalOutstanding,
    this.allSuppliersOutstanding,
  });

  SupplierLoaded copyWithFinancial({
    List<SupplierInvoice>? invoices,
    List<SupplierPayment>? payments,
    Map<String, dynamic>? financialSummary,
    double? globalOutstanding,
    List<Map<String, dynamic>>? allSuppliersOutstanding,
    int? selectedSupplierId,
  }) {
    return SupplierLoaded(
      suppliers: suppliers,
      attachments: attachments,
      selectedSupplierId: selectedSupplierId ?? this.selectedSupplierId,
      invoices: invoices ?? this.invoices,
      payments: payments ?? this.payments,
      financialSummary: financialSummary ?? this.financialSummary,
      globalOutstanding: globalOutstanding ?? this.globalOutstanding,
      allSuppliersOutstanding: allSuppliersOutstanding ?? this.allSuppliersOutstanding,
    );
  }

  @override
  List<Object?> get props => [
        suppliers, attachments, selectedSupplierId,
        invoices, payments, financialSummary,
        globalOutstanding, allSuppliersOutstanding,
      ];
}

class SupplierError extends SupplierState {
  final String message;
  const SupplierError(this.message);
  @override
  List<Object?> get props => [message];
}

class SupplierOperationSuccess extends SupplierState {
  final String message;
  const SupplierOperationSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ───

class SupplierBloc extends Bloc<SupplierEvent, SupplierState> {
  final SupplierRepository _supplierRepository;
  bool _hasLoadedOnce = false;

  SupplierBloc(this._supplierRepository) : super(SupplierInitial()) {
    on<SupplierLoadAll>(_onLoadAll);
    on<SupplierRefresh>(_onRefresh);
    on<SupplierCreate>(_onCreate);
    on<SupplierUpdate>(_onUpdate);
    on<SupplierDelete>(_onDelete);
    on<SupplierLoadAttachments>(_onLoadAttachments);
    on<SupplierAddAttachment>(_onAddAttachment);
    on<SupplierUpdateAttachmentComment>(_onUpdateAttachmentComment);
    on<SupplierDeleteAttachment>(_onDeleteAttachment);
    on<SupplierLoadInvoices>(_onLoadInvoices);
    on<SupplierCreateInvoice>(_onCreateInvoice);
    on<SupplierUpdateInvoice>(_onUpdateInvoice);
    on<SupplierDeleteInvoice>(_onDeleteInvoice);
    on<SupplierRecordPayment>(_onRecordPayment);
    on<SupplierDeletePayment>(_onDeletePayment);
    on<SupplierLoadFinancialSummary>(_onLoadFinancialSummary);
    on<SupplierLoadPayments>(_onLoadPayments);
    on<SupplierLoadGlobalOutstanding>(_onLoadGlobalOutstanding);
    on<SupplierLoadAllOutstanding>(_onLoadAllOutstanding);
  }

  Future<void> _onLoadAll(SupplierLoadAll event, Emitter<SupplierState> emit) async {
    if (_hasLoadedOnce && state is SupplierLoaded) return;
    emit(SupplierLoading());
    try {
      final suppliers = await _supplierRepository.getAllSuppliers();
      _hasLoadedOnce = true;
      emit(SupplierLoaded(suppliers: suppliers));
    } catch (e) {
      emit(SupplierError(e.toString()));
    }
  }

  Future<void> _onRefresh(SupplierRefresh event, Emitter<SupplierState> emit) async {
    emit(SupplierLoading());
    try {
      final suppliers = await _supplierRepository.getAllSuppliers();
      _hasLoadedOnce = true;
      emit(SupplierLoaded(suppliers: suppliers));
    } catch (e) {
      emit(SupplierError(e.toString()));
    }
  }

  Future<void> _onCreate(SupplierCreate event, Emitter<SupplierState> emit) async {
    final currentState = state;
    List<Supplier> currentList = [];
    if (currentState is SupplierLoaded) {
      currentList = List<Supplier>.from(currentState.suppliers);
    }

    try {
      final id = await _supplierRepository.createSupplier(event.supplier);
      final created = event.supplier.copyWith(id: id);
      currentList.insert(0, created);
      // Sort by name
      currentList.sort((a, b) => a.name.compareTo(b.name));

      emit(SupplierLoaded(suppliers: currentList));
      emit(SupplierOperationSuccess(LocalizationService().get('supplierCreated')));
      emit(SupplierLoaded(suppliers: currentList));
    } catch (e) {
      emit(SupplierError(e.toString()));
    }
  }

  Future<void> _onUpdate(SupplierUpdate event, Emitter<SupplierState> emit) async {
    final currentState = state;
    List<Supplier> currentList = [];
    if (currentState is SupplierLoaded) {
      currentList = List<Supplier>.from(currentState.suppliers);
    }

    try {
      await _supplierRepository.updateSupplier(event.supplier);
      final idx = currentList.indexWhere((s) => s.id == event.supplier.id);
      if (idx != -1) {
        currentList[idx] = event.supplier;
      }
      currentList.sort((a, b) => a.name.compareTo(b.name));

      emit(SupplierLoaded(suppliers: currentList));
      emit(SupplierOperationSuccess(LocalizationService().get('supplierUpdated')));
      emit(SupplierLoaded(suppliers: currentList));
    } catch (e) {
      emit(SupplierError(e.toString()));
    }
  }

  Future<void> _onDelete(SupplierDelete event, Emitter<SupplierState> emit) async {
    final currentState = state;
    List<Supplier> currentList = [];
    if (currentState is SupplierLoaded) {
      currentList = List<Supplier>.from(currentState.suppliers);
    }

    try {
      await _supplierRepository.deleteSupplier(event.id);
      currentList.removeWhere((s) => s.id == event.id);

      emit(SupplierLoaded(suppliers: currentList));
      emit(SupplierOperationSuccess(LocalizationService().get('supplierDeleted')));
      emit(SupplierLoaded(suppliers: currentList));
    } catch (e) {
      emit(SupplierError(e.toString()));
    }
  }

  Future<void> _onLoadAttachments(SupplierLoadAttachments event, Emitter<SupplierState> emit) async {
    final currentState = state;
    List<Supplier> currentList = [];
    if (currentState is SupplierLoaded) {
      currentList = currentState.suppliers;
    }

    try {
      final attachments = await _supplierRepository.getAttachmentsBySupplier(event.supplierId);
      emit(SupplierLoaded(
        suppliers: currentList,
        attachments: attachments,
        selectedSupplierId: event.supplierId,
      ));
    } catch (e) {
      emit(SupplierError(e.toString()));
    }
  }

  Future<void> _onAddAttachment(SupplierAddAttachment event, Emitter<SupplierState> emit) async {
    final currentState = state;
    List<Supplier> currentList = [];
    int? selectedId;
    if (currentState is SupplierLoaded) {
      currentList = currentState.suppliers;
      selectedId = currentState.selectedSupplierId;
    }

    try {
      await _supplierRepository.addAttachment(event.attachment);
      // Reload attachments for the supplier
      final attachments = await _supplierRepository.getAttachmentsBySupplier(event.attachment.supplierId);

      emit(SupplierLoaded(
        suppliers: currentList,
        attachments: attachments,
        selectedSupplierId: selectedId,
      ));
      emit(SupplierOperationSuccess(LocalizationService().get('attachmentAdded')));
      emit(SupplierLoaded(
        suppliers: currentList,
        attachments: attachments,
        selectedSupplierId: selectedId,
      ));
    } catch (e) {
      emit(SupplierError(e.toString()));
    }
  }

  Future<void> _onUpdateAttachmentComment(
    SupplierUpdateAttachmentComment event,
    Emitter<SupplierState> emit,
  ) async {
    final currentState = state;
    List<Supplier> currentList = [];
    if (currentState is SupplierLoaded) {
      currentList = currentState.suppliers;
    }

    try {
      await _supplierRepository.updateAttachmentComment(event.attachmentId, event.comment);
      final attachments = await _supplierRepository.getAttachmentsBySupplier(event.supplierId);

      emit(SupplierLoaded(
        suppliers: currentList,
        attachments: attachments,
        selectedSupplierId: event.supplierId,
      ));
    } catch (e) {
      emit(SupplierError(e.toString()));
    }
  }

  Future<void> _onDeleteAttachment(SupplierDeleteAttachment event, Emitter<SupplierState> emit) async {
    final currentState = state;
    List<Supplier> currentList = [];
    if (currentState is SupplierLoaded) {
      currentList = currentState.suppliers;
    }

    try {
      await _supplierRepository.deleteAttachment(event.attachmentId);
      final attachments = await _supplierRepository.getAttachmentsBySupplier(event.supplierId);

      emit(SupplierLoaded(
        suppliers: currentList,
        attachments: attachments,
        selectedSupplierId: event.supplierId,
      ));
      emit(SupplierOperationSuccess(LocalizationService().get('attachmentDeleted')));
      emit(SupplierLoaded(
        suppliers: currentList,
        attachments: attachments,
        selectedSupplierId: event.supplierId,
      ));
    } catch (e) {
      emit(SupplierError(e.toString()));
    }
  }

  // ─── Invoice Handlers ───

  SupplierLoaded _getCurrentLoaded() {
    final s = state;
    if (s is SupplierLoaded) return s;
    return const SupplierLoaded(suppliers: []);
  }

  Future<void> _onLoadInvoices(SupplierLoadInvoices event, Emitter<SupplierState> emit) async {
    try {
      final invoices = await _supplierRepository.getInvoicesBySupplier(event.supplierId);
      final summary = await _supplierRepository.getSupplierFinancialSummary(event.supplierId);
      final current = _getCurrentLoaded();
      emit(current.copyWithFinancial(
        invoices: invoices,
        financialSummary: summary,
        selectedSupplierId: event.supplierId,
      ));
    } catch (e) {
      emit(SupplierError(e.toString()));
    }
  }

  Future<void> _onCreateInvoice(SupplierCreateInvoice event, Emitter<SupplierState> emit) async {
    try {
      await _supplierRepository.createInvoice(event.invoice);
      final invoices = await _supplierRepository.getInvoicesBySupplier(event.invoice.supplierId);
      final summary = await _supplierRepository.getSupplierFinancialSummary(event.invoice.supplierId);
      final current = _getCurrentLoaded();
      emit(current.copyWithFinancial(
        invoices: invoices,
        financialSummary: summary,
        selectedSupplierId: event.invoice.supplierId,
      ));
      emit(SupplierOperationSuccess(LocalizationService().get('supplierInvoiceCreated')));
      emit(current.copyWithFinancial(
        invoices: invoices,
        financialSummary: summary,
        selectedSupplierId: event.invoice.supplierId,
      ));
    } catch (e) {
      emit(SupplierError(e.toString()));
    }
  }

  Future<void> _onUpdateInvoice(SupplierUpdateInvoice event, Emitter<SupplierState> emit) async {
    try {
      await _supplierRepository.updateInvoice(event.invoice);
      final invoices = await _supplierRepository.getInvoicesBySupplier(event.invoice.supplierId);
      final summary = await _supplierRepository.getSupplierFinancialSummary(event.invoice.supplierId);
      final current = _getCurrentLoaded();
      emit(current.copyWithFinancial(
        invoices: invoices,
        financialSummary: summary,
        selectedSupplierId: event.invoice.supplierId,
      ));
      emit(SupplierOperationSuccess(LocalizationService().get('supplierInvoiceUpdated')));
      emit(current.copyWithFinancial(
        invoices: invoices,
        financialSummary: summary,
        selectedSupplierId: event.invoice.supplierId,
      ));
    } catch (e) {
      emit(SupplierError(e.toString()));
    }
  }

  Future<void> _onDeleteInvoice(SupplierDeleteInvoice event, Emitter<SupplierState> emit) async {
    try {
      await _supplierRepository.deleteInvoice(event.invoiceId);
      final invoices = await _supplierRepository.getInvoicesBySupplier(event.supplierId);
      final summary = await _supplierRepository.getSupplierFinancialSummary(event.supplierId);
      final current = _getCurrentLoaded();
      emit(current.copyWithFinancial(
        invoices: invoices,
        financialSummary: summary,
        selectedSupplierId: event.supplierId,
      ));
      emit(SupplierOperationSuccess(LocalizationService().get('supplierInvoiceDeleted')));
      emit(current.copyWithFinancial(
        invoices: invoices,
        financialSummary: summary,
        selectedSupplierId: event.supplierId,
      ));
    } catch (e) {
      emit(SupplierError(e.toString()));
    }
  }

  Future<void> _onRecordPayment(SupplierRecordPayment event, Emitter<SupplierState> emit) async {
    try {
      await _supplierRepository.recordPayment(event.payment);
      final invoices = await _supplierRepository.getInvoicesBySupplier(event.supplierId);
      final payments = await _supplierRepository.getPaymentsBySupplier(event.supplierId);
      final summary = await _supplierRepository.getSupplierFinancialSummary(event.supplierId);
      final current = _getCurrentLoaded();
      emit(current.copyWithFinancial(
        invoices: invoices,
        payments: payments,
        financialSummary: summary,
        selectedSupplierId: event.supplierId,
      ));
      emit(SupplierOperationSuccess(LocalizationService().get('supplierPaymentRecorded')));
      emit(current.copyWithFinancial(
        invoices: invoices,
        payments: payments,
        financialSummary: summary,
        selectedSupplierId: event.supplierId,
      ));
    } catch (e) {
      emit(SupplierError(e.toString()));
    }
  }

  Future<void> _onDeletePayment(SupplierDeletePayment event, Emitter<SupplierState> emit) async {
    try {
      await _supplierRepository.deletePayment(event.paymentId);
      final invoices = await _supplierRepository.getInvoicesBySupplier(event.supplierId);
      final payments = await _supplierRepository.getPaymentsBySupplier(event.supplierId);
      final summary = await _supplierRepository.getSupplierFinancialSummary(event.supplierId);
      final current = _getCurrentLoaded();
      emit(current.copyWithFinancial(
        invoices: invoices,
        payments: payments,
        financialSummary: summary,
        selectedSupplierId: event.supplierId,
      ));
      emit(SupplierOperationSuccess(LocalizationService().get('supplierPaymentDeleted')));
      emit(current.copyWithFinancial(
        invoices: invoices,
        payments: payments,
        financialSummary: summary,
        selectedSupplierId: event.supplierId,
      ));
    } catch (e) {
      emit(SupplierError(e.toString()));
    }
  }

  Future<void> _onLoadPayments(SupplierLoadPayments event, Emitter<SupplierState> emit) async {
    try {
      final payments = await _supplierRepository.getPaymentsBySupplier(event.supplierId);
      final current = _getCurrentLoaded();
      emit(current.copyWithFinancial(
        payments: payments,
        selectedSupplierId: event.supplierId,
      ));
    } catch (e) {
      emit(SupplierError(e.toString()));
    }
  }

  Future<void> _onLoadFinancialSummary(SupplierLoadFinancialSummary event, Emitter<SupplierState> emit) async {
    try {
      final summary = await _supplierRepository.getSupplierFinancialSummary(event.supplierId);
      final current = _getCurrentLoaded();
      emit(current.copyWithFinancial(
        financialSummary: summary,
        selectedSupplierId: event.supplierId,
      ));
    } catch (e) {
      emit(SupplierError(e.toString()));
    }
  }

  Future<void> _onLoadGlobalOutstanding(SupplierLoadGlobalOutstanding event, Emitter<SupplierState> emit) async {
    try {
      final outstanding = await _supplierRepository.getGlobalOutstandingBalance();
      final current = _getCurrentLoaded();
      emit(current.copyWithFinancial(globalOutstanding: outstanding));
    } catch (e) {
      emit(SupplierError(e.toString()));
    }
  }

  Future<void> _onLoadAllOutstanding(SupplierLoadAllOutstanding event, Emitter<SupplierState> emit) async {
    try {
      final allOutstanding = await _supplierRepository.getAllSuppliersOutstanding();
      final globalOutstanding = await _supplierRepository.getGlobalOutstandingBalance();
      final current = _getCurrentLoaded();
      emit(current.copyWithFinancial(
        allSuppliersOutstanding: allOutstanding,
        globalOutstanding: globalOutstanding,
      ));
    } catch (e) {
      emit(SupplierError(e.toString()));
    }
  }
}
