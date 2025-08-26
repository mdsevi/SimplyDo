import 'package:hive/hive.dart';
import '../character/profile.dart';
import '../extra/categories.dart';
import 'package:flutter/material.dart';

part 'habit.g.dart';

@HiveType(typeId: 1)
class Habit extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  String description;

  @HiveField(2, defaultValue: null)
  int? lastCompletedEpoch;

  DateTime? get lastCompleted => lastCompletedEpoch == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(lastCompletedEpoch!);

  set lastCompleted(DateTime? dt) {
    lastCompletedEpoch = dt?.millisecondsSinceEpoch;
  }

  @HiveField(3, defaultValue: "Easy")
  String difficulty;

  @HiveField(4, defaultValue: 0)
  int streak;

  @HiveField(5, defaultValue: false)
  bool isCompleted;

  @HiveField(6, defaultValue: 0)
  int lastExpReward;

  @HiveField(7, defaultValue: 0)
  int lastCoinReward;

  @HiveField(8, defaultValue: 1)
  int timesPerDay;

  @HiveField(9, defaultValue: 0)
  int completionsToday;

  /// Category (shared with Tasks)
  @HiveField(10, defaultValue: "Others")
  String category;

  /// Preferred time of day for this habit (stored as minutes since midnight)
  @HiveField(11)
  int? habitTimeMinutes;

  /// Reminder before habit time (e.g. 15min before)
  @HiveField(12)
  int? reminderMinutesBefore;

  /// Creation date for sorting/filtering
  @HiveField(13)
  DateTime createdAt;

  /// Get habit time as DateTime (today's date + stored minutes)
  DateTime? get habitTime {
    if (habitTimeMinutes == null) return null;
    final now = DateTime.now();
    final hours = habitTimeMinutes! ~/ 60;
    final minutes = habitTimeMinutes! % 60;
    return DateTime(now.year, now.month, now.day, hours, minutes);
  }

  set habitTime(DateTime? dt) {
    if (dt == null) {
      habitTimeMinutes = null;
    } else {
      habitTimeMinutes = dt.hour * 60 + dt.minute;
    }
  }

  /// Get reminder time (habitTime - reminderMinutesBefore)
  DateTime? get reminderDate {
    if (habitTime == null || reminderMinutesBefore == null) return null;
    return habitTime!.subtract(Duration(minutes: reminderMinutesBefore!));
  }

  /// Get habit time as a TimeOfDay (for UI display)
  TimeOfDay? get habitTimeOfDay {
    if (habitTimeMinutes == null) return null;
    final hours = habitTimeMinutes! ~/ 60;
    final minutes = habitTimeMinutes! % 60;
    return TimeOfDay(hour: hours, minute: minutes);
  }

  Habit({
    required this.name,
    required this.description,
    this.lastCompletedEpoch,
    this.difficulty = "Easy",
    this.streak = 0,
    this.isCompleted = false,
    this.lastExpReward = 0,
    this.lastCoinReward = 0,
    this.timesPerDay = 1,
    this.completionsToday = 0,
    this.category = "Others",
    this.habitTimeMinutes,
    this.reminderMinutesBefore,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Completing a habit grants rewards to the profile
  void complete(Profile profile) {
    if (completionsToday < timesPerDay) {
      completionsToday++;
      isCompleted = completionsToday >= timesPerDay;
      streak = isCompleted ? streak + 1 : streak;
      lastCompleted = DateTime.now();

      // --- Base rewards ---
      int baseExp;
      int baseCoins;

      switch (difficulty) {
        case "Easy":
          baseExp = 5;
          baseCoins = 3;
          break;
        case "Medium":
          baseExp = 10;
          baseCoins = 5;
          break;
        case "Hard":
          baseExp = 20;
          baseCoins = 10;
          break;
        default:
          baseExp = 5;
          baseCoins = 3;
      }

      // Rewards automatically scaled by INT / LCK inside profile.addRewards
      profile.addRewards(baseExp, baseCoins);

      lastExpReward = baseExp;
      lastCoinReward = baseCoins;

      save();
    }
  }

  /// Undo completion (decrement progress)
  void undoComplete() {
    if (completionsToday > 0) {
      completionsToday--;
      isCompleted = false;
      if (streak > 0 && completionsToday == 0) streak--;
      save();
    }
  }

  /// Resets today's progress. If incomplete, applies scaled damage to profile.
  void resetDay(Profile profile) {
    if (!isCompleted) {
      int baseDmg;
      switch (difficulty) {
        case "Easy":
          baseDmg = 10;
          break;
        case "Medium":
          baseDmg = 6;
          break;
        case "Hard":
          baseDmg = 3;
          break;
        default:
          baseDmg = 5;
      }

      // --- Vitality reduces damage taken (5% per point, capped at 80%) ---
      final vit = profile.vitality;
      final reduction = (vit * 0.05).clamp(0, 0.8); // max 80% reduction
      final dmg = (baseDmg * (1 - reduction)).round();
      final actual = dmg < 1 && baseDmg > 0
          ? 1
          : dmg; // ensure at least 1 if base > 0

      profile.takeDamage(actual);
    }

    completionsToday = 0;
    isCompleted = false;
    lastCompleted = null;
    if (streak > 0) streak--;
    lastExpReward = 0;
    lastCoinReward = 0;
    save();
  }
}
