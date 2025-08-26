import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../character/profile.dart';
import '../models/task.dart';
import '../models/habit.dart';
import '../models/shop_item.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final Box<Profile> profileBox;
  late final Box settingsBox;
  late final Box<Task> tasksBox;
  late final Box<Task> archiveBox;
  late final Box<Habit> habitsBox;
  late final Box<ShopItem> shopBox;

  final _nameController = TextEditingController();

  // ---------------- Notifications ----------------
  final _fln = FlutterLocalNotificationsPlugin();
  static const _dailyChannel = AndroidNotificationChannel(
    'daily_reminder_channel',
    'Daily Reminders',
    description: 'Daily reminder to check your tasks & habits',
    importance: Importance.defaultImportance,
  );

  Future<void> _initNotifications() async {
    // Android init (request runtime permission on Android 13+)
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    // iOS init
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _fln.initialize(initSettings);

    // Create Android channel
    final androidPlugin = _fln
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(_dailyChannel);
      await androidPlugin.requestNotificationsPermission();
    }

    // Ask iOS permissions
    final iosPlugin = _fln
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (iosPlugin != null) {
      await iosPlugin.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  /// Schedules/cancels a simple daily reminder at user's preferred time.
  /// Pref time is stored in settings as 'reminderHour' (0-23) & 'reminderMin' (0-59).
  Future<void> _refreshDailyReminder(bool enabled) async {
    if (!enabled) {
      await _fln.cancel(1001);
      return;
    }

    // Ensure notifications initialized + permissions ok
    await _initNotifications();

    final hour =
        settingsBox.get('reminderHour', defaultValue: 20) as int; // 8pm
    final min = settingsBox.get('reminderMin', defaultValue: 0) as int;

    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, min);
    if (next.isBefore(now)) next = next.add(const Duration(days: 1));

    await _fln.zonedSchedule(
      1001,
      'Time to check in ✨',
      'Review your tasks & habits to earn XP and coins!',
      next,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _dailyChannel.id,
          _dailyChannel.name,
          channelDescription: _dailyChannel.description,
          priority: Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // repeat daily
    );
  }

  Future<void> _pickReminderTime() async {
    final initialTime = TimeOfDay(
      hour: settingsBox.get('reminderHour', defaultValue: 20),
      minute: settingsBox.get('reminderMin', defaultValue: 0),
    );
    final t = await showTimePicker(context: context, initialTime: initialTime);
    if (t != null) {
      settingsBox.put('reminderHour', t.hour);
      settingsBox.put('reminderMin', t.minute);
      if (settingsBox.get('notifications', defaultValue: true) == true) {
        await _refreshDailyReminder(true);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Daily reminder set to ${t.format(context)}')),
        );
        setState(() {});
      }
    }
  }

  @override
  void initState() {
    super.initState();
    profileBox = Hive.box<Profile>('profileBox');
    settingsBox = Hive.box('settings');
    tasksBox = Hive.box<Task>('tasks');
    archiveBox = Hive.box<Task>('archiveTasks');
    habitsBox = Hive.box<Habit>('habits');
    shopBox = Hive.box<ShopItem>('shopBox');

    final p = profileBox.get('player');
    if (p != null) {
      _nameController.text = p.username;
    }

    // Initialize notifications and ensure current toggle state is respected
    _initNotifications().then((_) {
      final enabled =
          settingsBox.get('notifications', defaultValue: true) as bool;
      _refreshDailyReminder(enabled);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // --- Helper: Always reseed potion ---
  void _addDefaultPotion() {
    final hasPotion = shopBox.values.any(
      (item) => item.name == "Health Potion",
    );
    if (!hasPotion) {
      shopBox.add(
        ShopItem(
          name: "Health Potion",
          price: 25,
          description: "Restores 30 HP",
          type: "potion",
          healAmount: 30,
        ),
      );
    }
  }

  Future<bool> _confirmDialog(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("Confirm"),
              ),
            ],
          ),
        ) ??
        false;
  }

  // --- Profile Updates ---
  void _updateName() {
    final p = profileBox.get('player');
    if (p != null) {
      p.username = _nameController.text.trim();
      p.save();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Name updated!")));
    }
  }

  Future<void> _updateAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final p = profileBox.get('player');
      if (p != null) {
        p.avatarPath = picked.path;
        p.save();
        if (mounted) setState(() {});
      }
    }
  }

  // --- Reset & Delete Actions ---
  Future<void> _resetProgress() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reset Progress"),
        content: const Text(
          "This will erase all your tasks, habits, stats, shop items, and reset your profile. "
          "Are you sure you want to continue?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Reset"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Clear tasks
      await tasksBox.clear();

      // Clear habits
      await habitsBox.clear();

      // Clear archive
      await archiveBox.clear();

      // Clear shop items
      await shopBox.clear();

      // Reset profile stats
      final p = profileBox.get('player');
      if (p != null) {
        await p
            .resetStats(); // this should reset level, exp, coins, skills, etc.
        await p.save();
      }

      // Reset settings back to defaults
      await settingsBox.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("All progress has been reset.")),
        );
        setState(() {}); // refresh UI
      }
    }
  }

  Future<void> _resetShop() async {
    final confirm = await _confirmDialog(
      "Reset Shop",
      "This will delete all shop items except the Health Potion. Continue?",
    );
    if (!confirm) return;

    await shopBox.clear();
    _addDefaultPotion();

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Shop reset successfully!")));
      setState(() {});
    }
  }

  Future<void> _clearArchive() async {
    final confirm = await _confirmDialog(
      "Delete All Archived Tasks",
      "This will delete all archived tasks permanently. Continue?",
    );
    if (!confirm) return;

    await archiveBox.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All archived tasks deleted!")),
      );
      setState(() {});
    }
  }

  Future<void> _clearHabits() async {
    final confirm = await _confirmDialog(
      "Delete All Habits",
      "This will delete all habits permanently. Continue?",
    );
    if (!confirm) return;

    await habitsBox.clear();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("All habits deleted!")));
      setState(() {});
    }
  }

  Future<void> _clearTasks() async {
    final confirm = await _confirmDialog(
      "Delete All Active Tasks",
      "This will delete all active tasks permanently. Continue?",
    );
    if (!confirm) return;

    await tasksBox.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All active tasks deleted!")),
      );
      setState(() {});
    }
  }

  // --- Settings ---
  void _toggleTheme(ThemeMode mode) {
    settingsBox.put("themeMode", mode.index);
    setState(() {});
    // NOTE: Ensure your MaterialApp reads this value to actually update theme.
  }

  Future<void> _toggleNotifications(bool enabled) async {
    settingsBox.put("notifications", enabled);
    await _refreshDailyReminder(enabled);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled ? "Daily reminders enabled" : "Daily reminders disabled",
          ),
        ),
      );
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = profileBox.get('player');
    final currentTheme =
        ThemeMode.values[settingsBox.get(
          "themeMode",
          defaultValue: ThemeMode.system.index,
        )];
    final notificationsEnabled =
        settingsBox.get("notifications", defaultValue: true) as bool;

    final reminderHour =
        settingsBox.get('reminderHour', defaultValue: 20) as int;
    final reminderMin = settingsBox.get('reminderMin', defaultValue: 0) as int;

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Avatar + Username ---
          Center(
            child: GestureDetector(
              onTap: _updateAvatar,
              child: CircleAvatar(
                radius: 50,
                backgroundImage:
                    (p?.avatarPath != null && File(p!.avatarPath!).existsSync())
                    ? FileImage(File(p.avatarPath!))
                    : null,
                child:
                    (p?.avatarPath == null ||
                        !(p?.avatarPath != null &&
                            File(p!.avatarPath!).existsSync()))
                    ? const Icon(Icons.person, size: 50)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: "Username"),
            onSubmitted: (_) => _updateName(),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _updateName,
            child: const Text("Save Name"),
          ),

          const Divider(height: 32),

          // --- Theme Switch ---
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: const Text("Theme"),
            subtitle: const Text("Choose app appearance"),
            trailing: DropdownButton<ThemeMode>(
              value: currentTheme,
              items: const [
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text("System"),
                ),
                DropdownMenuItem(value: ThemeMode.light, child: Text("Light")),
                DropdownMenuItem(value: ThemeMode.dark, child: Text("Dark")),
              ],
              onChanged: (mode) {
                if (mode != null) _toggleTheme(mode);
              },
            ),
          ),

          // --- Notifications ---
          SwitchListTile(
            secondary: const Icon(Icons.notifications),
            title: const Text("Enable Daily Reminder"),
            subtitle: Text(
              notificationsEnabled
                  ? "Reminder at ${TimeOfDay(hour: reminderHour, minute: reminderMin).format(context)}"
                  : "Off",
            ),
            value: notificationsEnabled,
            onChanged: (v) => _toggleNotifications(v),
          ),
          ListTile(
            enabled: notificationsEnabled,
            leading: const Icon(Icons.schedule),
            title: const Text("Reminder Time"),
            subtitle: Text(
              TimeOfDay(
                hour: reminderHour,
                minute: reminderMin,
              ).format(context),
            ),
            onTap: notificationsEnabled ? _pickReminderTime : null,
          ),

          const Divider(height: 32),

          // --- Danger Zone ---
          ExpansionTile(
            leading: const Icon(Icons.warning_amber_rounded),
            title: const Text("Danger Zone"),
            collapsedTextColor: Colors.red,
            textColor: Colors.red,
            iconColor: Colors.red,
            childrenPadding: const EdgeInsets.symmetric(
              vertical: 8,
              horizontal: 8,
            ),
            children: [
              _dangerButton(
                icon: Icons.refresh,
                label: "Reset Progress",
                color: const Color.fromARGB(255, 218, 106, 98),
                onPressed: _resetProgress,
              ),
              _dangerButton(
                icon: Icons.store,
                label: "Reset Shop",
                color: const Color.fromARGB(255, 135, 121, 206),
                onPressed: _resetShop,
              ),
              _dangerButton(
                icon: Icons.task,
                label: "Delete All Active Tasks",
                color: const Color.fromARGB(255, 135, 121, 206),
                onPressed: _clearTasks,
              ),
              _dangerButton(
                icon: Icons.delete_forever,
                label: "Delete All Archived Tasks",
                color: const Color.fromARGB(255, 135, 121, 206),
                onPressed: _clearArchive,
              ),
              _dangerButton(
                icon: Icons.delete_sweep,
                label: "Delete All Habits",
                color: const Color.fromARGB(255, 135, 121, 206),
                onPressed: _clearHabits,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dangerButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: ElevatedButton.icon(
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(backgroundColor: color),
        onPressed: onPressed,
      ),
    );
  }
}
