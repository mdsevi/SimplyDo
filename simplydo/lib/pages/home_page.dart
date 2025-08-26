import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../character/profile.dart';
import '../models/task.dart';
import '../models/habit.dart';
import '../extra/damage_ui.dart'; // popup
import '../utilities/game_over.dart'; // 👈 new import

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Box<Profile> profileBox;
  late Box settingsBox;
  late Box<Task> tasksBox;
  late Box<Habit> habitsBox;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    profileBox = Hive.box<Profile>('profileBox');
    settingsBox = Hive.box('settings');
    tasksBox = Hive.box<Task>('tasks');
    habitsBox = Hive.box<Habit>('habits');
    _loading = false;

    WidgetsBinding.instance.addPostFrameCallback((_) => _checkDailyDamage());
  }

  /// Calculate & apply overdue + incomplete-habit damage once per day.
  Future<void> _checkDailyDamage() async {
    final profile = profileBox.get('player');
    if (profile == null) return;

    final now = DateTime.now();
    final todayKey = "${now.year}-${now.month}-${now.day}";

    final lastApplied = settingsBox.get('lastDamageDay', defaultValue: "");
    if (lastApplied == todayKey) {
      debugPrint('[Damage] Skipped – already applied today ($todayKey).');
      return;
    }

    int overdueDamageTotal = 0;
    int habitDamageTotal = 0;

    final vit = profile.vitality;

    int scaledDamage(int base) {
      final reduction = 1 - (0.05 * vit);
      final reduced = (base * reduction).round();
      return reduced < 1 && base > 0 ? 1 : reduced;
    }

    // ----- Overdue Tasks Damage -----
    for (int i = 0; i < tasksBox.length; i++) {
      final t = await tasksBox.getAt(i); // Task? (nullable)

      if (t == null) continue; // skip if null

      final dmg = (t.getOverdueDamage(profile)).clamp(0, 9999);
      if (dmg > 0) {
        final actual = scaledDamage(dmg);
        profile.takeDamage(actual);
        overdueDamageTotal += actual;
        debugPrint(
          '[Damage] Task "${t.title}" -> -$actual HP (base $dmg, Vit $vit).',
        );
      }
    }

    // ----- Incomplete Habits Damage -----
    for (int i = 0; i < habitsBox.length; i++) {
      final h = habitsBox.getAt(i)!;
      final oldHp = profile.health;

      h.resetDay(profile); // handles damage + reset logic itself

      final lost = oldHp - profile.health;
      if (lost > 0) {
        habitDamageTotal += lost;
        debugPrint('[Damage] Habit "${h.name}" -> -$lost HP (via resetDay).');
      }
    }

    profile.save();

    final total = overdueDamageTotal + habitDamageTotal;

    settingsBox.put('lastDamageDay', todayKey);

    if (total > 0) {
      showDamagePopup(
        context,
        overdueDamage: overdueDamageTotal,
        habitDamage: habitDamageTotal,
      );
    } else {
      debugPrint('[Damage] No damage today ($todayKey).');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return ValueListenableBuilder(
      valueListenable: profileBox.listenable(keys: ['player']),
      builder: (context, Box<Profile> box, _) {
        final p = box.get('player');
        if (p == null) {
          return const Scaffold(body: Center(child: Text("No profile found")));
        }

        // --- Death Check ---
        if (p.isDead) {
          return GameOverPage(player: p); // ✅ fixed param name
        }

        if (p.health > p.maxHealth) {
          p.health = p.maxHealth;
          p.save();
        }

        final showTip = p.level < 2;

        return Scaffold(
          appBar: AppBar(title: const Text('Dashboard')),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Welcome, ${p.username}!',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _statCard('Level', p.level.toString(), Icons.star),
                      const SizedBox(width: 12),
                      _statCard(
                        'Coins',
                        p.coins.toString(),
                        Icons.monetization_on,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _statCard(
                        'EXP',
                        p.experience.toString(),
                        Icons.trending_up,
                      ),
                      const SizedBox(width: 12),
                      _statCard(
                        'Health',
                        '${p.health} / ${p.maxHealth}',
                        Icons.favorite,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Skills section
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 8,
                          color: Colors.black.withOpacity(0.05),
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.insights),
                            const SizedBox(width: 8),
                            Text(
                              'Skills',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const Spacer(),
                            Chip(
                              label: Text("Points: ${p.unspentSkillPoints}"),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _skillRow(
                          label: 'Vitality',
                          value: p.vitality,
                          onPlus: (p.unspentSkillPoints > 0 && p.vitality < 10)
                              ? () => setState(p.increaseVitality)
                              : null,
                        ),
                        _skillRow(
                          label: 'Intelligence',
                          value: p.intelligence,
                          onPlus:
                              (p.unspentSkillPoints > 0 && p.intelligence < 10)
                              ? () => setState(p.increaseIntelligence)
                              : null,
                        ),
                        _skillRow(
                          label: 'Luck',
                          value: p.luck,
                          onPlus: (p.unspentSkillPoints > 0 && p.luck < 10)
                              ? () => setState(p.increaseLuck)
                              : null,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (showTip)
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: const Text(
                        'Tip: complete tasks and habits to earn XP and coins!',
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Expanded _statCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              blurRadius: 8,
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }

  Widget _skillRow({
    required String label,
    required int value,
    VoidCallback? onPlus,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: LinearProgressIndicator(
              value: (value.clamp(0, 10)) / 10.0,
              minHeight: 10,
            ),
          ),
          const SizedBox(width: 12),
          Text(value.toString()),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onPlus,
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Spend point',
          ),
        ],
      ),
    );
  }
}
