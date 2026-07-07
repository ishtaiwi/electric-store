import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/services/pdf_service.dart';
import '../../../settings/domain/repositories/settings_repository.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/sale_item.dart';
import '../../domain/repositories/invoice_repository.dart';

// Events
abstract class InvoiceEvent extends Equatable {
  const InvoiceEvent();

  @override
  List<Object?> get props => [];
}

class InvoiceLoadAll extends InvoiceEvent {}

class InvoiceRefresh extends InvoiceEvent {}

class InvoiceLoadById extends InvoiceEvent {
  final int id;

  const InvoiceLoadById(this.id);

  @override
  List<Object?> get props => [id];
}

class InvoiceLoadByDateRange extends InvoiceEvent {
  final DateTime start;
  final DateTime end;

  const InvoiceLoadByDateRange({required this.start, required this.end});

  @override
  List<Object?> get props => [start, end];
}

class InvoiceLoadByCustomer extends InvoiceEvent {
  final int customerId;

  const InvoiceLoadByCustomer(this.customerId);

  @override
  List<Object?> get props => [customerId];
}

class InvoiceLoadToday extends InvoiceEvent {}

class InvoiceDelete extends InvoiceEvent {
  final int id;

  const InvoiceDelete(this.id);

  @override
  List<Object?> get props => [id];
}

class InvoiceLoadDetails extends InvoiceEvent {
  final int invoiceId;

  const InvoiceLoadDetails(this.invoiceId);

  @override
  List<Object?> get props => [invoiceId];
}

class InvoicePrint extends InvoiceEvent {
  final int invoiceId;

  const InvoicePrint(this.invoiceId);

  @override
  List<Object?> get props => [invoiceId];
}

class InvoiceSavePdf extends InvoiceEvent {
  final int invoiceId;

  const InvoiceSavePdf(this.invoiceId);

  @override
  List<Object?> get props => [invoiceId];
}

class InvoiceUpdatePaidAmount extends InvoiceEvent {
  final int invoiceId;
  final double paidAmount;

  const InvoiceUpdatePaidAmount({required this.invoiceId, required this.paidAmount});

  @override
  List<Object?> get props => [invoiceId, paidAmount];
}

class InvoiceUpdateNotes extends InvoiceEvent {
  final int invoiceId;
  final String? notes;

  const InvoiceUpdateNotes({required this.invoiceId, this.notes});

  @override
  List<Object?> get props => [invoiceId, notes];
}

class InvoiceFullUpdate extends InvoiceEvent {
  final int invoiceId;
  final List<SaleItem> updatedItems;
  final double discountAmount;
  final String? customerName;
  final int? customerId;
  final String? paymentMethod;
  final double? paidAmount;

  const InvoiceFullUpdate({
    required this.invoiceId,
    required this.updatedItems,
    this.discountAmount = 0,
    this.customerName,
    this.customerId,
    this.paymentMethod,
    this.paidAmount,
  });

  @override
  List<Object?> get props => [invoiceId, updatedItems, discountAmount, customerName, customerId, paymentMethod, paidAmount];
}

/// Fast update: adds invoice to list without DB reload
class InvoiceAdded extends InvoiceEvent {
  final Invoice invoice;

  const InvoiceAdded(this.invoice);

  @override
  List<Object?> get props => [invoice];
}

/// Fast update: updates invoice in list without DB reload
class InvoiceUpdated extends InvoiceEvent {
  final Invoice invoice;

  const InvoiceUpdated(this.invoice);

  @override
  List<Object?> get props => [invoice];
}

// States
abstract class InvoiceState extends Equatable {
  const InvoiceState();

  @override
  List<Object?> get props => [];
}

class InvoiceInitial extends InvoiceState {}

class InvoiceLoading extends InvoiceState {}

class InvoiceListLoaded extends InvoiceState {
  final List<Invoice> invoices;

  const InvoiceListLoaded(this.invoices);

  @override
  List<Object?> get props => [invoices];
}

class InvoiceLoaded extends InvoiceState {
  final List<Invoice> invoices;

  const InvoiceLoaded(this.invoices);

  @override
  List<Object?> get props => [invoices];
}

class InvoiceDetailsLoaded extends InvoiceState {
  final Invoice invoice;
  final List<SaleItem> items;

