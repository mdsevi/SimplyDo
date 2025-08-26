import 'package:hive/hive.dart';
import '../models/task.dart';

class TaskService {
  final Box<Task> taskBox;

  TaskService(this.taskBox);

  Future<void> addTask({
    required String title,
    String? description,
    List<SubTask> subtasks = const [],
    int difficulty = 0,
    String category = "Others",
    int? rewardExp,
    int? rewardCoins,
    int? dueDateEpoch,
    int? reminderMinutesBefore,
    TaskRepeat? repeat,
  }) async {
    final task = Task(
      title: title,
      description: subtasks.isEmpty ? description : null,
      subtasks: subtasks,
      difficulty: difficulty,
      category: category,
      rewardExp: rewardExp ?? 0,
      rewardCoins: rewardCoins ?? 0,
      dueDateEpoch: dueDateEpoch,
      reminderMinutesBefore: reminderMinutesBefore,
      repeat: repeat ?? TaskRepeat(type: RepeatType.none),
    );

    await taskBox.add(task);

    // If reminder is set, schedule notification
    await task.scheduleReminder();
  }
}
