import 'package:get_it/get_it.dart';

import '../database/database_helper.dart';
import '../services/pdf_service.dart';
import '../services/security_service.dart';
import '../services/audit_logger_service.dart';
import '../services/error_handler_service.dart';
import '../services/validation_service.dart';
import '../services/smart_search_service.dart';
import '../services/chatbot_service.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/products/data/repositories/product_repository_impl.dart';
import '../../features/products/domain/repositories/product_repository.dart';
import '../../features/products/presentation/bloc/product_bloc.dart';
import '../../features/sales/data/repositories/sales_repository_impl.dart';
import '../../features/sales/domain/repositories/sales_repository.dart';
import '../../features/sales/presentation/bloc/sales_bloc.dart';
import '../../features/sales/presentation/bloc/all_sales_bloc.dart';
import '../../features/customers/data/repositories/customer_repository_impl.dart';
import '../../features/customers/domain/repositories/customer_repository.dart';
import '../../features/customers/presentation/bloc/customer_bloc.dart';
import '../../features/invoices/data/repositories/invoice_repository_impl.dart';
import '../../features/invoices/domain/repositories/invoice_repository.dart';
import '../../features/invoices/presentation/bloc/invoice_bloc.dart';
import '../../features/reports/data/repositories/report_repository_impl.dart';
import '../../features/reports/domain/repositories/report_repository.dart';
import '../../features/reports/presentation/bloc/report_bloc.dart';
import '../../features/expenses/data/repositories/expense_repository_impl.dart';
import '../../features/expenses/domain/repositories/expense_repository.dart';
import '../../features/expenses/presentation/bloc/expense_bloc.dart';
import '../../features/settings/data/repositories/settings_repository_impl.dart';
import '../../features/settings/domain/repositories/settings_repository.dart';
import '../../features/backup/data/repositories/backup_repository_impl.dart';
import '../../features/backup/domain/repositories/backup_repository.dart';
import '../../features/price_lists/data/repositories/price_list_repository_impl.dart';
import '../../features/price_lists/domain/repositories/price_list_repository.dart';
import '../../features/price_lists/presentation/bloc/price_list_bloc.dart';
import '../../features/suppliers/data/repositories/supplier_repository_impl.dart';
import '../../features/suppliers/domain/repositories/supplier_repository.dart';
import '../../features/suppliers/presentation/bloc/supplier_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Database
  sl.registerLazySingleton(() => DatabaseHelper());

  // Core Services - Security, Audit, Error Handling, Validation
  sl.registerLazySingleton(() => SecurityService());
  sl.registerLazySingleton(() => AuditLoggerService());
  sl.registerLazySingleton(() => ErrorHandlerService());
  sl.registerLazySingleton(() => ValidationService());
  sl.registerLazySingleton(() => PdfService());

  // AI Services - Smart Search and Chatbot
  sl.registerLazySingleton(() => SmartSearchService());
  sl.registerLazySingleton(() => ChatbotService());

  // Initialize audit logger with database
  final auditLogger = sl<AuditLoggerService>();
  auditLogger.initialize(sl<DatabaseHelper>());

  // Repositories
  sl.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(sl()));
  sl.registerLazySingleton<ProductRepository>(() => ProductRepositoryImpl(sl()));
  sl.registerLazySingleton<SalesRepository>(() => SalesRepositoryImpl(sl()));
  sl.registerLazySingleton<CustomerRepository>(() => CustomerRepositoryImpl(sl()));
  sl.registerLazySingleton<InvoiceRepository>(() => InvoiceRepositoryImpl(sl()));
  sl.registerLazySingleton<ReportRepository>(() => ReportRepositoryImpl(sl()));
  sl.registerLazySingleton<ExpenseRepository>(() => ExpenseRepositoryImpl(sl()));
  sl.registerLazySingleton<SettingsRepository>(() => SettingsRepositoryImpl(sl()));
  sl.registerLazySingleton<BackupRepository>(() => BackupRepositoryImpl(sl()));
  sl.registerLazySingleton<PriceListRepository>(() => PriceListRepositoryImpl(sl()));
  sl.registerLazySingleton<SupplierRepository>(() => SupplierRepositoryImpl(sl()));

  // BLoCs - Using LazySingleton for all data blocs to cache data and enable instant navigation
  sl.registerFactory(() => AuthBloc(sl()));
  sl.registerLazySingleton(() => ProductBloc(sl()));
  sl.registerLazySingleton(() => SalesBloc(sl(), sl(), sl()));
  sl.registerLazySingleton(() => CustomerBloc(sl()));
  sl.registerLazySingleton(() => InvoiceBloc(sl(), sl(), sl()));
  sl.registerLazySingleton(() => ReportBloc(sl()));
  sl.registerLazySingleton(() => ExpenseBloc(sl()));
  sl.registerLazySingleton(() => PriceListBloc(sl(), sl(), sl()));
  sl.registerLazySingleton(() => SupplierBloc(sl()));
  sl.registerLazySingleton(() => AllSalesBloc(sl()));
}
