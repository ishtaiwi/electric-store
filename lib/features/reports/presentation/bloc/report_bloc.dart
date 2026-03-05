import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/repositories/report_repository.dart';

// Events
abstract class ReportEvent extends Equatable {
  const ReportEvent();

  @override
  List<Object?> get props => [];
}

class ReportLoadDashboard extends ReportEvent {}

class ReportLoadDailySales extends ReportEvent {
  final DateTime date;

  const ReportLoadDailySales(this.date);

  @override
  List<Object?> get props => [date];
}

class ReportLoadProfit extends ReportEvent {
  final DateTime start;
  final DateTime end;

  const ReportLoadProfit({required this.start, required this.end});

  @override
  List<Object?> get props => [start, end];
}

class ReportLoadInventory extends ReportEvent {}

class ReportLoadCustomerDebts extends ReportEvent {}

class ReportLoadBestSelling extends ReportEvent {
  final int limit;

  const ReportLoadBestSelling({this.limit = 10});

  @override
  List<Object?> get props => [limit];
}

class ReportLoadSalesByCategory extends ReportEvent {
  final DateTime start;
  final DateTime end;

  const ReportLoadSalesByCategory({required this.start, required this.end});

  @override
  List<Object?> get props => [start, end];
}

class ReportLoadMonthlySales extends ReportEvent {
  final int year;

  const ReportLoadMonthlySales(this.year);

  @override
  List<Object?> get props => [year];
}

class ReportLoadAll extends ReportEvent {
  final DateTime startDate;
  final DateTime endDate;

  const ReportLoadAll({required this.startDate, required this.endDate});

  @override
  List<Object?> get props => [startDate, endDate];
}

// States
abstract class ReportState extends Equatable {
  const ReportState();

  @override
  List<Object?> get props => [];
}

class ReportInitial extends ReportState {}

class ReportLoading extends ReportState {}

class ReportDashboardLoaded extends ReportState {
  final Map<String, dynamic> stats;

  const ReportDashboardLoaded(this.stats);

  @override
  List<Object?> get props => [stats];
}

class ReportDailySalesLoaded extends ReportState {
  final List<Map<String, dynamic>> sales;
  final DateTime date;

  const ReportDailySalesLoaded({required this.sales, required this.date});

  @override
  List<Object?> get props => [sales, date];
}

class ReportProfitLoaded extends ReportState {
  final Map<String, dynamic> profitData;

  const ReportProfitLoaded(this.profitData);

  @override
  List<Object?> get props => [profitData];
}

class ReportInventoryLoaded extends ReportState {
  final List<Map<String, dynamic>> inventory;

  const ReportInventoryLoaded(this.inventory);

  @override
  List<Object?> get props => [inventory];
}

class ReportCustomerDebtsLoaded extends ReportState {
  final List<Map<String, dynamic>> debts;

  const ReportCustomerDebtsLoaded(this.debts);

  @override
  List<Object?> get props => [debts];
}

class ReportBestSellingLoaded extends ReportState {
  final List<Map<String, dynamic>> products;

  const ReportBestSellingLoaded(this.products);

  @override
  List<Object?> get props => [products];
}

class ReportSalesByCategoryLoaded extends ReportState {
  final List<Map<String, dynamic>> categoryData;

  const ReportSalesByCategoryLoaded(this.categoryData);

  @override
  List<Object?> get props => [categoryData];
}

class ReportMonthlySalesLoaded extends ReportState {
  final List<Map<String, dynamic>> monthlyData;
  final int year;

  const ReportMonthlySalesLoaded({required this.monthlyData, required this.year});

  @override
  List<Object?> get props => [monthlyData, year];
}

class ReportError extends ReportState {
  final String message;

  const ReportError(this.message);

  @override
  List<Object?> get props => [message];
}

class ReportLoaded extends ReportState {
  final List<Map<String, dynamic>> dailySales;
  final List<Map<String, dynamic>> monthlyTrend;
  final Map<String, dynamic> profitReport;
  final List<Map<String, dynamic>> inventoryReport;
  final List<Map<String, dynamic>> categorySales;
  final List<Map<String, dynamic>> customerDebts;
  final List<Map<String, dynamic>> bestSelling;

  const ReportLoaded({
    required this.dailySales,
    required this.monthlyTrend,
    required this.profitReport,
    required this.inventoryReport,
    required this.categorySales,
    required this.customerDebts,
    required this.bestSelling,
  });

  @override
  List<Object?> get props => [
        dailySales,
        monthlyTrend,
        profitReport,
        inventoryReport,
        categorySales,
        customerDebts,
        bestSelling,
      ];
}

// BLoC
class ReportBloc extends Bloc<ReportEvent, ReportState> {
  final ReportRepository _reportRepository;
  
  // Cache dashboard stats and track when they were last loaded
  Map<String, dynamic>? _cachedDashboardStats;
  DateTime? _lastDashboardLoad;
  static const _cacheValidDuration = Duration(seconds: 30);

  ReportBloc(this._reportRepository) : super(ReportInitial()) {
    on<ReportLoadDashboard>(_onLoadDashboard);
    on<ReportLoadDailySales>(_onLoadDailySales);
    on<ReportLoadProfit>(_onLoadProfit);
    on<ReportLoadInventory>(_onLoadInventory);
    on<ReportLoadCustomerDebts>(_onLoadCustomerDebts);
    on<ReportLoadBestSelling>(_onLoadBestSelling);
    on<ReportLoadSalesByCategory>(_onLoadSalesByCategory);
    on<ReportLoadMonthlySales>(_onLoadMonthlySales);
    on<ReportLoadAll>(_onLoadAll);
  }
  
