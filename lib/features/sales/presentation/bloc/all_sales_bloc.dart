import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/sale_record.dart';
import '../../domain/repositories/sales_repository.dart';

// ─── Events ───

abstract class AllSalesEvent extends Equatable {
  const AllSalesEvent();

  @override
  List<Object?> get props => [];
}

class AllSalesLoad extends AllSalesEvent {}

class AllSalesSearch extends AllSalesEvent {
  final String query;

  const AllSalesSearch(this.query);

  @override
  List<Object?> get props => [query];
}

class AllSalesLoadMore extends AllSalesEvent {}

class AllSalesRefresh extends AllSalesEvent {}

// ─── States ───

abstract class AllSalesState extends Equatable {
  const AllSalesState();

  @override
  List<Object?> get props => [];
}

class AllSalesInitial extends AllSalesState {}

class AllSalesLoading extends AllSalesState {}

class AllSalesLoaded extends AllSalesState {
  final List<SaleRecord> records;
  final int totalCount;
  final bool hasMore;
  final bool isLoadingMore;
  final String searchQuery;

  const AllSalesLoaded({
    required this.records,
    required this.totalCount,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.searchQuery = '',
  });

  AllSalesLoaded copyWith({
    List<SaleRecord>? records,
    int? totalCount,
    bool? hasMore,
    bool? isLoadingMore,
    String? searchQuery,
  }) {
    return AllSalesLoaded(
      records: records ?? this.records,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [records, totalCount, hasMore, isLoadingMore, searchQuery];
}

class AllSalesError extends AllSalesState {
  final String message;

  const AllSalesError(this.message);

  @override
  List<Object?> get props => [message];
}

// ─── BLoC ───

class AllSalesBloc extends Bloc<AllSalesEvent, AllSalesState> {
  final SalesRepository _salesRepository;
  static const int _pageSize = 50;

  AllSalesBloc(this._salesRepository) : super(AllSalesInitial()) {
    on<AllSalesLoad>(_onLoad);
    on<AllSalesSearch>(_onSearch);
    on<AllSalesLoadMore>(_onLoadMore);
    on<AllSalesRefresh>(_onRefresh);
  }

  Future<void> _onLoad(AllSalesLoad event, Emitter<AllSalesState> emit) async {
    emit(AllSalesLoading());
    try {
      final records = await _salesRepository.getAllSaleRecords(limit: _pageSize, offset: 0);
      final count = await _salesRepository.getSaleRecordsCount();
      emit(AllSalesLoaded(
        records: records,
        totalCount: count,
        hasMore: records.length < count,
      ));
    } catch (e) {
      emit(AllSalesError(e.toString()));
    }
  }

  Future<void> _onSearch(AllSalesSearch event, Emitter<AllSalesState> emit) async {
    emit(AllSalesLoading());
    try {
      final query = event.query.trim();
      final records = await _salesRepository.getAllSaleRecords(
        searchQuery: query.isEmpty ? null : query,
        limit: _pageSize,
        offset: 0,
      );
      final count = await _salesRepository.getSaleRecordsCount(
        searchQuery: query.isEmpty ? null : query,
      );
      emit(AllSalesLoaded(
        records: records,
        totalCount: count,
        hasMore: records.length < count,
        searchQuery: query,
      ));
    } catch (e) {
      emit(AllSalesError(e.toString()));
    }
  }

  Future<void> _onLoadMore(AllSalesLoadMore event, Emitter<AllSalesState> emit) async {
    final currentState = state;
    if (currentState is! AllSalesLoaded || !currentState.hasMore || currentState.isLoadingMore) return;

    emit(currentState.copyWith(isLoadingMore: true));
    try {
      final query = currentState.searchQuery;
      final moreRecords = await _salesRepository.getAllSaleRecords(
        searchQuery: query.isEmpty ? null : query,
        limit: _pageSize,
        offset: currentState.records.length,
      );
      final allRecords = [...currentState.records, ...moreRecords];
      emit(currentState.copyWith(
        records: allRecords,
        hasMore: allRecords.length < currentState.totalCount,
        isLoadingMore: false,
      ));
    } catch (e) {
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onRefresh(AllSalesRefresh event, Emitter<AllSalesState> emit) async {
    final currentQuery = state is AllSalesLoaded ? (state as AllSalesLoaded).searchQuery : '';
    emit(AllSalesLoading());
    try {
      final query = currentQuery.trim();
      final records = await _salesRepository.getAllSaleRecords(
        searchQuery: query.isEmpty ? null : query,
        limit: _pageSize,
        offset: 0,
      );
      final count = await _salesRepository.getSaleRecordsCount(
        searchQuery: query.isEmpty ? null : query,
      );
      emit(AllSalesLoaded(
        records: records,
        totalCount: count,
        hasMore: records.length < count,
        searchQuery: query,
      ));
    } catch (e) {
      emit(AllSalesError(e.toString()));
    }
  }
}
