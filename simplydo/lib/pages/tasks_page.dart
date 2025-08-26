import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/task.dart';
import '../character/profile.dart';
import '../utilities/add_task_page.dart';
import '../utilities/notifications_helper.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

enum TaskSortOption {
  dueSoonest,
  dueLatest,
  alphabeticalAZ,
  alphabeticalZA,
  category,
  creationDateNewest,
  creationDateOldest,
}

class _TasksPageState extends State<TasksPage> {
  late final Box<Task> tasksBox;
  late final Box<Task> archiveBox;
  late final Box<Profile> profileBox;

  static const _tabTitles = <String>[
    'Today',
    'This Week',
    'Overdue',
    'All',
    'Archived',
  ];

  TaskSortOption _sortOption = TaskSortOption.dueSoonest;

  @override
  void initState() {
    super.initState();
    tasksBox = Hive.box<Task>('tasks');
    archiveBox = Hive.box<Task>('archiveTasks');
    profileBox = Hive.box<Profile>('profileBox');
  }

  /// Check all tasks and apply overdue damage once per day
  void _applyDailyOverdueDamage() {
    final profile = profileBox.get('player');
    if (profile == null) return;

    for (final task in tasksBox.values) {
      task.applyOverdueDamage(profile);
    }
  }

  // ---------------- helpers ----------------

  String _difficultyLabelToText(int idx) => switch (idx) {
    0 => "Easy",
    1 => "Medium",
    _ => "Hard",
  };

  (int exp, int coins) _rollRewards(int difficulty) {
    final rnd = Random();
    switch (difficulty) {
      case 2: // Hard
        return (rnd.nextInt(21) + 20, rnd.nextInt(7) + 6);
      case 1: // Medium
        return (rnd.nextInt(11) + 10, rnd.nextInt(4) + 3);
      default: // Easy
        return (rnd.nextInt(6) + 5, rnd.nextInt(3) + 1);
    }
  }

