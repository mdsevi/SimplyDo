// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TaskAdapter extends TypeAdapter<Task> {
  @override
  final int typeId = 0;

  @override
  Task read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Task(
      title: fields[0] as String,
      description: fields[1] as String?,
      subtasks: (fields[2] as List).cast<SubTask>(),
      completed: fields[3] == null ? false : fields[3] as bool,
      rewardExp: fields[4] == null ? 0 : fields[4] as int,
      rewardCoins: fields[5] == null ? 0 : fields[5] as int,
      dueDateEpoch: fields[6] as int?,
      difficulty: fields[7] == null ? 0 : fields[7] as int,
      lastDamageEpoch: fields[8] == null ? 0 : fields[8] as int,
      reminderMinutesBefore: fields[9] as int?,
      category: fields[10] as String,
      repeat: fields[11] as TaskRepeat?,
    );
  }

  @override
  void write(BinaryWriter writer, Task obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.description)
      ..writeByte(2)
      ..write(obj.subtasks)
      ..writeByte(3)
      ..write(obj.completed)
      ..writeByte(4)
      ..write(obj.rewardExp)
      ..writeByte(5)
      ..write(obj.rewardCoins)
      ..writeByte(6)
      ..write(obj.dueDateEpoch)
      ..writeByte(7)
      ..write(obj.difficulty)
      ..writeByte(8)
      ..write(obj.lastDamageEpoch)
      ..writeByte(9)
      ..write(obj.reminderMinutesBefore)
      ..writeByte(10)
      ..write(obj.category)
      ..writeByte(11)
      ..write(obj.repeat);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SubTaskAdapter extends TypeAdapter<SubTask> {
  @override
  final int typeId = 4;

  @override
  SubTask read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SubTask(
      title: fields[0] as String,
      completed: fields[1] == null ? false : fields[1] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, SubTask obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.completed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubTaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TaskRepeatAdapter extends TypeAdapter<TaskRepeat> {
  @override
  final int typeId = 5;

  @override
  TaskRepeat read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TaskRepeat(
      type: fields[0] as RepeatType,
      interval: fields[1] as int?,
      weekday: fields[2] as int?,
      monthDay: fields[3] as int?,
      month: fields[4] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, TaskRepeat obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.type)
      ..writeByte(1)
      ..write(obj.interval)
      ..writeByte(2)
      ..write(obj.weekday)
      ..writeByte(3)
      ..write(obj.monthDay)
      ..writeByte(4)
      ..write(obj.month);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskRepeatAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RepeatTypeAdapter extends TypeAdapter<RepeatType> {
  @override
  final int typeId = 6;

  @override
  RepeatType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return RepeatType.none;
      case 1:
        return RepeatType.daily;
      case 2:
        return RepeatType.weekly;
      case 3:
        return RepeatType.monthly;
      case 4:
        return RepeatType.yearly;
      case 5:
        return RepeatType.custom;
      default:
        return RepeatType.none;
    }
  }

  @override
  void write(BinaryWriter writer, RepeatType obj) {
    switch (obj) {
      case RepeatType.none:
        writer.writeByte(0);
        break;
      case RepeatType.daily:
        writer.writeByte(1);
        break;
      case RepeatType.weekly:
        writer.writeByte(2);
        break;
      case RepeatType.monthly:
        writer.writeByte(3);
        break;
      case RepeatType.yearly:
        writer.writeByte(4);
        break;
      case RepeatType.custom:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RepeatTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
