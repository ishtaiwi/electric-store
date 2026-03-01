import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/services/pdf_service.dart';
import '../../../settings/domain/repositories/settings_repository.dart';
import '../../domain/entities/price_list.dart';
import '../../domain/entities/price_list_item.dart';
import '../../domain/repositories/price_list_repository.dart';

// ==================== Events ====================

abstract class PriceListEvent extends Equatable {
  const PriceListEvent();

  @override
  List<Object?> get props => [];
}

class PriceListLoadAll extends PriceListEvent {}

class PriceListRefresh extends PriceListEvent {}

class PriceListLoadDetails extends PriceListEvent {
  final int priceListId;

  const PriceListLoadDetails(this.priceListId);

  @override
  List<Object?> get props => [priceListId];
}

class PriceListCreate extends PriceListEvent {
  final PriceList priceList;
  final List<PriceListItem> items;

  const PriceListCreate({required this.priceList, required this.items});

  @override
  List<Object?> get props => [priceList, items];
}

class PriceListUpdate extends PriceListEvent {
  final PriceList priceList;
  final List<PriceListItem> items;

  const PriceListUpdate({required this.priceList, required this.items});

  @override
  List<Object?> get props => [priceList, items];
}

class PriceListDelete extends PriceListEvent {
  final int id;

  const PriceListDelete(this.id);

  @override
  List<Object?> get props => [id];
}

class PriceListSearch extends PriceListEvent {
  final String query;

  const PriceListSearch(this.query);

  @override
  List<Object?> get props => [query];
}

class PriceListSavePdf extends PriceListEvent {
  final int priceListId;

  const PriceListSavePdf(this.priceListId);

  @override
  List<Object?> get props => [priceListId];
}

class PriceListPrint extends PriceListEvent {
  final int priceListId;

  const PriceListPrint(this.priceListId);

  @override
  List<Object?> get props => [priceListId];
}

// ==================== States ====================

abstract class PriceListState extends Equatable {
  const PriceListState();

  @override
  List<Object?> get props => [];
}

class PriceListInitial extends PriceListState {}

class PriceListLoading extends PriceListState {}

class PriceListListLoaded extends PriceListState {
  final List<PriceList> priceLists;

  const PriceListListLoaded(this.priceLists);

  @override
  List<Object?> get props => [priceLists];
}

class PriceListDetailsLoaded extends PriceListState {
  final PriceList priceList;
  final List<PriceListItem> items;

  const PriceListDetailsLoaded(this.priceList, this.items);

  @override
  List<Object?> get props => [priceList, items];
}

class PriceListError extends PriceListState {
  final String message;

  const PriceListError(this.message);

  @override
  List<Object?> get props => [message];
}

class PriceListOperationSuccess extends PriceListState {
  final String message;

  const PriceListOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class PriceListPdfSaved extends PriceListState {
  final String filePath;
  final String message;

  const PriceListPdfSaved({required this.filePath, required this.message});

  @override
  List<Object?> get props => [filePath, message];
}

// ==================== BLoC ====================

class PriceListBloc extends Bloc<PriceListEvent, PriceListState> {
  final PriceListRepository _priceListRepository;
  final PdfService _pdfService;
  final SettingsRepository _settingsRepository;

  // Persistent list that survives state transitions
  List<PriceList> _lastKnownPriceLists = [];

  PriceListBloc(this._priceListRepository, this._pdfService, this._settingsRepository) : super(PriceListInitial()) {
    on<PriceListLoadAll>(_onLoadAll);
    on<PriceListRefresh>(_onRefresh);
    on<PriceListLoadDetails>(_onLoadDetails);
    on<PriceListCreate>(_onCreate);
    on<PriceListUpdate>(_onUpdate);
    on<PriceListDelete>(_onDelete);
    on<PriceListSearch>(_onSearch);
    on<PriceListSavePdf>(_onSavePdf);
    on<PriceListPrint>(_onPrint);
  }

  Future<void> _onLoadAll(
    PriceListLoadAll event,
    Emitter<PriceListState> emit,
  ) async {
    if (_lastKnownPriceLists.isNotEmpty && state is PriceListListLoaded) {
      return;
    }
    emit(PriceListLoading());
    try {
      final priceLists = await _priceListRepository.getAllPriceLists();
      _lastKnownPriceLists = priceLists;
      emit(PriceListListLoaded(priceLists));
    } catch (e) {
      if (_lastKnownPriceLists.isNotEmpty) {
        emit(PriceListListLoaded(_lastKnownPriceLists));
      }
      emit(PriceListError(e.toString()));
    }
  }

  Future<void> _onRefresh(
    PriceListRefresh event,
    Emitter<PriceListState> emit,
  ) async {
    try {
      final priceLists = await _priceListRepository.getAllPriceLists();
      _lastKnownPriceLists = priceLists;
      emit(PriceListListLoaded(priceLists));
    } catch (e) {
      if (_lastKnownPriceLists.isNotEmpty) {
        emit(PriceListListLoaded(_lastKnownPriceLists));
      }
      emit(PriceListError(e.toString()));
    }
  }

