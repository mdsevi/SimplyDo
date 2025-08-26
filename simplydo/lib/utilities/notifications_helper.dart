import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/task.dart';
import '../models/habit.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class NotificationsHelper {
  // ===================== INIT =====================

  static Future<void> init() async {
    tz.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOSInit = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iOSInit,
    );

    await flutterLocalNotificationsPlugin.initialize(initSettings);

    // ✅ Permissions for iOS + Android 13+
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    // ✅ Listen for Task changes
    final taskBox = Hive.box<Task>('tasks');
    taskBox.watch().listen((event) async {
      final task = event.value as Task?;
      if (task == null) return;

      if (event.deleted) {
        await NotificationsHelper.cancelTaskReminder(task);
      } else {
        if (task.isComplete) {
          await NotificationsHelper.cancelTaskReminder(task);
        } else {
          await NotificationsHelper.scheduleTaskReminder(task);
        }
      }
    });

    // ✅ Listen for Habit changes
    final habitBox = Hive.box<Habit>('habits');
    habitBox.watch().listen((event) async {
      final habit = event.value as Habit?;
      if (habit == null) return;

      if (event.deleted) {
        await NotificationsHelper.cancelHabitReminder(habit);
      } else {
        if (habit.reminderDate == null) {
          await NotificationsHelper.cancelHabitReminder(habit);
        } else {
          await NotificationsHelper.scheduleHabitReminder(habit);
        }
      }
    });
  }

  // ===================== TASK REMINDERS =====================

  static Future<void> scheduleTaskReminder(Task task) async {
    if (task.reminderDate == null) return;

    final id = task.key is int ? task.key as int : task.hashCode;

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      "Task Reminder",
      task.title,
      tz.TZDateTime.from(task.reminderDate!, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_channel',
          'Task Reminders',
          channelDescription: 'Reminders for tasks',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelTaskReminder(Task task) async {
    final id = task.key is int ? task.key as int : task.hashCode;
    await NotificationsHelper.cancelNotification(id);
  }

  // ===================== HABIT REMINDERS =====================

  static Future<void> scheduleHabitReminder(Habit habit) async {
    final reminderDate = habit.reminderDate;
    if (reminderDate == null) return;

    final id = habit.key is int ? habit.key as int : habit.hashCode;

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      "Habit Reminder",
      "Don't forget your habit: ${habit.name}",
      tz.TZDateTime.from(reminderDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'habit_channel',
          'Habit Reminders',
          channelDescription: 'Reminders for daily habits',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // 🔁 repeat daily
    );
  }

  static Future<void> cancelHabitReminder(Habit habit) async {
    final id = habit.key is int ? habit.key as int : habit.hashCode;
    await NotificationsHelper.cancelNotification(id);
  }

  // ===================== HELPERS =====================

  static Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }
}
