import 'package:hive/hive.dart';

part 'shop_item.g.dart';

/// type: 'potion' or 'reward'
/// - If potion: You may set either:
///   a) healAmount (for Health Potion), OR
///   b) boostStat + boostAmount + boostDays (timed stat boost)
@HiveType(typeId: 3)
class ShopItem extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  int price;

  @HiveField(2)
  String type; // 'potion' | 'reward'

  @HiveField(3)
  String? description;

  // Potion: healing
  @HiveField(4)
  int? healAmount;

  // Potion: timed stat boost
  @HiveField(5)
  String? boostStat; // 'vitality' | 'intelligence' | 'luck'
  @HiveField(6)
  int? boostAmount;
  @HiveField(7)
  int? boostDays;

  ShopItem({
    required this.name,
    required this.price,
    required this.type,
    this.description,
    this.healAmount,
    this.boostStat,
    this.boostAmount,
    this.boostDays,
  });
}
