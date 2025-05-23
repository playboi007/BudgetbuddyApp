import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'firebase_service.dart';

class ReportsService {
  final FirebaseService _firebaseService = FirebaseService();

  // Get all categories for the current user
  Future<List<Map<String, dynamic>>> getUserCategories() async {
    final snapshot = await _firebaseService.getUserCategoriesRaw();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {'id': doc.id, ...data};
    }).toList();
  }

  // Get all transactions for a category in a date range
  Future<List<Map<String, dynamic>>> getCategoryTransactions(
      String categoryId, DateTime start, DateTime end) async {
    final snapshot = await _firebaseService.fetchCategoryTransactionsRaw(
        categoryId, start, end);
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {'id': doc.id, ...data};
    }).toList();
  }

  // Get all monthly summaries for the user
  Future<List<Map<String, dynamic>>> getMonthlySummaries() async {
    final snapshot = await _firebaseService.fetchMonthlySummariesRaw();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {'id': doc.id, ...data};
    }).toList();
  }

  // Get all weekly reports for the user
  Future<List<Map<String, dynamic>>> getWeeklyReports(
      {required int limit}) async {
    final snapshot = await _firebaseService.fetchWeeklyReportsRaw();
    List<Map<String, dynamic>> reports = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {'id': doc.id, ...data};
    }).toList();
    if (reports.length > limit) {
      return reports.sublist(0, limit);
    }
    return reports;
  }

  // Example: Get total savings (sum of all category amounts)
  Future<double> getTotalSavings() async {
    List<Map<String, dynamic>> categories = await getUserCategories();
    double total = 0.0;

    for (var cat in categories) {
      double value;
      if (cat['amount'] is double) {
        value = cat['amount'];
      } else {
        value = double.tryParse(cat['amount'].toString()) ?? 0.0;
      }
      total += value;
    }

    return total;
  }

  // Example: Get category breakdown
  Future<List<Map<String, dynamic>>> getCategoryBreakdown() async {
    final categories = await getUserCategories();
    return categories.map((cat) {
      final goalAmount = cat['goalAmount'] ?? 0.0;
      final amount = cat['amount'] ?? 0.0;
      return {
        'categoryId': cat['id'],
        'name': cat['name'] ?? 'Unknown',
        'amount': amount,
        'goalAmount': goalAmount,
        'progress': goalAmount > 0 ? (amount / goalAmount * 100) : 100.0,
      };
    }).toList();
  }

  // Get monthly summary (deposits, withdrawals by month)
  Future<Map<String, Map<String, double>>> getMonthlySummary(
      DateTime startDate, DateTime endDate) async {
    Map<String, Map<String, double>> monthlySummary = {};

    try {
      // Process all transactions directly (client-side processing)
      List<Map<String, dynamic>> transactions =
          await getTransactionsForTimeRange(startDate, endDate);

      // Initialize monthly summaries
      DateTime current = DateTime(startDate.year, startDate.month);
      while (current.isBefore(DateTime(endDate.year, endDate.month + 1))) {
        String monthKey = DateFormat('yyyy-MM').format(current);
        monthlySummary[monthKey] = {
          'deposits': 0.0,
          'withdrawals': 0.0,
          'net': 0.0,
        };
        current = DateTime(current.year, current.month + 1);
      }

      // Populate with transaction data
      for (var transaction in transactions) {
        Timestamp timestamp = transaction['date'];
        DateTime date = timestamp.toDate();
        String monthKey = DateFormat('yyyy-MM').format(date);

        if (!monthlySummary.containsKey(monthKey)) {
          monthlySummary[monthKey] = {
            'deposits': 0.0,
            'withdrawals': 0.0,
            'net': 0.0,
          };
        }

        if (transaction['transactionType'] == 'deposit') {
          monthlySummary[monthKey]!['deposits'] =
              (monthlySummary[monthKey]!['deposits'] ?? 0.0) +
                  transaction['amount'];
          monthlySummary[monthKey]!['net'] =
              (monthlySummary[monthKey]!['net'] ?? 0.0) + transaction['amount'];
        } else if (transaction['transactionType'] == 'withdrawal') {
          monthlySummary[monthKey]!['withdrawals'] =
              (monthlySummary[monthKey]!['withdrawals'] ?? 0.0) +
                  transaction['amount'];
          monthlySummary[monthKey]!['net'] =
              (monthlySummary[monthKey]!['net'] ?? 0.0) - transaction['amount'];
        }
      }

      return monthlySummary;
    } catch (e) {
      if (kDebugMode) {
        print('Error calculating monthly summaries: $e');
      }
      return {};
    }
  }

  /// Get savings trends over time
  Future<List<Map<String, dynamic>>> getSavingsTrends(
      DateTime startDate, DateTime endDate,
      {String? categoryId}) async {
    // Initialize result list with dates and zero balances
    List<Map<String, dynamic>> trendPoints = [];

    // Generate monthly points between start and end dates
    DateTime current = DateTime(startDate.year, startDate.month);
    while (current.isBefore(DateTime(endDate.year, endDate.month + 1))) {
      trendPoints.add({
        'date': current,
        'balance': 0.0,
      });
      current = DateTime(current.year, current.month + 1);
    }

    try {
      if (categoryId == null) {
        // For all categories, calculate from monthly summary
        Map<String, Map<String, double>> monthlySummary =
            await getMonthlySummary(startDate, endDate);

        List<String> sortedMonths = monthlySummary.keys.toList()..sort();

        double runningBalance = 0.0;

        for (int i = 0; i < sortedMonths.length; i++) {
          String monthKey = sortedMonths[i];
          Map<String, double> monthData = monthlySummary[monthKey]!;

          // Add this month's net to the running balance
          runningBalance += monthData['net'] ?? 0.0;

          // Find the corresponding trend point
          for (int j = 0; j < trendPoints.length; j++) {
            DateTime pointDate = trendPoints[j]['date'];
            String pointMonthKey = DateFormat('yyyy-MM').format(pointDate);

            if (pointMonthKey == monthKey) {
              trendPoints[j]['balance'] = runningBalance;
              break;
            }
          }
        }
      } else {
        // For a specific category, calculate from transactions
        double currentBalance = 0;

        // Get all transactions for this category
        QuerySnapshot transactions = await _firebaseService
            .fetchCategoryTransactionsRaw(categoryId, startDate, endDate);

        // Calculate balance at each point in time
        for (var transaction in transactions.docs) {
          Map<String, dynamic> data =
              transaction.data() as Map<String, dynamic>;
          Timestamp timestamp = data['date'];
          DateTime date = timestamp.toDate();

          // Skip transactions before our start date
          if (date.isBefore(startDate)) continue;

          // Update balance based on transaction type
          if (data['transactionType'] == 'deposit') {
            currentBalance += data['amount'] ?? 0.0;
          } else if (data['transactionType'] == 'withdrawal') {
            currentBalance -= data['amount'] ?? 0.0;
          }

          // Update all future points with this balance
          for (int i = 0; i < trendPoints.length; i++) {
            DateTime pointDate = trendPoints[i]['date'];
            if (!pointDate.isBefore(DateTime(date.year, date.month))) {
              trendPoints[i]['balance'] = currentBalance;
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error calculating trends: $e');
      }

      // Fall back to empty trends
      return trendPoints;
    }

    // Format for return
    for (int i = 0; i < trendPoints.length; i++) {
      trendPoints[i]['label'] =
          DateFormat('MMM yyyy').format(trendPoints[i]['date']);
    }

    return trendPoints;
  }

  /// Get weekly reports - client-side implementation
  Future<List<Map<String, dynamic>>> getCalculatedWeeklyReports(
      {int limit = 10}) async {
    try {
      // Calculate weekly reports on the client side
      DateTime now = DateTime.now();
      List<Map<String, dynamic>> reports = [];

      // Generate the last 'limit' weeks
      for (int i = 0; i < limit; i++) {
        DateTime endDate = now.subtract(Duration(days: 7 * i));
        DateTime startDate = endDate.subtract(const Duration(days: 7));

        // Get transactions for this week
        List<Map<String, dynamic>> weekTransactions =
            await getTransactionsForTimeRange(startDate, endDate);

        double deposits = 0.0;
        double withdrawals = 0.0;

        // Calculate totals
        for (var transaction in weekTransactions) {
          if (transaction['transactionType'] == 'deposit') {
            deposits += transaction['amount'];
          } else if (transaction['transactionType'] == 'withdrawal') {
            withdrawals += transaction['amount'];
          }
        }

        reports.add({
          'reportId': 'week-${i + 1}',
          'startDate': Timestamp.fromDate(startDate),
          'endDate': Timestamp.fromDate(endDate),
          'deposits': deposits,
          'withdrawals': withdrawals,
          'net': deposits - withdrawals,
        });
      }

      return reports;
    } catch (e) {
      if (kDebugMode) {
        print('Error calculating weekly reports: $e');
      }
      return [];
    }
  }

  /// Get category growth rate (percentage change over time) - client-side implementation
  Future<Map<String, dynamic>> getCategoryGrowthRate(String categoryId) async {
    try {
      // Get category data
      DocumentSnapshot categoryDoc =
          await _firebaseService.getSingleCategoryRaw(categoryId);
      if (!categoryDoc.exists) {
        throw Exception('Category does not exist');
      }

      Map<String, dynamic> categoryData =
          categoryDoc.data() as Map<String, dynamic>;
      double currentAmount = categoryData['amount'] ?? 0.0;

      // Get transactions for the last 3 months
      DateTime now = DateTime.now();
      DateTime threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);

      // Get all transactions for this category
      QuerySnapshot transactions = await _firebaseService
          .fetchCategoryTransactionsRaw(categoryId, threeMonthsAgo, now);

      if (transactions.docs.isEmpty) {
        return {
          'growthRate': 0.0,
          'monthlyAverage': 0.0,
          'isGrowing': false,
        };
      }

      // Group by month - client-side processing
      Map<String, double> monthlyNet = {};

      for (var doc in transactions.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        Timestamp timestamp = data['date'];
        DateTime date = timestamp.toDate();
        String monthKey = DateFormat('yyyy-MM').format(date);

        double amount = data['amount'] ?? 0.0;
        double change = data['transactionType'] == 'deposit' ? amount : -amount;

        monthlyNet[monthKey] = (monthlyNet[monthKey] ?? 0.0) + change;
      }

      // Calculate average monthly change
      double totalChange =
          monthlyNet.values.fold(0.0, (summ, value) => summ + value);
      double monthlyAverage = totalChange / monthlyNet.length;

      // Calculate growth rate
      double startAmount = currentAmount - totalChange;
      double growthRate =
          startAmount > 0 ? (totalChange / startAmount) * 100 : 0.0;

      return {
        'growthRate': growthRate,
        'monthlyAverage': monthlyAverage,
        'isGrowing': totalChange > 0,
        'monthlyChanges': monthlyNet,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error calculating growth rate: $e');
      }
      return {
        'growthRate': 0.0,
        'monthlyAverage': 0.0,
        'isGrowing': false,
      };
    }
  }

  /// Get transactions for a specific time range across all categories
  Future<List<Map<String, dynamic>>> getTransactionsForTimeRange(
      DateTime startDate, DateTime endDate) async {
    List<Map<String, dynamic>> allTransactions = [];

    final categories = await getUserCategories();
    for (var category in categories) {
      final transactions =
          await getCategoryTransactions(category['id'], startDate, endDate);
      for (var transaction in transactions) {
        allTransactions.add({
          'transactionId': transaction['id'],
          'categoryId': category['id'],
          'categoryName': category['name'] ?? 'Unknown',
          'amount': transaction['amount'] ?? 0.0,
          'transactionType': transaction['transactionType'] ?? '',
          'date': transaction['date'],
          'note': transaction['note'] ?? '',
        });
      }
    }
    return allTransactions;
  }

  /// Create or update monthly summary document for a specific month
  Future<void> updateMonthlySummary(
      DateTime date, double amount, String transactionType) async {
    try {
      // Format the month key (YYYY-MM)
      String monthKey = DateFormat('yyyy-MM').format(date);

      // Reference to the monthly summary document
      DocumentReference monthlySummaryRef =
          _firebaseService.getMonthlySummaryDocRef(monthKey);

      // Get the current document or create if it doesn't exist
      DocumentSnapshot monthlySummaryDoc = await monthlySummaryRef.get();

      if (monthlySummaryDoc.exists) {
        // Update existing document
        Map<String, dynamic> data =
            monthlySummaryDoc.data() as Map<String, dynamic>;

        if (transactionType == 'deposit') {
          double deposits = (data['deposits'] ?? 0.0) + amount;
          double net = (data['net'] ?? 0.0) + amount;
          await monthlySummaryRef.update({
            'deposits': deposits,
            'net': net,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        } else if (transactionType == 'withdrawal') {
          double withdrawals = (data['withdrawals'] ?? 0.0) + amount;
          double net = (data['net'] ?? 0.0) - amount;
          await monthlySummaryRef.update({
            'withdrawals': withdrawals,
            'net': net,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }
      } else {
        // Create new document
        Map<String, dynamic> newData = {
          'month': monthKey,
          'startDate': Timestamp.fromDate(DateTime(date.year, date.month, 1)),
          'endDate': Timestamp.fromDate(DateTime(date.year, date.month + 1, 0)),
          'deposits': transactionType == 'deposit' ? amount : 0.0,
          'withdrawals': transactionType == 'withdrawal' ? amount : 0.0,
          'net': transactionType == 'deposit' ? amount : -amount,
          'createdAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        };

        await monthlySummaryRef.set(newData);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating monthly summary: $e');
      }
      rethrow;
    }
  }

  /// Reverse a transaction's effect on monthly summary
  Future<void> reverseMonthlySummaryTransaction(
      DateTime date, double amount, String transactionType) async {
    try {
      // Format the month key (YYYY-MM)
      String monthKey = DateFormat('yyyy-MM').format(date);

      // Reference to the monthly summary document
      DocumentReference monthlySummaryRef =
          _firebaseService.getMonthlySummaryDocRef(monthKey);

      // Get the current document
      DocumentSnapshot monthlySummaryDoc = await monthlySummaryRef.get();

      if (monthlySummaryDoc.exists) {
        Map<String, dynamic> data =
            monthlySummaryDoc.data() as Map<String, dynamic>;

        if (transactionType == 'deposit') {
          // Reverse a deposit by reducing the deposits and net
          double deposits = (data['deposits'] ?? 0.0) - amount;
          double net = (data['net'] ?? 0.0) - amount;
          await monthlySummaryRef.update({
            'deposits': deposits,
            'net': net,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        } else if (transactionType == 'withdrawal') {
          // Reverse a withdrawal by reducing the withdrawals and increasing net
          double withdrawals = (data['withdrawals'] ?? 0.0) - amount;
          double net = (data['net'] ?? 0.0) + amount;
          await monthlySummaryRef.update({
            'withdrawals': withdrawals,
            'net': net,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error reversing monthly summary transaction: $e');
      }
      rethrow;
    }
  }

  /// Update weekly report for a specific week
  Future<void> updateWeeklyReport(
      DateTime transactionDate, double amount, String transactionType) async {
    try {
      // Calculate the start and end of the week containing the transaction
      int weekday = transactionDate.weekday;
      DateTime startOfWeek =
          transactionDate.subtract(Duration(days: weekday - 1));
      startOfWeek = DateTime(startOfWeek.year, startOfWeek.month,
          startOfWeek.day); // Normalize to start of day
      DateTime endOfWeek = startOfWeek.add(const Duration(days: 6));
      endOfWeek = DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day, 23,
          59, 59); // End of day

      // Create a unique ID for the week
      String weekId =
          'week-${startOfWeek.year}-${startOfWeek.month}-${startOfWeek.day}';

      // Reference to the weekly report document
      DocumentReference weeklyReportRef =
          _firebaseService.getWeeklyReportDocRef(weekId);

      // Get the current document or create if it doesn't exist
      DocumentSnapshot weeklyReportDoc = await weeklyReportRef.get();

      if (weeklyReportDoc.exists) {
        // Update existing document
        Map<String, dynamic> data =
            weeklyReportDoc.data() as Map<String, dynamic>;

        if (transactionType == 'deposit') {
          double deposits = (data['deposits'] ?? 0.0) + amount;
          double net = (data['net'] ?? 0.0) + amount;
          await weeklyReportRef.update({
            'deposits': deposits,
            'net': net,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        } else if (transactionType == 'withdrawal') {
          double withdrawals = (data['withdrawals'] ?? 0.0) + amount;
          double net = (data['net'] ?? 0.0) - amount;
          await weeklyReportRef.update({
            'withdrawals': withdrawals,
            'net': net,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }
      } else {
        // Create new document
        Map<String, dynamic> newData = {
          'reportId': weekId,
          'startDate': Timestamp.fromDate(startOfWeek),
          'endDate': Timestamp.fromDate(endOfWeek),
          'deposits': transactionType == 'deposit' ? amount : 0.0,
          'withdrawals': transactionType == 'withdrawal' ? amount : 0.0,
          'net': transactionType == 'deposit' ? amount : -amount,
          'createdAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        };

        await weeklyReportRef.set(newData);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating weekly report: $e');
      }
      rethrow;
    }
  }

  /// Reverse a transaction's effect on weekly report
  Future<void> reverseWeeklyReportTransaction(
      DateTime transactionDate, double amount, String transactionType) async {
    try {
      // Calculate the start and end of the week containing the transaction
      int weekday = transactionDate.weekday;
      DateTime startOfWeek =
          transactionDate.subtract(Duration(days: weekday - 1));
      startOfWeek = DateTime(startOfWeek.year, startOfWeek.month,
          startOfWeek.day); // Normalize to start of day

      // Create a unique ID for the week
      String weekId =
          'week-${startOfWeek.year}-${startOfWeek.month}-${startOfWeek.day}';

      // Reference to the weekly report document
      DocumentReference weeklyReportRef =
          _firebaseService.getWeeklyReportDocRef(weekId);

      // Get the current document
      DocumentSnapshot weeklyReportDoc = await weeklyReportRef.get();

      if (weeklyReportDoc.exists) {
        Map<String, dynamic> data =
            weeklyReportDoc.data() as Map<String, dynamic>;

        if (transactionType == 'deposit') {
          // Reverse a deposit by reducing the deposits and net
          double deposits = (data['deposits'] ?? 0.0) - amount;
          double net = (data['net'] ?? 0.0) - amount;
          await weeklyReportRef.update({
            'deposits': deposits,
            'net': net,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        } else if (transactionType == 'withdrawal') {
          // Reverse a withdrawal by reducing the withdrawals and increasing net
          double withdrawals = (data['withdrawals'] ?? 0.0) - amount;
          double net = (data['net'] ?? 0.0) + amount;
          await weeklyReportRef.update({
            'withdrawals': withdrawals,
            'net': net,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error reversing weekly report transaction: $e');
      }
      rethrow;
    }
  }

  /// Initialize collections for a new user
  Future<void> initializeCollections() async {
    try {
      // Create initial monthly summary for current month
      DateTime now = DateTime.now();
      String currentMonthKey = DateFormat('yyyy-MM').format(now);
      DocumentReference currentMonthRef =
          _firebaseService.getMonthlySummaryDocRef(currentMonthKey);

      DocumentSnapshot currentMonthDoc = await currentMonthRef.get();
      if (!currentMonthDoc.exists) {
        await currentMonthRef.set({
          'month': currentMonthKey,
          'startDate': Timestamp.fromDate(DateTime(now.year, now.month, 1)),
          'endDate': Timestamp.fromDate(DateTime(now.year, now.month + 1, 0)),
          'deposits': 0.0,
          'withdrawals': 0.0,
          'net': 0.0,
          'createdAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }

      // Create initial weekly report for current week
      int weekday = now.weekday;
      DateTime startOfWeek = now.subtract(Duration(days: weekday - 1));
      startOfWeek =
          DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      DateTime endOfWeek = startOfWeek.add(const Duration(days: 6));
      endOfWeek =
          DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day, 23, 59, 59);

      String weekId =
          'week-${startOfWeek.year}-${startOfWeek.month}-${startOfWeek.day}';
      DocumentReference weeklyReportRef =
          _firebaseService.getWeeklyReportDocRef(weekId);

      DocumentSnapshot weeklyReportDoc = await weeklyReportRef.get();
      if (!weeklyReportDoc.exists) {
        await weeklyReportRef.set({
          'reportId': weekId,
          'startDate': Timestamp.fromDate(startOfWeek),
          'endDate': Timestamp.fromDate(endOfWeek),
          'deposits': 0.0,
          'withdrawals': 0.0,
          'net': 0.0,
          'createdAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing collections: $e');
      }
      rethrow;
    }
  }
}
