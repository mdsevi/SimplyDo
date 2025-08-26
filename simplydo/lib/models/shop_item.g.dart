// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shop_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ShopItemAdapter extends TypeAdapter<ShopItem> {
  @override
  final int typeId = 3;

  @override
  ShopItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ShopItem(
      name: fields[0] as String,
      price: fields[1] as int,
      type: fields[2] as String,
      description: fields[3] as String?,
      healAmount: fields[4] as int?,
      boostStat: fields[5] as String?,
      boostAmount: fields[6] as int?,
      boostDays: fields[7] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, ShopItem obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.price)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.healAmount)
      ..writeByte(5)
      ..write(obj.boostStat)
      ..writeByte(6)
      ..write(obj.boostAmount)
      ..writeByte(7)
      ..write(obj.boostDays);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShopItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