  DateTime _onlyDate(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  /// map remindIndex -> minutes before (null = no reminder)
  int? _minutesFromRemindIndex(int remindIndex) {
    switch (remindIndex) {
      case 0:
        return null; // None
      case 1:
        return 0; // At time
      case 2:
        return 5;
      case 3:
        return 10;
      case 4:
        return 15;
      case 5:
        return 30;
      case 6:
        return 60;
      case 7:
        return 120;
      case 8:
        return 1440; // 1 day
      default:
        return null;
    }
  }

  /// inverse: minutes -> remindIndex (for edit prefill)
  int _remindIndexFromMinutes(int? minutes) {
    switch (minutes) {
      case null:
        return 0;
      case 0:
        return 1;
      case 5:
        return 2;
      case 10:
        return 3;
      case 15:
        return 4;
      case 30:
        return 5;
      case 60:
        return 6;
      case 120:
        return 7;
      case 1440:
        return 8;
      default:
        return 0;
    }
  }

  /// build TaskRepeat from AddTaskPage indices/fields
  TaskRepeat _buildRepeat(
    int repeatIndex, {
    int? weeklyDay,
    int? monthlyDay,
    DateTime? yearlyDate,
    int? customInterval,
  }) {
    // expected order: 0 None, 1 Daily, 2 Weekly, 3 Monthly, 4 Yearly, 5 Custom
    switch (repeatIndex) {
      case 1: // Daily
        return TaskRepeat(
          type: RepeatType.daily,
          interval: customInterval ?? 1,
        );
      case 2: // Weekly (weeklyDay: 0..6 Sunday-based)
        return TaskRepeat(type: RepeatType.weekly, weekday: weeklyDay ?? 0);
      case 3: // Monthly
        return TaskRepeat(
          type: RepeatType.monthly,
          monthDay: (monthlyDay == null || monthlyDay < 1) ? 1 : monthlyDay,
        );
      case 4: // Yearly
        return TaskRepeat(
          type: RepeatType.yearly,
          month: yearlyDate?.month ?? DateTime.now().month,
          monthDay: yearlyDate?.day ?? DateTime.now().day,
        );
      case 5: // Custom (every N days)
        return TaskRepeat(
          type: RepeatType.custom,
          interval: (customInterval == null || customInterval < 1)
              ? 1
              : customInterval,
        );
      case 0:
      default:
        return TaskRepeat(type: RepeatType.none);
    }
  }

  /// inverse: TaskRepeat -> repeatIndex (+ detail fields) for edit prefill
  int _repeatIndexFromRepeat(TaskRepeat? r) {
    if (r == null) {
      return 0; // default index for "none"
    }

    switch (r.type) {
      case RepeatType.none:
        return 0;
      case RepeatType.daily:
        return 1;
      case RepeatType.weekly:
        return 2;
      case RepeatType.monthly:
        return 3;
      case RepeatType.yearly:
        return 4;
      case RepeatType.custom:
        return 5;
    }
  }

  TimeOfDay? _extractStart(DateTime? d) =>
      d == null ? null : TimeOfDay(hour: d.hour, minute: d.minute);

  // ---------------- create / edit ----------------

  void _createTask() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddTaskPage(
          onSubmit:
              (
                String title,
                String? note,
                DateTime date,
                TimeOfDay? start,
                int difficulty, {
                List<String>? subtasks,
                String category = "Others",
                int remindIndex = 0,
                int repeatIndex = 0,
                int? weeklyDay,
                int? monthlyDay,
                DateTime? yearlyDate,
                int? customInterval,
                TaskRepeat? repeat, // <-- added repeat parameter here
              }) async {
                // Build repeat & reminder here
                final repeat = _buildRepeat(
                  repeatIndex,
                  weeklyDay: weeklyDay,
                  monthlyDay: monthlyDay,
                  yearlyDate: yearlyDate,
                  customInterval: customInterval,
                );
                final reminder = _minutesFromRemindIndex(remindIndex);

                // Merge date + optional start
                final dt = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  start?.hour ?? 0,
                  start?.minute ?? 0,
                );

                final newTask = Task(
                  title: title,
                  description: (subtasks != null && subtasks.isNotEmpty)
                      ? null
                      : (note?.trim().isEmpty ?? true)
                      ? null
                      : note!.trim(),
                  subtasks: (subtasks ?? [])
                      .where((s) => s.trim().isNotEmpty)
                      .map((s) => SubTask(title: s.trim(), completed: false))
                      .toList(),
                  completed: false,
                  rewardExp: 0,
                  rewardCoins: 0,
                  dueDateEpoch: dt.millisecondsSinceEpoch,
                  difficulty: difficulty,
                  category: (category == null || category.trim().isEmpty)
                      ? "Others"
                      : category.trim(),
                  repeat: repeat, // <-- use the repeat passed in
                  reminderMinutesBefore: reminder,
                  lastDamageEpoch: 0,
                );

                await _addTask(newTask);
              },
        ),
      ),
    );
  }

  void _editTask(int indexInBox, Task task) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddTaskPage(
          initialTitle: task.title,
          initialNote: task.description,
          initialDate: task.dueDate ?? DateTime.now(),
          initialStart: _extractStart(task.dueDate),
          initialDifficulty: task.difficulty,
          initialSubtasks: task.subtasks.map((s) => s.title).toList(),
          initialCategory: task.category,
          initialRemindIndex: _remindIndexFromMinutes(
            task.reminderMinutesBefore,
          ),
          initialRepeatIndex: _repeatIndexFromRepeat(task.repeat),
          initialWeeklyDay: task.repeat?.weekday,
          initialMonthlyDay: task.repeat?.monthDay,
          initialYearlyDate:
              (task.repeat?.month != null && task.repeat?.monthDay != null)
              ? DateTime(
                  DateTime.now().year,
                  task.repeat!.month!,
                  task.repeat!.monthDay!,
                )
              : null,
          initialCustomInterval: task.repeat?.interval,
          onDelete: () async {
            await NotificationsHelper.cancelTaskReminder(task);
            await task.delete();
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
          onSubmit:
              (
                String title,
                String? note,
                DateTime date,
                TimeOfDay? start,
                int difficulty, {
                List<String>? subtasks,
                String category = "Others",
                int remindIndex = 0,
                int repeatIndex = 0,
                int? weeklyDay,
                int? monthlyDay,
                DateTime? yearlyDate,
                int? customInterval,
                TaskRepeat? repeat, // <-- added repeat parameter here
              }) async {
                final repeat = _buildRepeat(
                  repeatIndex,
                  weeklyDay: weeklyDay,
                  monthlyDay: monthlyDay,
                  yearlyDate: yearlyDate,
                  customInterval: customInterval,
                );
                final reminder = _minutesFromRemindIndex(remindIndex);

                final dt = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  start?.hour ?? 0,
                  start?.minute ?? 0,
                );

                task
                  ..title = title
                  ..description = (subtasks != null && subtasks.isNotEmpty)
                      ? null
                      : (note?.trim().isEmpty ?? true)
                      ? null
                      : note!.trim()
                  ..subtasks = (subtasks ?? [])
                      .where((s) => s.trim().isNotEmpty)
                      .map((s) => SubTask(title: s.trim(), completed: false))
                      .toList()
                  ..dueDate = dt
                  ..difficulty = difficulty
                  ..category = category.isEmpty ? "Others" : category
                  ..reminderMinutesBefore = reminder
                  ..repeat = repeat;

                await task.save();
                await task.scheduleReminder();
              },
        ),
      ),
    );
  }

  Future<void> _addTask(Task task) async {
    final tasksBox = Hive.box<Task>('tasks');
    await tasksBox.add(task);
    await task.scheduleReminder();
  }

  // ---------------- rewards + profile ----------------

  void _applyRewardsFor(Task t) {
    final (exp, coins) = _rollRewards(t.difficulty);

    t
      ..rewardExp = exp
      ..rewardCoins = coins
      ..save();

    final p = profileBox.get('player');
    if (p != null) {
      // Calculate final gains with multipliers BEFORE adding
      final finalExp = (exp * (1 + p.intelligence * 0.05)).round();
      final finalCoins = (coins * (1 + p.luck * 0.05)).round();

      // Apply through central logic (handles leveling, skill points, heal)
      p.addRewards(exp, coins);

      // Show accurate snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gained +$finalExp XP and +$finalCoins coins')),
      );
    }
  }

  void _removeRewardsFor(Task t) {
    final p = profileBox.get('player');
    if (p != null) {
      p.experience = (p.experience - t.rewardExp).clamp(0, p.experience);
      p.coins = (p.coins - t.rewardCoins).clamp(0, p.coins);
      p.save();
    }

    t
      ..rewardExp = 0
      ..rewardCoins = 0
      ..save();
  }

  // ---------------- archive / restore ----------------

  Future<void> _archiveTask(Task t) async {
    final archivedTask = Task(
      title: t.title,
      description: t.description,
      subtasks: t.subtasks
          .map((s) => SubTask(title: s.title, completed: s.completed))
          .toList(),
      completed: true,
      rewardExp: t.rewardExp,
      rewardCoins: t.rewardCoins,
      dueDateEpoch: t.dueDate?.millisecondsSinceEpoch,
      difficulty: t.difficulty,
      // keep metadata
      category: t.category,
      repeat: t.repeat,
      reminderMinutesBefore: t.reminderMinutesBefore,
      lastDamageEpoch: t.lastDamageEpoch,
    );

    await NotificationsHelper.cancelTaskReminder(t);
    await archiveBox.add(archivedTask);
    await t.delete();
  }

  Future<void> _restoreTask(Task archived) async {
    _removeRewardsFor(archived);

    final restoredTask = Task(
      title: archived.title,
      description: archived.description,
      subtasks: archived.subtasks
          .map((s) => SubTask(title: s.title, completed: false))
          .toList(),
      completed: false,
      rewardExp: 0,
      rewardCoins: 0,
      dueDateEpoch: archived.dueDate?.millisecondsSinceEpoch,
      difficulty: archived.difficulty,
      // keep metadata
      category: archived.category,
      repeat: archived.repeat,
      reminderMinutesBefore: archived.reminderMinutesBefore,
      lastDamageEpoch: archived.lastDamageEpoch,
    );

    await tasksBox.add(restoredTask);
    await archived.delete();
  }

  /// --- helper: complete & archive with rewards ---
  Future<void> _completeAndArchive(Task task) async {
    if (task.subtasks.isNotEmpty) {
      for (final s in task.subtasks) {
        s.completed = true;
      }
    }
    task.completed = true;
    await task.save();

    _applyRewardsFor(task);
    await _archiveTask(task);
  }

  // ---------------- filtering (tabs) ----------------

  List<Task> _filterActiveTasksFor(int categoryIndex) {
    final now = DateTime.now();
    final today = _onlyDate(now);
    final weekEnd = today.add(const Duration(days: 7));

    final all = tasksBox.values.toList();

    int compareTasks(Task a, Task b) {
      switch (_sortOption) {
        case TaskSortOption.dueSoonest:
          return (a.dueDate ?? DateTime(2100)).compareTo(
            b.dueDate ?? DateTime(2100),
          );
        case TaskSortOption.dueLatest:
          return (b.dueDate ?? DateTime(0)).compareTo(a.dueDate ?? DateTime(0));
        case TaskSortOption.alphabeticalAZ:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case TaskSortOption.alphabeticalZA:
          return b.title.toLowerCase().compareTo(a.title.toLowerCase());
        case TaskSortOption.category:
          return a.category.toLowerCase().compareTo(b.category.toLowerCase());
        case TaskSortOption.creationDateNewest:
          return (b.key as int).compareTo(a.key as int);
        case TaskSortOption.creationDateOldest:
          return (a.key as int).compareTo(b.key as int);
      }
    }

    if (categoryIndex == 3) {
      return all;
    }

    final todayList = <Task>[];
    final weekList = <Task>[];
    final overdueList = <Task>[];

    for (final t in all) {
      final d = _onlyDate(t.dueDate ?? today);
      if (d.isBefore(today)) {
        overdueList.add(t);
      } else if (d == today) {
        todayList.add(t);
        weekList.add(t);
      } else if (d.isAfter(today) && d.isBefore(weekEnd)) {
        weekList.add(t);
      }
    }

    return switch (categoryIndex) {
      0 => todayList,
      1 => weekList,
      2 => overdueList,
      _ => all,
    };
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 5,
      child: Builder(
        builder: (context) {
          final tabController = DefaultTabController.of(context);

          return Scaffold(
            appBar: AppBar(
              centerTitle: true,
              title: AnimatedBuilder(
                animation: tabController,
                builder: (_, __) => Text(_tabTitles[tabController.index]),
              ),
              bottom: const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.today)),
                  Tab(icon: Icon(Icons.calendar_view_week)),
                  Tab(icon: Icon(Icons.schedule)),
                  Tab(icon: Icon(Icons.list)),
                  Tab(icon: Icon(Icons.archive)),
                ],
              ),
              actions: [
                PopupMenuButton<TaskSortOption>(
                  icon: const Icon(Icons.sort),
                  onSelected: (option) {
                    setState(() {
                      _sortOption = option;
                    });
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: TaskSortOption.dueSoonest,
                      child: Text("Due Date (Soonest)"),
                    ),
                    const PopupMenuItem(
                      value: TaskSortOption.dueLatest,
                      child: Text("Due Date (Latest)"),
                    ),
                    const PopupMenuItem(
                      value: TaskSortOption.alphabeticalAZ,
                      child: Text("Title (A–Z)"),
                    ),
                    const PopupMenuItem(
                      value: TaskSortOption.alphabeticalZA,
                      child: Text("Title (Z–A)"),
                    ),
                    const PopupMenuItem(
                      value: TaskSortOption.category,
                      child: Text("Category"),
                    ),
                    const PopupMenuItem(
                      value: TaskSortOption.creationDateNewest,
                      child: Text("Creation Date (Newest)"),
                    ),
                    const PopupMenuItem(
                      value: TaskSortOption.creationDateOldest,
                      child: Text("Creation Date (Oldest)"),
                    ),
                  ],
                ),
              ],
            ),
            body: TabBarView(
              children: [
                _ActiveList(
                  box: tasksBox,
                  filter: () => _filterActiveTasksFor(0),
                  onCheckAndArchive: (task) async {
                    await _completeAndArchive(task);
                  },
                  onEdit: _editTask,
                  darkMode: isDark,
                ),
                _ActiveList(
                  box: tasksBox,
                  filter: () => _filterActiveTasksFor(1),
                  onCheckAndArchive: (task) async {
                    await _completeAndArchive(task);
                  },
                  onEdit: _editTask,
                  darkMode: isDark,
                ),
                _ActiveList(
                  box: tasksBox,
                  filter: () => _filterActiveTasksFor(2),
                  onCheckAndArchive: (task) async {
                    await _completeAndArchive(task);
                  },
                  onEdit: _editTask,
                  darkMode: isDark,
                ),
                _ActiveList(
                  box: tasksBox,
                  filter: () => _filterActiveTasksFor(3),
                  onCheckAndArchive: (task) async {
                    await _completeAndArchive(task);
                  },
                  onEdit: _editTask,
                  darkMode: isDark,
                ),
                _ArchiveList(
                  archiveBox: archiveBox,
                  onUndo: _restoreTask,
                  darkMode: isDark,
                  sortOption: _sortOption,
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              heroTag: "tasksFab",
              onPressed: _createTask,
              child: const Icon(Icons.add),
            ),
          );
        },
      ),
    );
  }
}