  const InvoiceDetailsLoaded(this.invoice, this.items);

  @override
  List<Object?> get props => [invoice, items];
}

class InvoiceError extends InvoiceState {
  final String message;

  const InvoiceError(this.message);

  @override
  List<Object?> get props => [message];
}

class InvoiceOperationSuccess extends InvoiceState {
  final String message;

  const InvoiceOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class InvoicePdfSaved extends InvoiceState {
  final String filePath;
  final String message;

  const InvoicePdfSaved({required this.filePath, required this.message});

  @override
  List<Object?> get props => [filePath, message];
}

// BLoC
class InvoiceBloc extends Bloc<InvoiceEvent, InvoiceState> {
  final InvoiceRepository _invoiceRepository;
  final PdfService _pdfService;
  final SettingsRepository _settingsRepository;
  
  // Persistent list that survives state transitions (details, success, error, etc.)
  List<Invoice> _lastKnownInvoices = [];

  InvoiceBloc(
    this._invoiceRepository,
    this._pdfService,
    this._settingsRepository,
  ) : super(InvoiceInitial()) {
    on<InvoiceLoadAll>(_onLoadAll);
    on<InvoiceRefresh>(_onRefresh);
    on<InvoiceLoadById>(_onLoadById);
    on<InvoiceLoadByDateRange>(_onLoadByDateRange);
    on<InvoiceLoadByCustomer>(_onLoadByCustomer);
    on<InvoiceLoadToday>(_onLoadToday);
    on<InvoiceDelete>(_onDelete);
    on<InvoiceLoadDetails>(_onLoadDetails);
    on<InvoicePrint>(_onPrint);
    on<InvoiceSavePdf>(_onSavePdf);
    on<InvoiceUpdatePaidAmount>(_onUpdatePaidAmount);
    on<InvoiceUpdateNotes>(_onUpdateNotes);
    on<InvoiceFullUpdate>(_onFullUpdate);
    on<InvoiceAdded>(_onInvoiceAdded);
    on<InvoiceUpdated>(_onInvoiceUpdated);
  }

  Future<void> _onLoadAll(
    InvoiceLoadAll event,
    Emitter<InvoiceState> emit,
  ) async {
    if (_lastKnownInvoices.isNotEmpty && state is InvoiceListLoaded) {
      return;
    }
    emit(InvoiceLoading());
    try {
      final invoices = await _invoiceRepository.getAllInvoices();
      _lastKnownInvoices = invoices;
      emit(InvoiceListLoaded(invoices));
    } catch (e) {
      if (_lastKnownInvoices.isNotEmpty) {
        emit(InvoiceListLoaded(_lastKnownInvoices));
      }
      emit(InvoiceError(e.toString()));
    }
  }

  Future<void> _onRefresh(
    InvoiceRefresh event,
    Emitter<InvoiceState> emit,
  ) async {
    try {
      final invoices = await _invoiceRepository.getAllInvoices();
      _lastKnownInvoices = invoices;
      emit(InvoiceListLoaded(invoices));
    } catch (e) {
      if (_lastKnownInvoices.isNotEmpty) {
        emit(InvoiceListLoaded(_lastKnownInvoices));
      }
      emit(InvoiceError(e.toString()));
    }
  }

  Future<void> _onLoadById(
    InvoiceLoadById event,
    Emitter<InvoiceState> emit,
  ) async {
    emit(InvoiceLoading());
    try {
      final invoice = await _invoiceRepository.getInvoiceById(event.id);
      if (invoice != null) {
        final items = await _invoiceRepository.getInvoiceItems(event.id);
        emit(InvoiceDetailsLoaded(invoice, items));
      } else {
        emit(InvoiceError(LocalizationService().get('invoiceNotFound')));
      }
    } catch (e) {
      emit(InvoiceError(e.toString()));
    }
  }

  Future<void> _onLoadByDateRange(
    InvoiceLoadByDateRange event,
    Emitter<InvoiceState> emit,
  ) async {
    // Don't emit loading to avoid flicker — keep showing old data
    try {
      final invoices = await _invoiceRepository.getInvoicesByDateRange(event.start, event.end);
      _lastKnownInvoices = invoices;
      emit(InvoiceListLoaded(invoices));
    } catch (e) {
      if (_lastKnownInvoices.isNotEmpty) {
        emit(InvoiceListLoaded(_lastKnownInvoices));
      }
      emit(InvoiceError(e.toString()));
    }
  }

