// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProfileAdapter extends TypeAdapter<Profile> {
  @override
  final int typeId = 2;

  @override
  Profile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Profile(
      username: fields[0] as String,
      experience: fields[1] as int,
      coins: fields[2] as int,
      level: fields[3] as int,
      health: fields[4] as int,
      avatarPath: fields[5] as String?,
      vitality: fields[6] == null ? 0 : fields[6] as int,
      intelligence: fields[7] == null ? 0 : fields[7] as int,
      luck: fields[8] == null ? 0 : fields[8] as int,
      unspentSkillPoints: fields[9] == null ? 0 : fields[9] as int,
    );
  }

  @override
  void write(BinaryWriter writer, Profile obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.username)
      ..writeByte(1)
      ..write(obj.experience)
      ..writeByte(2)
      ..write(obj.coins)
      ..writeByte(3)
      ..write(obj.level)
      ..writeByte(4)
      ..write(obj.health)
      ..writeByte(5)
      ..write(obj.avatarPath)
      ..writeByte(6)
      ..write(obj.vitality)
      ..writeByte(7)
      ..write(obj.intelligence)
      ..writeByte(8)
      ..write(obj.luck)
      ..writeByte(9)
      ..write(obj.unspentSkillPoints);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
