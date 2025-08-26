import 'dart:math';
import 'package:hive/hive.dart';
import '../character/profile.dart';
import '../extra/categories.dart';
import '../utilities/notifications_helper.dart';

part 'task.g.dart';

@HiveType(typeId: 0)
class Task extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  String? description;

  @HiveField(2)
  List<SubTask> subtasks;

  @HiveField(3, defaultValue: false)
  bool completed;

  @HiveField(4, defaultValue: 0)
  int rewardExp;

  @HiveField(5, defaultValue: 0)
  int rewardCoins;

  @HiveField(6)
  int? dueDateEpoch;

  DateTime? get dueDate => dueDateEpoch == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(dueDateEpoch!);

  set dueDate(DateTime? dt) {
    dueDateEpoch = dt?.millisecondsSinceEpoch;
  }

  @HiveField(7, defaultValue: 0)
  int difficulty;

  String get difficultyLabel {
    switch (difficulty) {
      case 1:
        return "Medium";
      case 2:
        return "Hard";
      default:
        return "Easy";
    }
  }

  @HiveField(8, defaultValue: 0)
  int lastDamageEpoch = 0;

  @HiveField(9)
  int? reminderMinutesBefore;

  DateTime? get reminderDate {
    if (dueDate == null || reminderMinutesBefore == null) return null;
    return dueDate!.subtract(Duration(minutes: reminderMinutesBefore!));
  }

  /// Category
  @HiveField(10)
  String category;

  /// Repeat info
  @HiveField(11)
  TaskRepeat? repeat;

  Task({
    required this.title,
    this.description,
    this.subtasks = const [],
    this.completed = false,
    this.rewardExp = 0,
    this.rewardCoins = 0,
    this.dueDateEpoch,
    this.difficulty = 0,
    this.lastDamageEpoch = 0,
    this.reminderMinutesBefore,
    this.category = "Others",
    TaskRepeat? repeat,
  }) : repeat = repeat ?? TaskRepeat(type: RepeatType.none);

  // ---------- Existing methods ----------
  bool get isSubtaskBased => subtasks.isNotEmpty;

  bool get isComplete =>
      isSubtaskBased ? subtasks.every((s) => s.completed) : completed;

  int get completedSubtasks => subtasks.where((s) => s.completed).length;

  double get progress => subtasks.isEmpty
      ? (completed ? 1.0 : 0.0)
      : completedSubtasks / subtasks.length;

  void toggleComplete() {
    if (isSubtaskBased) {
      if (subtasks.every((s) => s.completed)) {
        completed = true;
      }
    } else {
      completed = !completed;
    }
    save();
  }

  void undoComplete() {
    if (isSubtaskBased) {
      for (final s in subtasks) {
        s.completed = false;
      }
    }
    completed = false;
    save();
  }

  void addSubtask(String title, {bool completed = false}) {
    subtasks = List<SubTask>.from(subtasks)
      ..add(SubTask(title: title, completed: completed));
    _syncCompletedFromSubtasks();
    save();
  }

  void removeSubtaskAt(int index) {
    if (index < 0 || index >= subtasks.length) return;
    subtasks = List<SubTask>.from(subtasks)..removeAt(index);
    _syncCompletedFromSubtasks();
    save();
  }

  void toggleSubtask(int index) {
    if (index < 0 || index >= subtasks.length) return;
    final s = subtasks[index];
    s.completed = !s.completed;
    _syncCompletedFromSubtasks();
    save();
  }

  void setSubtaskCompleted(int index, bool value) {
    if (index < 0 || index >= subtasks.length) return;
    subtasks[index].completed = value;
    _syncCompletedFromSubtasks();
    save();
  }

  void _syncCompletedFromSubtasks() {
    if (subtasks.isNotEmpty) {
      completed = subtasks.every((s) => s.completed);
    }
  }

  // ---------- Rewards ----------
  void complete(Profile profile) {
    if (isComplete) return;

    if (isSubtaskBased) {
      for (final s in subtasks) {
        s.completed = true;
      }
    }
    completed = true;

    profile.addRewards(rewardExp, rewardCoins);

    save();
  }

  int getOverdueDamage(Profile profile) {
    if (isComplete || dueDate == null) return 0;

    final now = DateTime.now();
    if (now.isBefore(dueDate!)) return 0;

    final overdueDays = now.difference(dueDate!).inDays + 1;
    final baseDmg = (5 * (pow(2, overdueDays) - 1)).toInt();

    final cappedBase = baseDmg > 25 ? 25 : baseDmg;

    // --- Vitality reduces damage taken (5% per point, capped at 80%) ---
    final vit = profile.vitality;
    final reduction = (vit * 0.05).clamp(0, 0.8); // up to 80% reduction
    final dmg = (cappedBase * (1 - reduction)).round();

    // Ensure at least 1 damage if base > 0
    return cappedBase > 0 && dmg < 1 ? 1 : dmg;
  }

  void applyOverdueDamage(Profile profile) {
    final todayMidnight = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final todayEpoch = todayMidnight.millisecondsSinceEpoch;

    if (todayEpoch <= lastDamageEpoch) return;

    final dmg = getOverdueDamage(profile);
    if (dmg > 0) {
      profile.takeDamage(dmg);
      lastDamageEpoch = todayEpoch;
      save();
    }
  }

  Future<void> scheduleReminder() async {
    final reminderDate = this.reminderDate;
    if (reminderDate != null) {
      await NotificationsHelper.scheduleTaskReminder(this);
    }
  }

  // ---------- Repeat Logic ----------
  void rescheduleIfRepeating() {
    if (repeat == null || dueDate == null) return;

    DateTime newDate = dueDate!;

    switch (repeat!.type) {
      case RepeatType.daily:
        newDate = dueDate!.add(Duration(days: repeat!.interval ?? 1));
        break;
      case RepeatType.weekly:
        final targetWeekday =
            repeat!.weekday ?? _toSundayBased(dueDate!.weekday);
        newDate = _nextSundayBasedWeekday(dueDate!, targetWeekday);
        break;
      case RepeatType.monthly:
        final targetDay = repeat!.monthDay ?? dueDate!.day;
        newDate = DateTime(dueDate!.year, dueDate!.month + 1, targetDay);
        break;
      case RepeatType.yearly:
        final month = repeat!.month ?? dueDate!.month;
        final day = repeat!.monthDay ?? dueDate!.day;
        newDate = DateTime(dueDate!.year + 1, month, day);
        break;
      case RepeatType.custom:
        if (repeat!.interval != null) {
          newDate = dueDate!.add(Duration(days: repeat!.interval!));
        }
        break;
      case RepeatType.none:
      default:
        return;
    }

    completed = false;
    for (var s in subtasks) {
      s.completed = false;
    }
    dueDate = newDate;
    save();
  }

  int _toSundayBased(int dartWeekday) => dartWeekday % 7;

  DateTime _nextSundayBasedWeekday(DateTime from, int targetWeekday) {
    final current = _toSundayBased(from.weekday);
    int daysToAdd = (targetWeekday - current) % 7;
    if (daysToAdd <= 0) daysToAdd += 7;
    return from.add(Duration(days: daysToAdd));
  }
}

@HiveType(typeId: 4)
class SubTask extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1, defaultValue: false)
  bool completed;

  SubTask({required this.title, this.completed = false});
}

@HiveType(typeId: 5)
class TaskRepeat extends HiveObject {
  @HiveField(0)
  RepeatType type;

  @HiveField(1)
  int? interval;

  @HiveField(2)
  int? weekday; // 0 = Sunday, 6 = Saturday

  @HiveField(3)
  int? monthDay;

  @HiveField(4)
  int? month;

  TaskRepeat({
    required this.type,
    this.interval,
    this.weekday,
    this.monthDay,
    this.month,
  });
}

@HiveType(typeId: 6)
enum RepeatType {
  @HiveField(0)
  none,

  @HiveField(1)
  daily,

  @HiveField(2)
  weekly,

  @HiveField(3)
  monthly,

  @HiveField(4)
  yearly,

  @HiveField(5)
  custom,
}