  Future<void> _onLoadByCustomer(
    InvoiceLoadByCustomer event,
    Emitter<InvoiceState> emit,
  ) async {
    try {
      final invoices = await _invoiceRepository.getInvoicesByCustomer(event.customerId);
      _lastKnownInvoices = invoices;
      emit(InvoiceListLoaded(invoices));
    } catch (e) {
      if (_lastKnownInvoices.isNotEmpty) {
        emit(InvoiceListLoaded(_lastKnownInvoices));
      }
      emit(InvoiceError(e.toString()));
    }
  }

  Future<void> _onLoadToday(
    InvoiceLoadToday event,
    Emitter<InvoiceState> emit,
  ) async {
    try {
      final invoices = await _invoiceRepository.getInvoicesToday();
      _lastKnownInvoices = invoices;
      emit(InvoiceListLoaded(invoices));
    } catch (e) {
      if (_lastKnownInvoices.isNotEmpty) {
        emit(InvoiceListLoaded(_lastKnownInvoices));
      }
      emit(InvoiceError(e.toString()));
    }
  }

  Future<void> _onDelete(
    InvoiceDelete event,
    Emitter<InvoiceState> emit,
  ) async {
    try {
      await _invoiceRepository.deleteInvoice(event.id);
      
      // Remove from persistent list
      _lastKnownInvoices = _lastKnownInvoices.where((inv) => inv.id != event.id).toList();
      
      emit(InvoiceListLoaded(List.from(_lastKnownInvoices)));
      emit(InvoiceOperationSuccess(LocalizationService().get('invoiceDeleted')));
      // Re-emit list to keep UI showing after success state
      emit(InvoiceListLoaded(List.from(_lastKnownInvoices)));
    } catch (e) {
      emit(InvoiceError(e.toString()));
    }
  }

  Future<void> _onLoadDetails(
    InvoiceLoadDetails event,
    Emitter<InvoiceState> emit,
  ) async {
    try {
      final invoice = await _invoiceRepository.getInvoiceById(event.invoiceId);
      if (invoice != null) {
        final items = await _invoiceRepository.getInvoiceItems(event.invoiceId);
        emit(InvoiceDetailsLoaded(invoice, items));
      } else {
        emit(InvoiceError(LocalizationService().get('invoiceNotFound')));
      }
    } catch (e) {
      emit(InvoiceError(e.toString()));
    }
  }

  Future<void> _onPrint(
    InvoicePrint event,
    Emitter<InvoiceState> emit,
  ) async {
    try {
      final invoice = await _invoiceRepository.getInvoiceById(event.invoiceId);
      if (invoice == null) {
        emit(InvoiceError(LocalizationService().get('invoiceNotFound')));
        return;
      }
      
      final items = await _invoiceRepository.getInvoiceItems(event.invoiceId);
      final settings = await _settingsRepository.getSettings();
      
      await _pdfService.printInvoice(
        invoice: invoice,
        items: items,
        storeSettings: settings,
      );
      
      emit(InvoiceOperationSuccess(LocalizationService().get('invoiceSentToPrinter')));
    } catch (e) {
      emit(InvoiceError('Print failed: ${e.toString()}'));
    }
  }

  Future<void> _onSavePdf(
    InvoiceSavePdf event,
    Emitter<InvoiceState> emit,
  ) async {
    try {
      final invoice = await _invoiceRepository.getInvoiceById(event.invoiceId);
      if (invoice == null) {
        emit(InvoiceError(LocalizationService().get('invoiceNotFound')));
        return;
      }
      
      final items = await _invoiceRepository.getInvoiceItems(event.invoiceId);
      final settings = await _settingsRepository.getSettings();
      
      final filePath = await _pdfService.saveInvoicePdf(
        invoice: invoice,
        items: items,
        storeSettings: settings,
      );
      
      emit(InvoicePdfSaved(
        filePath: filePath,
        message: '${LocalizationService().get('invoiceSavedTo')} $filePath',
      ));
    } catch (e) {
      emit(InvoiceError('Save PDF failed: ${e.toString()}'));
    }
  }

