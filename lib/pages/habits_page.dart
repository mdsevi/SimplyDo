import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../utilities/notifications_helper.dart';
import '../models/habit.dart';
import '../character/profile.dart';
import '../utilities/add_habit.dart';
import '../extra/categories.dart';

enum HabitSortOption { dateCreated, category, alphabeticalAZ, alphabeticalZA }

class HabitsPage extends StatefulWidget {
  const HabitsPage({super.key});

  @override
  State<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends State<HabitsPage>
    with SingleTickerProviderStateMixin {
  late final Box<Habit> habitsBox;
  late final Box<Profile> profileBox;
  late Profile profile;

  late final AnimationController _holdController;
  int? _holdingKey;

  HabitSortOption _sortOption = HabitSortOption.dateCreated;

  @override
  void initState() {
    super.initState();
    habitsBox = Hive.box<Habit>('habits');
    profileBox = Hive.box<Profile>('profileBox');

    profile = profileBox.get(
      'player',
      defaultValue: Profile(
        username: "Hero",
        experience: 0,
        coins: 0,
        level: 1,
        health: 100,
      ),
    )!;

    _holdController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _holdController.addStatusListener((status) async {
      if (status == AnimationStatus.completed && _holdingKey != null) {
        final habit = habitsBox.get(_holdingKey);
        if (habit == null) {
          _resetHold();
          return;
        }

        if (habit.isCompleted) {
          habit.completionsToday = 0;
          habit.isCompleted = false;
          habit.streak = max(0, habit.streak - 1);
          _undoRewardsFor(habit);
          await habit.save();
        } else {
          final remaining = habit.timesPerDay - habit.completionsToday;
          for (int i = 0; i < remaining; i++) {
            habit.complete(profile);
          }
          if (habit.completionsToday >= habit.timesPerDay) {
            _applyRewardsFor(habit);
          }
          await habit.save();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Auto-completed $remaining× "${habit.name}"'),
              ),
            );
          }
        }

        _resetHold();
      }

      if (status == AnimationStatus.dismissed && _holdingKey != null) {
        setState(() => _holdingKey = null);
      }
    });
  }

  void _resetHold() {
    _holdController.reset();
    setState(() => _holdingKey = null);
  }

  @override
  void dispose() {
    _holdController.dispose();
    super.dispose();
  }

  // ---------- Notifications ----------
  Future<void> _scheduleHabitNotification(Habit habit, int id) async {
    if (habit.habitTime == null) return;
    await NotificationsHelper.scheduleHabitReminder(habit);
  }

  // ---------- Add ----------
  void _addHabit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => AddHabitPage(
          onAdd: (habit) async {
            final key = await habitsBox.add(habit);
            _scheduleHabitNotification(habit, key);
          },
        ),
      ),
    );
  }

  // ---------- Edit ----------
  Future<void> _editHabit(Habit habit) async {
    final nameController = TextEditingController(text: habit.name);
    final descController = TextEditingController(text: habit.description);
    int timesPerDay = habit.timesPerDay;
    String category = habit.category.isNotEmpty
        ? habit.category
        : Categories.all.first;
    String difficulty = habit.difficulty;
    TimeOfDay? habitTime = habit.habitTimeOfDay;
    int? reminderMinutes = habit.reminderMinutesBefore;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Edit Habit'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Habit Name'),
                ),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Times per day:"),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            if (timesPerDay > 1) {
                              setState(() => timesPerDay--);
                            }
                          },
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text(
                          timesPerDay.toString(),
                          style: const TextStyle(fontSize: 18),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() => timesPerDay++);
                          },
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  items: Categories.all
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => category = val);
                  },
                  decoration: const InputDecoration(labelText: "Category"),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: difficulty,
                  items: ["Easy", "Medium", "Hard"]
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => difficulty = val);
                  },
                  decoration: const InputDecoration(labelText: "Difficulty"),
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: Text(
                    habitTime != null
                        ? habitTime!.format(context)
                        : "Pick Time",
                  ),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: ctx,
                      initialTime: habitTime ?? TimeOfDay.now(),
                    );
                    if (picked != null) setState(() => habitTime = picked);
                  },
                ),
                if (habitTime != null)
                  TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Reminder minutes before",
                    ),
                    controller: TextEditingController(
                      text: reminderMinutes?.toString() ?? "",
                    ),
                    onChanged: (val) {
                      reminderMinutes = val.isEmpty ? null : int.tryParse(val);
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await habit.delete();
                if (mounted) Navigator.pop(ctx, null);
              },
              child: const Text('Delete'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx, {
                  "name": nameController.text,
                  "desc": descController.text,
                  "times": timesPerDay,
                  "category": category,
                  "difficulty": difficulty,
                  "habitTime": habitTime,
                  "reminderMinutes": reminderMinutes,
                });
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      habit.name = result["name"];
      habit.description = result["desc"];
      habit.timesPerDay = result["times"];
      habit.category = result["category"];
      habit.difficulty = result["difficulty"];
      habit.habitTime = result["habitTime"] == null
          ? null
          : DateTime(
              DateTime.now().year,
              DateTime.now().month,
              DateTime.now().day,
              result["habitTime"].hour,
              result["habitTime"].minute,
            );
      habit.reminderMinutesBefore = result["reminderMinutes"];
      await habit.save();

      final key = habit.key;
      if (key is int) {
        _scheduleHabitNotification(habit, key);
      }
    }
  }

  // ---------- Rewards ----------
  int _randomBetween(int min, int max) {
    final r = Random();
    return min + r.nextInt(max - min + 1);
  }

  (int, int) _rollRewards(String difficulty) {
    switch (difficulty) {
      case "Hard":
        return (_randomBetween(20, 40), _randomBetween(6, 12));
      case "Medium":
        return (_randomBetween(10, 20), _randomBetween(3, 6));
      case "Easy":
      default:
        return (_randomBetween(5, 10), _randomBetween(1, 3));
    }
  }

  void _applyRewardsFor(Habit h) {
    if (h.completionsToday < h.timesPerDay) return;

    final (exp, coins) = _rollRewards(h.difficulty);
    profile.addRewards(exp, coins);

    h.lastExpReward = exp;
    h.lastCoinReward = coins;
    h.isCompleted = true;
    h.save();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Completed "${h.name}"! +$exp XP, +$coins coins')),
    );
  }

  void _undoRewardsFor(Habit h) {
    profile.removeRewards(h.lastExpReward, h.lastCoinReward);

    h.lastExpReward = 0;
    h.lastCoinReward = 0;
    h.isCompleted = false;
    h.save();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Habit undone, rewards removed.')),
    );
  }

  // ---------- Sorting ----------
  List<Habit> _sortHabits(List<Habit> habits) {
    int _nullsLast<T>(T? a, T? b, int Function(T, T) cmp) {
      if (a == null && b == null) return 0;
      if (a == null) return 1;
      if (b == null) return -1;
      return cmp(a, b);
    }

    switch (_sortOption) {
      case HabitSortOption.dateCreated:
        habits.sort(
          (a, b) => _nullsLast<DateTime?>(
            a.createdAt,
            b.createdAt,
            (x, y) => x!.compareTo(y!),
          ),
        );
        break;
      case HabitSortOption.category:
        habits.sort(
          (a, b) =>
              a.category.toLowerCase().compareTo(b.category.toLowerCase()),
        );
        break;
      case HabitSortOption.alphabeticalAZ:
        habits.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case HabitSortOption.alphabeticalZA:
        habits.sort(
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
        break;
    }
    return habits;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Habits'),
        actions: [
          DropdownButton<HabitSortOption>(
            value: _sortOption,
            underline: const SizedBox(),
            onChanged: (val) {
              if (val != null) setState(() => _sortOption = val);
            },
            items: const [
              DropdownMenuItem(
                value: HabitSortOption.dateCreated,
                child: Text("Date Created"),
              ),
              DropdownMenuItem(
                value: HabitSortOption.category,
                child: Text("Category"),
              ),
              DropdownMenuItem(
                value: HabitSortOption.alphabeticalAZ,
                child: Text("A–Z"),
              ),
              DropdownMenuItem(
                value: HabitSortOption.alphabeticalZA,
                child: Text("Z–A"),
              ),
            ],
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: habitsBox.listenable(),
        builder: (context, Box<Habit> box, _) {
          if (box.isEmpty) {
            return const Center(child: Text('No habits yet'));
          }

          final habits = _sortHabits(box.values.toList(growable: false));

          return ListView.builder(
            itemCount: habits.length,
            itemBuilder: (context, index) {
              final habit = habits[index];

              return Dismissible(
                key: ValueKey(habit.key),
                background: Container(
                  color: Colors.blue,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.edit, color: Colors.white),
                ),
                secondaryBackground: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  if (direction == DismissDirection.startToEnd) {
                    await _editHabit(habit);
                    return false;
                  } else if (direction == DismissDirection.endToStart) {
                    await habit.delete();
                    return true;
                  }
                  return false;
                },
                child: GestureDetector(
                  onTapDown: (_) {
                    _holdingKey = habit.key is int ? habit.key as int : null;
                    _holdController.forward(from: 0);
                    setState(() {});
                  },
                  onTapUp: (_) {
                    if (_holdController.value < 1.0) {
                      _holdController.reverse();
                      _holdingKey = null;
                      setState(() {});
                    }
                  },
                  onTapCancel: () {
                    if (_holdController.value < 1.0) {
                      _holdController.reverse();
                      _holdingKey = null;
                      setState(() {});
                    }
                  },
                  child: AnimatedBuilder(
                    animation: _holdController,
                    builder: (context, child) {
                      final bool isHoldingThis =
                          _holdingKey != null && habit.key == _holdingKey;
                      final scale = isHoldingThis
                          ? 1.0 + (_holdController.value * 0.05)
                          : 1.0;

                      final progressColor = habit.isCompleted
                          ? Colors.red
                          : Colors.green;

                      return Transform.scale(
                        scale: scale,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ListTile(
                              title: Text(habit.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (habit.description.isNotEmpty)
                                    Text(habit.description),
                                  if (habit.category.isNotEmpty)
                                    Text(
                                      "Category: ${habit.category}",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.secondary,
                                      ),
                                    ),
                                  Text(
                                    "Streak: ${habit.streak} • "
                                    "${habit.completionsToday} / ${habit.timesPerDay}"
                                    "${habit.habitTime != null ? " • ${TimeOfDay.fromDateTime(habit.habitTime!).format(context)}" : ""}",
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  habit.isCompleted
                                      ? Icons.check_circle
                                      : Icons.circle_outlined,
                                  color: habit.isCompleted
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                                onPressed: () {
                                  if (habit.isCompleted) {
                                    habit.undoComplete();
                                    habit.streak = max(0, habit.streak - 1);
                                    _undoRewardsFor(habit);
                                    habit.save();
                                  } else {
                                    habit.complete(profile);
                                    if (habit.completionsToday >=
                                        habit.timesPerDay) {
                                      _applyRewardsFor(habit);
                                    }
                                  }
                                },
                              ),
                            ),
                            if (isHoldingThis)
                              SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(
                                  value: _holdController.value,
                                  strokeWidth: 3,
                                  color: progressColor,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "habitsFab",
        onPressed: _addHabit,
        child: const Icon(Icons.add),
      ),
    );
  }
}
