import 'package:hive/hive.dart';

import '../models/task.dart';
import '../models/habit.dart';
import '../models/shop_item.dart';

part 'profile.g.dart';

@HiveType(typeId: 2)
class Profile extends HiveObject {
  @HiveField(0)
  String username;

  @HiveField(1)
  int experience;

  @HiveField(2)
  int coins;

  @HiveField(3)
  int level;

  @HiveField(4)
  int health;

  @HiveField(5)
  String? avatarPath;

  // --- RPG stats ---
  @HiveField(6, defaultValue: 0)
  int vitality; // boosts max HP

  @HiveField(7, defaultValue: 0)
  int intelligence; // boosts EXP gain

  @HiveField(8, defaultValue: 0)
  int luck; // boosts coin gain

  @HiveField(9, defaultValue: 0)
  int unspentSkillPoints;

  Profile({
    required this.username,
    required this.experience,
    required this.coins,
    required this.level,
    required this.health,
    this.avatarPath,
    this.vitality = 0,
    this.intelligence = 0,
    this.luck = 0,
    this.unspentSkillPoints = 0,
  });

  // --- Derived values ---
  int get maxHealth => 100 + 5 * vitality;
  bool get isDead => health <= 0;

  // --- Rewards / Leveling ---
  void addRewards(int baseExp, int baseCoins) {
    final exp = (baseExp * (1 + intelligence * 0.05)).round();
    final coinsGained = (baseCoins * (1 + luck * 0.05)).round();

    experience += exp;
    coins += coinsGained;

    _handleLevelUps();
    save();
  }

  void removeRewards(int exp, int coinsLost) {
    experience = (experience - exp).clamp(0, experience);
    coins = (coins - coinsLost).clamp(0, coins);
    save();
  }

  void takeDamage(int amount) {
    health -= amount;
    if (health < 0) health = 0;
    save();
  }

  // --- Leveling ---
  void _handleLevelUps() {
    while (experience >= _xpForNextLevel() && level < 30) {
      experience -= _xpForNextLevel();
      level++;
      if (level > 1) unspentSkillPoints++;
      health = maxHealth; // restore on level up
    }
  }

  int _xpForNextLevel() {
    if (level >= 30) return 9999999;
    return 100 + (level - 1) * 20;
  }

  // --- Skill Points ---
  void increaseVitality() {
    if (unspentSkillPoints > 0 && vitality < 10) {
      vitality++;
      unspentSkillPoints--;
      health = maxHealth;
      save();
    }
  }

  void increaseIntelligence() {
    if (unspentSkillPoints > 0 && intelligence < 10) {
      intelligence++;
      unspentSkillPoints--;
      save();
    }
  }

  void increaseLuck() {
    if (unspentSkillPoints > 0 && luck < 10) {
      luck++;
      unspentSkillPoints--;
      save();
    }
  }

  // --- Death Reset (only stats) ---
  // --- Full Reset (stats, level, coins, avatar) ---
  Future<void> resetStats() async {
    experience = 0;
    coins = 0;
    level = 1;

    vitality = 0;
    intelligence = 0;
    luck = 0;
    unspentSkillPoints = 0;

    health = maxHealth;
    await save();
  }
}
