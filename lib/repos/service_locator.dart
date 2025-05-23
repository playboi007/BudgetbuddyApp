import 'package:budgetbuddy_app/repos/auth_repo.dart';
import 'package:budgetbuddy_app/provider/category_provider.dart';
import 'package:budgetbuddy_app/provider/notification_provider.dart';
import 'package:budgetbuddy_app/provider/transaction_provider.dart';
import 'package:budgetbuddy_app/states/analytics_provider.dart';
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

void setupServiceLocator() {
  // Repositories with lazy loading
  getIt.registerLazySingleton(() => AuthRepo());
  getIt.registerLazySingleton(() => CategoryProvider());
  getIt.registerLazySingleton(() => TransactionProvider());
  getIt.registerLazySingleton(() => NotificationProvider());
  getIt.registerLazySingleton(() => AnalyticsProvider());

  getIt.registerSingleton<CategoryProvider>(CategoryProvider());
}
