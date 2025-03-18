import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class ReportsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Collection references
  CollectionReference get _usersCollection => _firestore.collection('users');

  // Get user document reference
  DocumentReference _getUserDoc() {
    if (currentUserId == null) throw Exception('User not authenticated');
    return _usersCollection.doc(currentUserId);
  }

  // Get categories collection for current user
  CollectionReference _getCategoriesCollection() {
    return _getUserDoc().collection('categories');
  }

  // Get monthly summaries collection
  CollectionReference _getMonthlySummariesCollection() {
    return _getUserDoc().collection('monthlySummaries');
  }

  // Get weekly reports collection
  CollectionReference _getWeeklyReportsCollection() {
    return _getUserDoc().collection('weeklyReports');
  }

  // Get all categories for the current user
  Future<List<DocumentSnapshot>> getUserCategories() async {
    if (currentUserId == null) throw Exception('User not authenticated');

    QuerySnapshot snapshot = await _getCategoriesCollection().get();
    return snapshot.docs;
  }

  // Total savings overview across all categories
  Future<double> getTotalSavings() async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      // First try to get the pre-calculated total from user document
      DocumentSnapshot userDoc = await _getUserDoc().get();
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        if (userData.containsKey('totalSavings')) {
          return userData['totalSavings'] ?? 0.0;
        }
      }

      // Fall back to calculating from categories if not available
      List<DocumentSnapshot> categories = await getUserCategories();
      double totalSavings = 0;

      for (var category in categories) {
        Map<String, dynamic> data = category.data() as Map<String, dynamic>;
        totalSavings += data['amount'] ?? 0.0;
      }

      return totalSavings;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting total savings: $e');
      }
      // Fall back to calculating from categories
      List<DocumentSnapshot> categories = await getUserCategories();
      double totalSavings = 0;

      for (var category in categories) {
        Map<String, dynamic> data = category.data() as Map<String, dynamic>;
        totalSavings += data['amount'] ?? 0.0;
      }

      return totalSavings;
    }

    //return allTransactions;
  }

  // Get monthly summary (deposits, withdrawals by month)
  Future<Map<String, Map<String, double>>> getMonthlySummary(
      DateTime startDate, DateTime endDate) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    Map<String, Map<String, double>> monthlySummary = {};

    // First check if we have pre-calculated summaries
    try {
      List<String> monthKeys = [];

      // Generate all month keys between start and end date
      DateTime current = DateTime(startDate.year, startDate.month);
      while (current.isBefore(DateTime(endDate.year, endDate.month + 1))) {
        String monthKey = DateFormat('yyyy-MM').format(current);
        monthKeys.add(monthKey);

        // Initialize empty summary for this month
        monthlySummary[monthKey] = {
          'deposits': 0.0,
          'withdrawals': 0.0,
          'net': 0.0,
        };

        current = DateTime(current.year, current.month + 1);
      }

      // Try to get pre-calculated summaries
      for (String monthKey in monthKeys) {
        DocumentSnapshot summaryDoc =
            await _getMonthlySummariesCollection().doc(monthKey).get();

        if (summaryDoc.exists) {
          Map<String, dynamic> data = summaryDoc.data() as Map<String, dynamic>;
          monthlySummary[monthKey] = {
            'deposits': data['deposits'] ?? 0.0,
            'withdrawals': data['withdrawals'] ?? 0.0,
            'net': data['net'] ?? 0.0,
          };
        }
      }

      // For months without pre-calculated data, calculate from transactions
      List<Map<String, dynamic>> transactions =
          await getTransactionsForTimeRange(startDate, endDate);

      for (var transaction in transactions) {
        Timestamp timestamp = transaction['date'];
        DateTime date = timestamp.toDate();
        String monthKey = DateFormat('yyyy-MM').format(date);

        // Skip if we already have pre-calculated data for this month
        if (!monthlySummary.containsKey(monthKey) ||
            (monthlySummary[monthKey]!['deposits'] == 0 &&
                monthlySummary[monthKey]!['withdrawals'] == 0)) {
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
                (monthlySummary[monthKey]!['net'] ?? 0.0) +
                    transaction['amount'];
          } else if (transaction['transactionType'] == 'withdrawal') {
            monthlySummary[monthKey]!['withdrawals'] =
                (monthlySummary[monthKey]!['withdrawals'] ?? 0.0) +
                    transaction['amount'];
            monthlySummary[monthKey]!['net'] =
                (monthlySummary[monthKey]!['net'] ?? 0.0) -
                    transaction['amount'];
          }
        }
      }

      return monthlySummary;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting pre-calculated monthly summaries: $e');
      }
      // Fall back to calculating everything from transactions
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
    }
  }

  // Get savings trends over time
  Future<List<Map<String, dynamic>>> getSavingsTrends(
      DateTime startDate, DateTime endDate,
      {String? categoryId}) async {
    if (currentUserId == null) throw Exception('User not authenticated');

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
      // If requesting trends for all categories, check if we have pre-calculated monthly summaries
      if (categoryId == null) {
        // Get monthly summaries
        Map<String, Map<String, double>> monthlySummary =
            await getMonthlySummary(startDate, endDate);

        // Sort month keys
        List<String> sortedMonths = monthlySummary.keys.toList()..sort();

        // Calculate running balance
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
        // For a specific category, we need to calculate from transactions
        double currentBalance = 0;

        // Get all transactions for this category
        QuerySnapshot transactions = await _firestore
            .collection('users')
            .doc(currentUserId)
            .collection('categories')
            .doc(categoryId)
            .collection('transactions')
            .orderBy('date')
            .get();

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
      print('Error calculating trends: $e');
      // Fall back to calculating everything from transactions
      if (categoryId != null) {
        // For a specific category
        DocumentSnapshot categorySnapshot =
            await _getCategoriesCollection().doc(categoryId).get();
        if (categorySnapshot.exists) {
          double currentBalance = 0;

          // Get all transactions for this category
          QuerySnapshot transactions = await _firestore
              .collection('users')
              .doc(currentUserId)
              .collection('categories')
              .doc(categoryId)
              .collection('transactions')
              .orderBy('date')
              .get();

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
      } else {
        // For all categories
        List<DocumentSnapshot> categories = await getUserCategories();

        for (var category in categories) {
          double currentBalance = 0;

          // Get all transactions for this category
          QuerySnapshot transactions = await _firestore
              .collection('users')
              .doc(currentUserId)
              .collection('categories')
              .doc(category.id)
              .collection('transactions')
              .orderBy('date')
              .get();

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
                trendPoints[i]['balance'] =
                    (trendPoints[i]['balance'] ?? 0.0) + currentBalance;
              }
            }
          }
        }
      }
    }

    // Format for return
    for (int i = 0; i < trendPoints.length; i++) {
      trendPoints[i]['label'] =
          DateFormat('MMM yyyy').format(trendPoints[i]['date']);
    }

    return trendPoints;
  }

  // Get weekly reports
  Future<List<Map<String, dynamic>>> getWeeklyReports({int limit = 10}) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      QuerySnapshot snapshot = await _getWeeklyReportsCollection()
          .orderBy('endDate', descending: true)
          .limit(limit)
          .get();

      List<Map<String, dynamic>> reports = [];

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        reports.add({
          'reportId': doc.id,
          'startDate': data['startDate'],
          'endDate': data['endDate'],
          'deposits': data['deposits'] ?? 0.0,
          'withdrawals': data['withdrawals'] ?? 0.0,
          'net': data['net'] ?? 0.0,
        });
      }

      return reports;
    } catch (e) {
      print('Error getting weekly reports: $e');
      return [];
    }
  }

  // Get category growth rate (percentage change over time)
  Future<Map<String, dynamic>> getCategoryGrowthRate(String categoryId) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      // Get category data
      DocumentSnapshot categoryDoc =
          await _getCategoriesCollection().doc(categoryId).get();
      if (!categoryDoc.exists) {
        throw Exception('Category does not exist');
      }

      Map<String, dynamic> categoryData =
          categoryDoc.data() as Map<String, dynamic>;
      double currentAmount = categoryData['amount'] ?? 0.0;

      // Get transactions for the last 3 months
      DateTime now = DateTime.now();
      DateTime threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);

      QuerySnapshot transactions = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('categories')
          .doc(categoryId)
          .collection('transactions')
          .where('date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(threeMonthsAgo))
          .orderBy('date')
          .get();

      if (transactions.docs.isEmpty) {
        return {
          'growthRate': 0.0,
          'monthlyAverage': 0.0,
          'isGrowing': false,
        };
      }

      // Group by month
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

  // Get category breakdown (amounts in each category)
  Future<List<Map<String, dynamic>>> getCategoryBreakdown() async {
    if (currentUserId == null) throw Exception('User not authenticated');

    List<DocumentSnapshot> categories = await getUserCategories();
    List<Map<String, dynamic>> breakdown = [];

    for (var category in categories) {
      Map<String, dynamic> data = category.data() as Map<String, dynamic>;
      breakdown.add({
        'categoryId': category.id,
        'name': data['name'] ?? 'Unknown',
        'amount': data['amount'] ?? 0.0,
        'goalAmount': data['goalAmount'] ?? 0.0,
        'progress': data['goalAmount'] > 0
            ? ((data['amount'] ?? 0.0) / data['goalAmount'] * 100)
            : 100.0,
      });
    }

    return breakdown;
  }

  // Get transactions for a specific time range across all categories
  Future<List<Map<String, dynamic>>> getTransactionsForTimeRange(DateTime startDate, DateTime endDate) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    List<DocumentSnapshot> categories = await getUserCategories();
    List<Map<String, dynamic>> allTransactions = [];

    for (var category in categories) {
      QuerySnapshot transactions = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('categories')
          .doc(category.id)
          .collection('transactions')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      for (var transaction in transactions.docs) {
        Map<String, dynamic> data = transaction.data() as Map<String, dynamic>;
        Map<String, dynamic> categoryData =
            category.data() as Map<String, dynamic>;

        allTransactions.add({
          'transactionId': transaction.id,
          'categoryId': category.id,
          'categoryName': categoryData['name'] ?? 'Unknown',
          'amount': data['amount'] ?? 0.0,
          'transactionType': data['transactionType'] ?? '',
          'date': data['date'],
          'note': data['note'] ?? '',
        });
      }
    }
    //added this
    return allTransactions;
  }
}