  Future<void> _onLoadDetails(
    PriceListLoadDetails event,
    Emitter<PriceListState> emit,
  ) async {
    try {
      final priceList = await _priceListRepository.getPriceListById(event.priceListId);
      if (priceList != null) {
        final items = await _priceListRepository.getPriceListItems(event.priceListId);
        emit(PriceListDetailsLoaded(priceList, items));
      } else {
        emit(PriceListError(LocalizationService().get('priceListNotFound')));
      }
    } catch (e) {
      emit(PriceListError(e.toString()));
    }
  }

  Future<void> _onCreate(
    PriceListCreate event,
    Emitter<PriceListState> emit,
  ) async {
    try {
      await _priceListRepository.createPriceList(event.priceList, event.items);

      // Reload the full list
      final priceLists = await _priceListRepository.getAllPriceLists();
      _lastKnownPriceLists = priceLists;

      emit(PriceListListLoaded(List.from(_lastKnownPriceLists)));
      emit(PriceListOperationSuccess(LocalizationService().get('priceListCreated')));
      emit(PriceListListLoaded(List.from(_lastKnownPriceLists)));
    } catch (e) {
      emit(PriceListError(e.toString()));
    }
  }

  Future<void> _onUpdate(
    PriceListUpdate event,
    Emitter<PriceListState> emit,
  ) async {
    try {
      await _priceListRepository.updatePriceList(event.priceList, event.items);

      // Reload the full list
      final priceLists = await _priceListRepository.getAllPriceLists();
      _lastKnownPriceLists = priceLists;

      emit(PriceListListLoaded(List.from(_lastKnownPriceLists)));
      emit(PriceListOperationSuccess(LocalizationService().get('priceListUpdated')));
      emit(PriceListListLoaded(List.from(_lastKnownPriceLists)));
    } catch (e) {
      emit(PriceListError(e.toString()));
    }
  }

  Future<void> _onDelete(
    PriceListDelete event,
    Emitter<PriceListState> emit,
  ) async {
    try {
      await _priceListRepository.deletePriceList(event.id);

      _lastKnownPriceLists =
          _lastKnownPriceLists.where((pl) => pl.id != event.id).toList();

      emit(PriceListListLoaded(List.from(_lastKnownPriceLists)));
      emit(PriceListOperationSuccess(LocalizationService().get('priceListDeleted')));
      emit(PriceListListLoaded(List.from(_lastKnownPriceLists)));
    } catch (e) {
      emit(PriceListError(e.toString()));
    }
  }

  Future<void> _onSearch(
    PriceListSearch event,
    Emitter<PriceListState> emit,
  ) async {
    try {
      if (event.query.isEmpty) {
        final priceLists = await _priceListRepository.getAllPriceLists();
        _lastKnownPriceLists = priceLists;
        emit(PriceListListLoaded(priceLists));
      } else {
        final priceLists = await _priceListRepository.searchPriceLists(event.query);
        emit(PriceListListLoaded(priceLists));
      }
    } catch (e) {
      if (_lastKnownPriceLists.isNotEmpty) {
        emit(PriceListListLoaded(_lastKnownPriceLists));
      }
      emit(PriceListError(e.toString()));
    }
  }

  Future<void> _onSavePdf(
    PriceListSavePdf event,
    Emitter<PriceListState> emit,
  ) async {
    try {
      final priceList = await _priceListRepository.getPriceListById(event.priceListId);
      if (priceList == null) {
        emit(PriceListError(LocalizationService().get('priceListNotFound')));
        return;
      }

      final items = await _priceListRepository.getPriceListItems(event.priceListId);
      final settings = await _settingsRepository.getSettings();

      final filePath = await _pdfService.savePriceListPdf(
        priceList: priceList,
        items: items,
        storeSettings: settings,
      );

      emit(PriceListPdfSaved(
        filePath: filePath,
        message: '${LocalizationService().get('pdfSavedTo')} $filePath',
      ));
    } catch (e) {
      emit(PriceListError('Save PDF failed: ${e.toString()}'));
    }
  }

  Future<void> _onPrint(
    PriceListPrint event,
    Emitter<PriceListState> emit,
  ) async {
    try {
      final priceList = await _priceListRepository.getPriceListById(event.priceListId);
      if (priceList == null) {
        emit(PriceListError(LocalizationService().get('priceListNotFound')));
        return;
      }

      final items = await _priceListRepository.getPriceListItems(event.priceListId);
      final settings = await _settingsRepository.getSettings();

      await _pdfService.printPriceList(
        priceList: priceList,
        items: items,
        storeSettings: settings,
      );

      emit(PriceListOperationSuccess(LocalizationService().get('pdfSaved')));
    } catch (e) {
      emit(PriceListError('Print failed: ${e.toString()}'));
    }
  }
}
