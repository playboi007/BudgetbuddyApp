import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:budgetbuddy_app/data models/budget_models.dart';
import 'package:budgetbuddy_app/utils/constants/enums.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz_data.initializeTimeZones();

    final AndroidInitializationSettings androidInitSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings iosInitSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initSettings = InitializationSettings(
      android: androidInitSettings,
      iOS: iosInitSettings,
    );

    // Initialize the notifications plugin
    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification taps here
        // This can be expanded later to navigate to specific screens
      },
    );
  }

  Future<void> requestPermissions() async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    // Request permissions for Android (for Android 13 and above)
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> scheduleSavingsGoalReminder(BudgetCategory goal) async {
    // Cancel any existing notifications for this goal
    await cancelSavingsGoalReminders(goal.id);

    // Calculate base notification ID from goal ID
    final int baseId = goal.id.hashCode;

    // Check if goal is completed
    if (goal.amount >= (goal.goalAmount ?? 0)) {
      // Schedule congratulatory notification immediately
      await showImmediateNotification(
        id: baseId,
        title: 'Congratulations! 🎉',
        body: 'You have completed your ${goal.name} savings goal!',
      );
      return; // Skip other reminders
    }

    // Use custom reminder date if set, otherwise use default 30-day period
    final DateTime targetDate =
        goal.reminderDate ?? goal.createdAt.add(const Duration(days: 30));
    final int daysRemaining = targetDate.difference(DateTime.now()).inDays;

    // Schedule recurring reminders based on frequency
    if (goal.reminderDate != null &&
        goal.reminderFrequency != ReminderFrequency.none) {
      await _scheduleRecurringReminder(goal);
    }

    // Schedule 3-day reminder if more than 3 days remain
    if (daysRemaining > 3) {
      final DateTime reminderDate =
          targetDate.subtract(const Duration(days: 3));
      await _scheduleNotification(
        id: baseId,
        title: 'Goal Reminder',
        body:
            'Your ${goal.name} goal is due in 3 days. Current progress: ${(goal.amount / (goal.goalAmount ?? 1) * 100).toStringAsFixed(0)}%',
        scheduledDate: reminderDate,
      );
    }

    // Schedule weekly progress reminder if more than 7 days remain
    if (daysRemaining > 7) {
      final DateTime weeklyReminderDate =
          DateTime.now().add(const Duration(days: 7));
      await _scheduleNotification(
        id: baseId + 1,
        title: 'Weekly Progress Update',
        body:
            'You\'ve saved ${goal.formattedAmount} towards your ${goal.name} goal.',
        scheduledDate: weeklyReminderDate,
      );
    }

    // Calculate current progress percentage
    final double progressPercentage = goal.amount / (goal.goalAmount ?? 1);

    // Schedule milestone notifications (25%, 50%, 75%)
    final List<double> milestones = [0.25, 0.5, 0.75];
    for (int i = 0; i < milestones.length; i++) {
      final double milestone = milestones[i];
      if (progressPercentage < milestone) {
        // Calculate amount needed to reach this milestone
        final double targetAmount = (goal.goalAmount ?? 0) * milestone;
        final double amountNeeded = targetAmount - goal.amount;

        if (amountNeeded > 0) {
          await _scheduleNotification(
            id: baseId + 2 + i,
            title: '${(milestone * 100).toInt()}% Milestone Approaching',
            body:
                'You need Ksh ${amountNeeded.toStringAsFixed(0)} more to reach the ${(milestone * 100).toInt()}% milestone for your ${goal.name} goal.',
            scheduledDate: DateTime.now().add(Duration(days: 1 + i)),
          );
        }
      }
    }

    // Check if goal is overdue
    if (DateTime.now().isAfter(targetDate)) {
      await _scheduleNotification(
        id: baseId + 5,
        title: 'Goal Overdue',
        body:
            'Your ${goal.name} goal is overdue. You\'ve currently saved ${(progressPercentage * 100).toStringAsFixed(0)}% of your target.',
        scheduledDate: DateTime.now(),
      );
    }
  }

  Future<void> cancelSavingsGoalReminders(String goalId) async {
    final int baseId = goalId.hashCode;
    final int recurringBaseId = baseId + 100;

    // Cancel regular reminders
    for (int i = 0; i <= 5; i++) {
      await _notificationsPlugin.cancel(baseId + i);
    }

    // Cancel recurring reminders
    for (int i = 0; i <= 2; i++) {
      await _notificationsPlugin.cancel(recurringBaseId + i);
    }
  }

  Future<void> _scheduleRecurringReminder(BudgetCategory goal) async {
    if (goal.reminderDate == null) return;

    final int baseId = goal.id.hashCode +
        100; // Use a different base ID for recurring reminders
    final DateTime startDate = goal.reminderDate!;

    // Calculate next reminder date based on frequency
    DateTime nextReminderDate;
    DateTimeComponents dateTimeComponents;

    switch (goal.reminderFrequency) {
      case ReminderFrequency.weekly:
        nextReminderDate = startDate;
        dateTimeComponents = DateTimeComponents.dayOfWeekAndTime;
        break;
      case ReminderFrequency.biWeekly:
        // For bi-weekly, we'll schedule two notifications
        // First one on the start date
        await _scheduleNotification(
          id: baseId,
          title: 'Savings Goal Reminder',
          body:
              'Remember to check your progress on ${goal.name}. Current: ${goal.formattedAmount}',
          scheduledDate: startDate,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );

        // Second one two weeks after the start date
        nextReminderDate = startDate.add(const Duration(days: 14));
        dateTimeComponents = DateTimeComponents.dayOfWeekAndTime;
        break;
      case ReminderFrequency.monthly:
        nextReminderDate = startDate;
        dateTimeComponents = DateTimeComponents.dayOfMonthAndTime;
        break;
      default:
        return; // No recurring reminder needed
    }

    await _scheduleNotification(
      id: baseId + 1,
      title: 'Recurring Savings Goal Reminder',
      body:
          'Check your progress on ${goal.name}. Current: ${goal.formattedAmount}',
      scheduledDate: nextReminderDate,
      matchDateTimeComponents: dateTimeComponents,
    );
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    final tz.TZDateTime tzScheduledDate = tz.TZDateTime.from(
      scheduledDate,
      tz.local,
    );

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'savings_goals_channel',
      'Savings Goals',
      channelDescription: 'Notifications for savings goals',
      importance: Importance.high,
      priority: Priority.high,
      color: Colors.green,
      showWhen: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tzScheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents:
          matchDateTimeComponents ?? DateTimeComponents.time,
      /*uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,*/
    );
  }

  Future<void> scheduleAllSavingsGoalReminders(
      List<BudgetCategory> goals) async {
    for (final goal in goals) {
      if (goal.categoryType == 'savings' && goal.goalAmount != null) {
        // Schedule reminder if a custom reminder date is set or if it's a savings goal
        await scheduleSavingsGoalReminder(goal);
      }
    }
  }

  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'savings_goals_channel',
      'Savings Goals',
      channelDescription: 'Notifications for savings goals',
      importance: Importance.high,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // Notification details for both platforms
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Show the notification immediately
    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
    );
  }
}
