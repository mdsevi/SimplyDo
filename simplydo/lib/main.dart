import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'main_page.dart';
import 'models/task.dart';
import 'models/habit.dart';
import 'character/profile.dart';
import 'models/shop_item.dart';
import 'utilities/notifications_helper.dart';

Future<void> ensureSettingsDefaults() async {
  final settingsBox = Hive.box('settings');

  Future<void> setIfMissing(String key, dynamic value) async {
    if (!settingsBox.containsKey(key)) {
      await settingsBox.put(key, value);
    }
  }

  await setIfMissing('themeMode', ThemeMode.system.index);
  await setIfMissing('notifications', true);

  // Skills
  await setIfMissing('skillPoints', 0);
  await setIfMissing('vitality', 0);
  await setIfMissing('intelligence', 0);
  await setIfMissing('luck', 0);

  // Active boosts (list of maps)
  await setIfMissing('activeBoosts', <Map<String, dynamic>>[]);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  tz.initializeTimeZones();

  // Register ALL adapters
  Hive.registerAdapter(TaskAdapter());
  Hive.registerAdapter(SubTaskAdapter());
  Hive.registerAdapter(TaskRepeatAdapter());
  Hive.registerAdapter(RepeatTypeAdapter());
  Hive.registerAdapter(HabitAdapter());
  Hive.registerAdapter(ProfileAdapter());
  Hive.registerAdapter(ShopItemAdapter());

  await Hive.openBox<Task>('tasks');
  await Hive.openBox<Habit>('habits');
  await Hive.openBox<Profile>('profile');
  await Hive.openBox('settings');
  await Hive.openBox<ShopItem>('shop');

  await NotificationsHelper.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<void> _initApp() async {
    // Open remaining boxes lazily after UI is up
    await Hive.openBox<Task>('archiveTasks');
    await Hive.openBox<Habit>('habits');
    await Hive.openBox<Profile>('profileBox');
    final shopBox = await Hive.openBox<ShopItem>('shopBox');

    // Init notifications
    await NotificationsHelper.init();

    // Reschedule reminders
    final tasksBox = Hive.box<Task>('tasks');
    for (var key in tasksBox.keys) {
      final task = await tasksBox.get(key);
      if (task?.reminderDate != null) {
        await task!.scheduleReminder();
      }
    }

    // Seed profile
    var profileBox = Hive.box<Profile>('profileBox');
    if (profileBox.get('player') == null) {
      profileBox.put(
        'player',
        Profile(
          username: 'Player',
          experience: 0,
          coins: 0,
          level: 1,
          health: 100,
          avatarPath: null,
        ),
      );
    }

    await ensureSettingsDefaults();

    // Seed shop
    if (shopBox.isEmpty) {
      shopBox.add(
        ShopItem(
          name: "Health Potion",
          price: 25,
          type: "potion",
          description: "Restores 30 HP",
          healAmount: 30,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsBox = Hive.box("settings");
    return ValueListenableBuilder(
      valueListenable: settingsBox.listenable(),
      builder: (context, box, _) {
        final themeMode = ThemeMode
            .values[box.get("themeMode", defaultValue: ThemeMode.system.index)];

        final lightTheme = ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: Colors.grey[100],
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          cardColor: Colors.white,
        );

        final darkTheme = ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurpleAccent,
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF121212),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
          cardColor: const Color(0xFF1E1E1E),
        );

        return FutureBuilder(
          future: _initApp(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const MaterialApp(
                home: Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: lightTheme,
              darkTheme: darkTheme,
              themeMode: themeMode,
              home: const MainPage(),
            );
          },
        );
      },
    );
  }
}
