// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HabitAdapter extends TypeAdapter<Habit> {
  @override
  final int typeId = 1;

  @override
  Habit read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Habit(
      name: fields[0] as String,
      description: fields[1] as String,
      lastCompletedEpoch: fields[2] as int?,
      difficulty: fields[3] == null ? 'Easy' : fields[3] as String,
      streak: fields[4] == null ? 0 : fields[4] as int,
      isCompleted: fields[5] == null ? false : fields[5] as bool,
      lastExpReward: fields[6] == null ? 0 : fields[6] as int,
      lastCoinReward: fields[7] == null ? 0 : fields[7] as int,
      timesPerDay: fields[8] == null ? 1 : fields[8] as int,
      completionsToday: fields[9] == null ? 0 : fields[9] as int,
      category: fields[10] == null ? 'Others' : fields[10] as String,
      habitTimeMinutes: fields[11] as int?,
      reminderMinutesBefore: fields[12] as int?,
      createdAt: fields[13] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Habit obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.description)
      ..writeByte(2)
      ..write(obj.lastCompletedEpoch)
      ..writeByte(3)
      ..write(obj.difficulty)
      ..writeByte(4)
      ..write(obj.streak)
      ..writeByte(5)
      ..write(obj.isCompleted)
      ..writeByte(6)
      ..write(obj.lastExpReward)
      ..writeByte(7)
      ..write(obj.lastCoinReward)
      ..writeByte(8)
      ..write(obj.timesPerDay)
      ..writeByte(9)
      ..write(obj.completionsToday)
      ..writeByte(10)
      ..write(obj.category)
      ..writeByte(11)
      ..write(obj.habitTimeMinutes)
      ..writeByte(12)
      ..write(obj.reminderMinutesBefore)
      ..writeByte(13)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HabitAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
