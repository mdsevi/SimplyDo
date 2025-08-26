import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../extra/categories.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AddHabitPage extends StatefulWidget {
  final Function(Habit) onAdd;

  const AddHabitPage({super.key, required this.onAdd});

  @override
  State<AddHabitPage> createState() => _AddHabitPageState();
}

class _AddHabitPageState extends State<AddHabitPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  int _timesPerDay = 1;
  TimeOfDay? _habitTime;
  String _selectedCategory = "Others"; // 🏷️ Default category
  String _selectedDifficulty = "Easy"; // 🎚️ Default difficulty

  void _pickTime() async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: _habitTime ?? now,
    );
    if (picked != null) {
      setState(() {
        _habitTime = picked;
      });
    }
  }

  void _saveHabit() {
    if (_nameController.text.isEmpty) return;

    final newHabit = Habit(
      name: _nameController.text,
      description: _descController.text,
      streak: 0,
      timesPerDay: _timesPerDay,
      habitTimeMinutes: _habitTime == null
          ? null
          : (_habitTime!.hour * 60 + _habitTime!.minute),
      category: _selectedCategory,
      difficulty: _selectedDifficulty, // 🎚️ Save difficulty
    );

    final habitBox = Hive.box<Habit>('habits');
    habitBox.add(newHabit);

    widget.onAdd(newHabit);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add New Habit")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Habit Name"),
              ),
              TextField(
                controller: _descController,
                decoration: const InputDecoration(labelText: "Description"),
              ),
              const SizedBox(height: 20),

              // 🏷️ Category Dropdown
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(labelText: "Category"),
                items: Categories.all.map((cat) {
                  return DropdownMenuItem(value: cat, child: Text(cat));
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedCategory = val!;
                  });
                },
              ),

              const SizedBox(height: 20),

              // 🎚️ Difficulty Dropdown
              DropdownButtonFormField<String>(
                value: _selectedDifficulty,
                decoration: const InputDecoration(labelText: "Difficulty"),
                items: ["Easy", "Medium", "Hard"].map((diff) {
                  return DropdownMenuItem(value: diff, child: Text(diff));
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedDifficulty = val!;
                  });
                },
              ),

              const SizedBox(height: 20),

              // 🔁 Times per day
              Row(
                children: [
                  const Text("Times per day:", style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.remove_circle),
                    onPressed: () {
                      setState(() {
                        if (_timesPerDay > 1) _timesPerDay--;
                      });
                    },
                  ),
                  Text(
                    "$_timesPerDay",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle),
                    onPressed: () {
                      setState(() {
                        _timesPerDay++;
                      });
                    },
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ⏰ Habit Time
              Row(
                children: [
                  const Text("Habit Time:", style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time),
                    label: Text(
                      _habitTime == null
                          ? "Pick Time"
                          : _habitTime!.format(context),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: _saveHabit,
                  child: const Text("Add Habit"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
