import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/services/localization_service.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/entities/supplier_attachment.dart';
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

  const SupplierLoaded({
    required this.suppliers,
    this.attachments = const [],
    this.selectedSupplierId,
  });

  @override
  List<Object?> get props => [suppliers, attachments, selectedSupplierId];
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
}