  Future<void> _onUpdatePaidAmount(
    InvoiceUpdatePaidAmount event,
    Emitter<InvoiceState> emit,
  ) async {
    try {
      await _invoiceRepository.updateInvoicePaidAmount(event.invoiceId, event.paidAmount);
      
      // Re-read invoice from DB to get the actual recalculated paid amount
      final updatedInvoice = await _invoiceRepository.getInvoiceById(event.invoiceId);
      
      // Update in persistent list
      final index = _lastKnownInvoices.indexWhere((inv) => inv.id == event.invoiceId);
      if (index != -1) {
        if (updatedInvoice != null) {
          _lastKnownInvoices[index] = updatedInvoice;
        } else {
          _lastKnownInvoices[index] = _lastKnownInvoices[index].copyWith(paidAmount: event.paidAmount);
        }
      }
      
      emit(InvoiceListLoaded(List.from(_lastKnownInvoices)));
      emit(InvoiceOperationSuccess(LocalizationService().get('paymentRecorded')));
      // Re-emit list to keep UI showing after success state
      emit(InvoiceListLoaded(List.from(_lastKnownInvoices)));
    } catch (e) {
      emit(InvoiceError(e.toString()));
    }
  }

  Future<void> _onUpdateNotes(
    InvoiceUpdateNotes event,
    Emitter<InvoiceState> emit,
  ) async {
    try {
      await _invoiceRepository.updateInvoiceNotes(event.invoiceId, event.notes);
      
      // Update in persistent list
      final index = _lastKnownInvoices.indexWhere((inv) => inv.id == event.invoiceId);
      if (index != -1) {
        _lastKnownInvoices[index] = _lastKnownInvoices[index].copyWith(notes: event.notes);
      }
      
      emit(InvoiceListLoaded(List.from(_lastKnownInvoices)));
      emit(InvoiceOperationSuccess(LocalizationService().get('notesSaved')));
      // Re-emit list to keep UI showing after success state
      emit(InvoiceListLoaded(List.from(_lastKnownInvoices)));
    } catch (e) {
      emit(InvoiceError(e.toString()));
    }
  }

  Future<void> _onFullUpdate(
    InvoiceFullUpdate event,
    Emitter<InvoiceState> emit,
  ) async {
    try {
      final updatedInvoice = await _invoiceRepository.updateInvoice(
        invoiceId: event.invoiceId,
        updatedItems: event.updatedItems,
        discountAmount: event.discountAmount,
        customerName: event.customerName,
        customerId: event.customerId,
        paymentMethod: event.paymentMethod,
        paidAmount: event.paidAmount,
      );

      if (updatedInvoice != null) {
        // Update in persistent list
        final index = _lastKnownInvoices.indexWhere((inv) => inv.id == event.invoiceId);
        if (index != -1) {
          _lastKnownInvoices[index] = updatedInvoice;
        }

        emit(InvoiceListLoaded(List.from(_lastKnownInvoices)));
        emit(InvoiceOperationSuccess(LocalizationService().get('invoiceUpdated')));
        emit(InvoiceListLoaded(List.from(_lastKnownInvoices)));
      } else {
        emit(InvoiceError(LocalizationService().get('invoiceNotFound')));
      }
    } catch (e) {
      emit(InvoiceError(e.toString()));
    }
  }

  /// Fast update: add invoice to beginning of list without DB reload
  void _onInvoiceAdded(
    InvoiceAdded event,
    Emitter<InvoiceState> emit,
  ) {
    // Add to persistent list at the beginning (most recent first)
    _lastKnownInvoices = [event.invoice, ..._lastKnownInvoices];
    emit(InvoiceListLoaded(List.from(_lastKnownInvoices)));
  }

  /// Fast update: update invoice in list without DB reload
  void _onInvoiceUpdated(
    InvoiceUpdated event,
    Emitter<InvoiceState> emit,
  ) {
    final index = _lastKnownInvoices.indexWhere((inv) => inv.id == event.invoice.id);
    if (index != -1) {
      _lastKnownInvoices[index] = event.invoice;
    }
    emit(InvoiceListLoaded(List.from(_lastKnownInvoices)));
  }
}
