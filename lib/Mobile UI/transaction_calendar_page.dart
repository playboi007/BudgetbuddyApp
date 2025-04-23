import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'package:budgetbuddy_app/services/transaction_provider.dart';
import 'package:budgetbuddy_app/services/reports_service.dart';
import 'package:budgetbuddy_app/utils/constants/colors.dart';
import 'package:budgetbuddy_app/utils/constants/text_strings.dart';

class TransactionCalendarPage extends StatefulWidget {
  const TransactionCalendarPage({Key? key}) : super(key: key);

  @override
  _TransactionCalendarPageState createState() =>
      _TransactionCalendarPageState();
}

class _TransactionCalendarPageState extends State<TransactionCalendarPage> {
  final ReportsService _reportsService = ReportsService();
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  Map<DateTime, List<Map<String, dynamic>>> _transactionsByDay = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Calculate the first and last day of the month
      final firstDay = DateTime(_focusedDay.year, _focusedDay.month, 1);
      final lastDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);

      // Get transactions for the month
      final transactions = await _reportsService.getTransactionsForTimeRange(
        firstDay,
        lastDay,
      );

      // Group transactions by day
      final Map<DateTime, List<Map<String, dynamic>>> transactionsByDay = {};

      for (var transaction in transactions) {
        final Timestamp timestamp = transaction['date'];
        final DateTime date = DateTime(
          timestamp.toDate().year,
          timestamp.toDate().month,
          timestamp.toDate().day,
        );

        if (!transactionsByDay.containsKey(date)) {
          transactionsByDay[date] = [];
        }

        transactionsByDay[date]!.add(transaction);
      }

      setState(() {
        _transactionsByDay = transactionsByDay;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getTransactionsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _transactionsByDay[normalizedDay] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(TextStrings.transactionCalendar),
        backgroundColor: Appcolors.blue600,
        foregroundColor: Appcolors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : Column(
                  children: [
                    TableCalendar(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      calendarFormat: _calendarFormat,
                      selectedDayPredicate: (day) {
                        return isSameDay(_selectedDay, day);
                      },
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });

                        // Show transactions for the selected day
                        final transactions =
                            _getTransactionsForDay(selectedDay);
                        if (transactions.isNotEmpty) {
                          _showTransactionDetails(
                              context, selectedDay, transactions);
                        }
                      },
                      onFormatChanged: (format) {
                        setState(() {
                          _calendarFormat = format;
                        });
                      },
                      onPageChanged: (focusedDay) {
                        setState(() {
                          _focusedDay = focusedDay;
                        });
                        _loadTransactions();
                      },
                      calendarStyle: CalendarStyle(
                        todayDecoration: BoxDecoration(
                          color: Appcolors.blue400.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: const BoxDecoration(
                          color: Appcolors.blue600,
                          shape: BoxShape.circle,
                        ),
                        markerDecoration: const BoxDecoration(
                          color: Appcolors.chartRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, date, events) {
                          final transactions = _getTransactionsForDay(date);
                          if (transactions.isEmpty) return null;

                          // Count deposits and withdrawals
                          int deposits = 0;
                          int withdrawals = 0;
                          for (var transaction in transactions) {
                            if (transaction['transactionType'] == 'deposit') {
                              deposits++;
                            } else if (transaction['transactionType'] ==
                                'withdrawal') {
                              withdrawals++;
                            }
                          }

                          return Positioned(
                            bottom: 1,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (deposits > 0)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 1),
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Appcolors.chartGreen,
                                    ),
                                  ),
                                if (withdrawals > 0)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 1),
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Appcolors.chartRed,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Appcolors.chartGreen,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text('Deposits'),
                            ],
                          ),
                          const SizedBox(width: 20),
                          Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Appcolors.chartRed,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text('Withdrawals'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  void _showTransactionDetails(BuildContext context, DateTime day,
      List<Map<String, dynamic>> transactions) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Transactions for ${DateFormat('MMMM d, yyyy').format(day)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final transaction = transactions[index];
                        final bool isDeposit =
                            transaction['transactionType'] == 'deposit';
                        final Timestamp timestamp = transaction['date'];
                        final DateTime dateTime = timestamp.toDate();
                        final String time =
                            DateFormat('h:mm a').format(dateTime);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8.0),
                          child: ListTile(
                            leading: Icon(
                              isDeposit
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              color: isDeposit
                                  ? Appcolors.chartGreen
                                  : Appcolors.chartRed,
                            ),
                            title:
                                Text(transaction['categoryName'] ?? 'Unknown'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(time),
                                if (transaction['note'] != null &&
                                    transaction['note'].toString().isNotEmpty)
                                  Text(
                                    transaction['note'],
                                    style:
                                        TextStyle(fontStyle: FontStyle.italic),
                                  ),
                              ],
                            ),
                            trailing: Text(
                              'Ksh ${transaction['amount'].toStringAsFixed(2)}',
                              style: TextStyle(
                                color: isDeposit
                                    ? Appcolors.chartGreen
                                    : Appcolors.chartRed,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