  /// Invalidate dashboard cache (call after sales, invoices, etc. change)
  void invalidateDashboardCache() {
    _cachedDashboardStats = null;
    _lastDashboardLoad = null;
  }

  Future<void> _onLoadDashboard(
    ReportLoadDashboard event,
    Emitter<ReportState> emit,
  ) async {
    // Use cached data if available and still valid
    if (_cachedDashboardStats != null && 
        _lastDashboardLoad != null &&
        DateTime.now().difference(_lastDashboardLoad!) < _cacheValidDuration) {
      emit(ReportDashboardLoaded(_cachedDashboardStats!));
      return;
    }
    
    // Show loading only if we don't have cached data
    if (_cachedDashboardStats == null) {
      emit(ReportLoading());
    }
    
    try {
      final stats = await _reportRepository.getDashboardStats();
      _cachedDashboardStats = stats;
      _lastDashboardLoad = DateTime.now();
      emit(ReportDashboardLoaded(stats));
    } catch (e) {
      emit(ReportError(e.toString()));
    }
  }

  Future<void> _onLoadDailySales(
    ReportLoadDailySales event,
    Emitter<ReportState> emit,
  ) async {
    emit(ReportLoading());
    try {
      final sales = await _reportRepository.getDailySalesReport(event.date);
      emit(ReportDailySalesLoaded(sales: sales, date: event.date));
    } catch (e) {
      emit(ReportError(e.toString()));
    }
  }

  Future<void> _onLoadProfit(
    ReportLoadProfit event,
    Emitter<ReportState> emit,
  ) async {
    emit(ReportLoading());
    try {
      final profitData = await _reportRepository.getProfitReport(event.start, event.end);
      emit(ReportProfitLoaded(profitData));
    } catch (e) {
      emit(ReportError(e.toString()));
    }
  }

  Future<void> _onLoadInventory(
    ReportLoadInventory event,
    Emitter<ReportState> emit,
  ) async {
    emit(ReportLoading());
    try {
      final inventory = await _reportRepository.getInventoryReport();
      emit(ReportInventoryLoaded(inventory));
    } catch (e) {
      emit(ReportError(e.toString()));
    }
  }

  Future<void> _onLoadCustomerDebts(
    ReportLoadCustomerDebts event,
    Emitter<ReportState> emit,
  ) async {
    emit(ReportLoading());
    try {
      final debts = await _reportRepository.getCustomerDebtsReport();
      emit(ReportCustomerDebtsLoaded(debts));
    } catch (e) {
      emit(ReportError(e.toString()));
    }
  }

  Future<void> _onLoadBestSelling(
    ReportLoadBestSelling event,
    Emitter<ReportState> emit,
  ) async {
    emit(ReportLoading());
    try {
      final products = await _reportRepository.getBestSellingProducts(event.limit);
      emit(ReportBestSellingLoaded(products));
    } catch (e) {
      emit(ReportError(e.toString()));
    }
  }

  Future<void> _onLoadSalesByCategory(
    ReportLoadSalesByCategory event,
    Emitter<ReportState> emit,
  ) async {
    emit(ReportLoading());
    try {
      final categoryData = await _reportRepository.getSalesByCategory(event.start, event.end);
      emit(ReportSalesByCategoryLoaded(categoryData));
    } catch (e) {
      emit(ReportError(e.toString()));
    }
  }

  Future<void> _onLoadMonthlySales(
    ReportLoadMonthlySales event,
    Emitter<ReportState> emit,
  ) async {
    emit(ReportLoading());
    try {
      final monthlyData = await _reportRepository.getMonthlySalesTrend(event.year);
      emit(ReportMonthlySalesLoaded(monthlyData: monthlyData, year: event.year));
    } catch (e) {
      emit(ReportError(e.toString()));
    }
  }

  Future<void> _onLoadAll(
    ReportLoadAll event,
    Emitter<ReportState> emit,
  ) async {
    emit(ReportLoading());
    try {
      // Run all independent queries in parallel for better performance
      final results = await Future.wait([
        _reportRepository.getDailySalesReport(event.startDate),
        _reportRepository.getMonthlySalesTrend(event.startDate.year),
        _reportRepository.getProfitReport(event.startDate, event.endDate),
        _reportRepository.getInventoryReport(),
        _reportRepository.getSalesByCategory(event.startDate, event.endDate),
        _reportRepository.getCustomerDebtsReport(),
        _reportRepository.getBestSellingProducts(10),
      ]);

      emit(ReportLoaded(
        dailySales: results[0] as List<Map<String, dynamic>>,
        monthlyTrend: results[1] as List<Map<String, dynamic>>,
        profitReport: results[2] as Map<String, dynamic>,
        inventoryReport: results[3] as List<Map<String, dynamic>>,
        categorySales: results[4] as List<Map<String, dynamic>>,
        customerDebts: results[5] as List<Map<String, dynamic>>,
        bestSelling: results[6] as List<Map<String, dynamic>>,
      ));
    } catch (e) {
      emit(ReportError(e.toString()));
    }
  }
}
