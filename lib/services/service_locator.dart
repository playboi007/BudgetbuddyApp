import 'package:budgetbuddy_app/repositories/auth_repo.dart';
import 'package:budgetbuddy_app/services/category_provider.dart';
import 'package:budgetbuddy_app/services/notification_provider.dart';
import 'package:budgetbuddy_app/services/transaction_provider.dart';
import 'package:budgetbuddy_app/states/analytics_provider.dart';
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

void setupServiceLocator() {
  // Repositories
  getIt.registerLazySingleton(() => AuthRepo());
  getIt.registerLazySingleton(() => CategoryProvider());
  getIt.registerLazySingleton(() => TransactionProvider());
  getIt.registerLazySingleton(() => NotificationProvider());
  getIt.registerLazySingleton(() => AnalyticsProvider());
}