// =================== ACTIVE LIST ===================

class _ActiveList extends StatefulWidget {
  const _ActiveList({
    required this.box,
    required this.filter,
    required this.onCheckAndArchive,
    this.isArchive = false,
    required this.onEdit,
    required this.darkMode,
  });

  final Box<Task> box;
  final List<Task> Function() filter;
  final bool isArchive;
  final Future<void> Function(Task task) onCheckAndArchive;
  final void Function(int indexInBox, Task task) onEdit;
  final bool darkMode;

  @override
  State<_ActiveList> createState() => _ActiveListState();
}

class _ActiveListState extends State<_ActiveList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _holdController;
  int? _holdingIndex;
  int? _completingIndex;

  @override
  void initState() {
    super.initState();
    _holdController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _holdController.addStatusListener((status) async {
      if (status == AnimationStatus.completed && _holdingIndex != null) {
        // Use the same order as currently displayed (already sorted upstream)
        final tasks = widget.filter();

        if (_holdingIndex! < tasks.length) {
          final task = tasks[_holdingIndex!];
          setState(() => _completingIndex = _holdingIndex);
          await Future.delayed(const Duration(milliseconds: 200));
          await widget.onCheckAndArchive(task);
        }
        _resetHold();
      }
      if (status == AnimationStatus.dismissed) {
        setState(() => _holdingIndex = null);
      }
    });
  }

  void _resetHold() {
    _holdController.reset();
    setState(() {
      _holdingIndex = null;
      _completingIndex = null;
    });
  }

  @override
  void dispose() {
    _holdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.darkMode ? Colors.deepPurple[700]! : Colors.white;

    return ValueListenableBuilder(
      valueListenable: widget.box.listenable(),
      builder: (context, Box<Task> b, _) {
        final tasks = widget.filter().toList();

        if (tasks.isEmpty) {
          return const Center(child: Text('No tasks in this category'));
        }

        return ListView.builder(
          itemCount: tasks.length,
          itemBuilder: (context, i) {
            final task = tasks[i];
            final indexInBox = b.values.toList().indexOf(task);
            final bool isHolding = _holdingIndex == i;
            final bool isCompleting = _completingIndex == i;

            return Dismissible(
              key: Key('active_${task.key}'),
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
                  widget.onEdit(indexInBox, task);
                  return false;
                } else {
                  await NotificationsHelper.cancelTaskReminder(task);
                  await task.delete();
                  return true;
                }
              },
              child: GestureDetector(
                onLongPressStart: (_) {
                  setState(() {
                    _holdingIndex = i;
                    _completingIndex = null;
                  });
                  _holdController.forward(from: 0);
                },
                onLongPressEnd: (_) {
                  if (_holdController.value < 1.0) {
                    _holdController.reverse();
                  }
                },
                child: AnimatedBuilder(
                  animation: _holdController,
                  builder: (context, child) {
                    final isThisAnimating = isHolding;
                    final scale = isThisAnimating
                        ? (1.0 + 0.05 * _holdController.value)
                        : 1.0;

                    return Transform.scale(
                      scale: scale,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: baseColor,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // quick tap icon (short strike-through then complete+archive)
                                IconButton(
                                  iconSize: 28,
                                  splashRadius: 22,
                                  icon: Icon(
                                    Icons.circle_outlined,
                                    color: Colors.grey[600],
                                  ),
                                  onPressed: () async {
                                    setState(() => _completingIndex = i);
                                    await Future.delayed(
                                      const Duration(milliseconds: 180),
                                    );
                                    await widget.onCheckAndArchive(task);
                                    setState(() => _completingIndex = null);
                                  },
                                ),
                                const SizedBox(width: 4),
                                // title + optional description + SUBTASKS
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      AnimatedDefaultTextStyle(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        style: TextStyle(
                                          fontSize: 16,
                                          decoration:
                                              (isHolding &&
                                                      _holdController.value >
                                                          0.2) ||
                                                  isCompleting
                                              ? TextDecoration.lineThrough
                                              : TextDecoration.none,
                                          color:
                                              (isHolding &&
                                                      _holdController.value >
                                                          0.2) ||
                                                  isCompleting
                                              ? Colors.grey
                                              : (widget.darkMode
                                                    ? Colors.white
                                                    : Colors.black87),
                                        ),
                                        child: Text(task.title),
                                      ),
                                      if ((task.description ?? '').isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4.0,
                                          ),
                                          child: Text(
                                            task.description!,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: widget.darkMode
                                                  ? Colors.white70
                                                  : Colors.black54,
                                            ),
                                          ),
                                        ),
                                      // ----- Category (NEW) -----
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 2.0,
                                        ),
                                        child: Text(
                                          task.category,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.secondary,
                                          ),
                                        ),
                                      ),

                                      // ------- SUBTASKS -------
                                      if (task.subtasks.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: task.subtasks.asMap().entries.map((
                                            entry,
                                          ) {
                                            final idx = entry.key;
                                            final sub = entry.value;
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 2,
                                              ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  // small checkbox
                                                  Checkbox(
                                                    value: sub.completed,
                                                    onChanged: (val) {
                                                      setState(() {
                                                        task.setSubtaskCompleted(
                                                          idx,
                                                          val ?? false,
                                                        );
                                                      });
                                                    },
                                                    materialTapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      sub.title,
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        decoration:
                                                            sub.completed
                                                            ? TextDecoration
                                                                  .lineThrough
                                                            : null,
                                                        color: widget.darkMode
                                                            ? (sub.completed
                                                                  ? Colors
                                                                        .white60
                                                                  : Colors
                                                                        .white70)
                                                            : (sub.completed
                                                                  ? Colors
                                                                        .black45
                                                                  : Colors
                                                                        .black87),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // date pill
                                Text(
                                  (() {
                                    final d = task.dueDate;
                                    if (d == null) return '--/--';
                                    return '${d.month}/${d.day}';
                                  })(),
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          // center progress ring during hold
                          if (isHolding)
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                value: _holdController.value,
                                strokeWidth: 3,
                                color: Colors.green,
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
    );
  }
}

// =================== ARCHIVE LIST ===================

class _ArchiveList extends StatefulWidget {
  const _ArchiveList({
    required this.archiveBox,
    required this.onUndo,
    required this.darkMode,
    required this.sortOption,
  });

  final Box<Task> archiveBox;
  final Future<void> Function(Task task) onUndo;
  final bool darkMode;
  final TaskSortOption sortOption;

  @override
  State<_ArchiveList> createState() => _ArchiveListState();
}

class _ArchiveListState extends State<_ArchiveList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _holdController;
  int? _holdingIndex;
  int? _undoingIndex;

  @override
  void initState() {
    super.initState();
    _holdController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _holdController.addStatusListener((status) async {
      if (status == AnimationStatus.completed && _holdingIndex != null) {
        final box = widget.archiveBox;
        if (_holdingIndex! < box.length) {
          final task = box.getAt(_holdingIndex!)!;
          setState(() => _undoingIndex = _holdingIndex);
          await Future.delayed(const Duration(milliseconds: 200));
          await widget.onUndo(task);
        }
        _resetHold();
      }
      if (status == AnimationStatus.dismissed) {
        setState(() => _holdingIndex = null);
      }
    });
  }

  void _resetHold() {
    _holdController.reset();
    setState(() {
      _holdingIndex = null;
      _undoingIndex = null;
    });
  }

  @override
  void dispose() {
    _holdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.darkMode ? Colors.deepPurple[700]! : Colors.white;

    return ValueListenableBuilder(
      valueListenable: widget.archiveBox.listenable(),
      builder: (context, Box<Task> box, _) {
        if (box.isEmpty) {
          return const Center(child: Text('Archive is empty'));
        }
        final archivedTasks = box.values.toList()
          ..sort((a, b) {
            switch (widget.sortOption) {
              case TaskSortOption.dueSoonest:
                return (a.dueDate ?? DateTime(2100)).compareTo(
                  b.dueDate ?? DateTime(2100),
                );
              case TaskSortOption.dueLatest:
                return (b.dueDate ?? DateTime(0)).compareTo(
                  a.dueDate ?? DateTime(0),
                );
              case TaskSortOption.alphabeticalAZ:
                return a.title.toLowerCase().compareTo(b.title.toLowerCase());
              case TaskSortOption.alphabeticalZA:
                return b.title.toLowerCase().compareTo(a.title.toLowerCase());
              case TaskSortOption.category:
                return a.category.toLowerCase().compareTo(
                  b.category.toLowerCase(),
                );
              case TaskSortOption.creationDateNewest:
                return (b.key as int).compareTo(a.key as int);
              case TaskSortOption.creationDateOldest:
                return (a.key as int).compareTo(b.key as int);
            }
          });

        return ListView.builder(
          itemCount: archivedTasks.length,
          itemBuilder: (context, index) {
            final task = archivedTasks[index];
            final isHolding = _holdingIndex == index;
            final isUndoing = _undoingIndex == index;

            return Dismissible(
              key: Key('archived_${task.key}'),
              background: Container(
                color: Colors.green,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const Icon(Icons.undo, color: Colors.white),
              ),
              secondaryBackground: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const Icon(Icons.delete_forever, color: Colors.white),
              ),
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.startToEnd) {
                  await widget.onUndo(task);
                  return true;
                } else {
                  await task.delete();
                  return true;
                }
              },
              child: GestureDetector(
                onLongPressStart: (_) {
                  setState(() {
                    _holdingIndex = index;
                    _undoingIndex = null;
                  });
                  _holdController.forward(from: 0);
                },
                onLongPressEnd: (_) {
                  if (_holdController.value < 1.0) {
                    _holdController.reverse();
                  }
                },
                child: AnimatedBuilder(
                  animation: _holdController,
                  builder: (context, child) {
                    final isThisAnimating = isHolding;
                    final scale = isThisAnimating
                        ? (1.0 + 0.05 * _holdController.value)
                        : 1.0;

                    return Transform.scale(
                      scale: scale,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: baseColor,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Undo (tap) control
                                IconButton(
                                  iconSize: 28,
                                  splashRadius: 22,
                                  icon: Icon(
                                    Icons.check_circle,
                                    color: Colors.grey[600],
                                  ),
                                  onPressed: () async {
                                    setState(() => _undoingIndex = index);
                                    await Future.delayed(
                                      const Duration(milliseconds: 180),
                                    );
                                    await widget.onUndo(task);
                                    setState(() => _undoingIndex = null);
                                  },
                                  tooltip: 'Restore',
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      AnimatedDefaultTextStyle(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        style: TextStyle(
                                          fontSize: 16,
                                          decoration:
                                              TextDecoration.lineThrough,
                                          color: isUndoing
                                              ? (widget.darkMode
                                                    ? Colors.white70
                                                    : Colors.black54)
                                              : Colors.grey,
                                        ),
                                        child: Text(task.title),
                                      ),
                                      if ((task.description ?? '').isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4.0,
                                          ),
                                          child: Text(
                                            task.description!,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: widget.darkMode
                                                  ? Colors.white70
                                                  : Colors.black54,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.archive, color: Colors.grey),
                              ],
                            ),
                          ),
                          if (isHolding)
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                value: _holdController.value,
                                strokeWidth: 3,
                                color: Colors.orange,
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
    );
  }
}
