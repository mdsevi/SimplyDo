import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../extra/categories.dart'; // Import your Categories list
import '../models/task.dart'; // <-- adjust path so TaskRepeat/RepeatType are available

class AddTaskPage extends StatefulWidget {
  final String? initialTitle;
  final String? initialNote;
  final DateTime? initialDate;
  final TimeOfDay? initialStart;
  final int? initialDifficulty;
  final List<String>? initialSubtasks;
  final String? initialCategory;
  final int? initialRemindIndex;
  final int? initialRepeatIndex;
  final int? initialWeeklyDay;
  final int? initialMonthlyDay;
  final DateTime? initialYearlyDate;
  final int? initialCustomInterval;

  final Future<void> Function(
    String title,
    String? note,
    DateTime date,
    TimeOfDay? start,
    int difficulty, {
    String category,
    int? customInterval,
    int? monthlyDay,
    int remindIndex,
    int repeatIndex,
    List<String>? subtasks,
    int? weeklyDay,
    DateTime? yearlyDate,
    TaskRepeat? repeat, // <-- wired in
  })
  onSubmit;

  final VoidCallback? onDelete;

  const AddTaskPage({
    super.key,
    required this.onSubmit,
    this.initialTitle,
    this.initialNote,
    this.initialDate,
    this.initialStart,
    this.initialDifficulty,
    this.initialSubtasks,
    this.initialCategory,
    this.initialRemindIndex,
    this.initialRepeatIndex,
    this.initialWeeklyDay,
    this.initialMonthlyDay,
    this.initialYearlyDate,
    this.initialCustomInterval,
    this.onDelete,
  });

  @override
  State<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage> {
  late TextEditingController _title;
  late TextEditingController _note;
  late DateTime _date;
  TimeOfDay? _start;
  int _difficulty = 0;
  int _remindIndex = 0;
  int _repeatIndex = 0;

  bool _useSubtasks = false;
  List<String> _subtasks = [];

  String _category = "Others";

  // repeat detail state
  int? _weeklyDay; // UI: 0=Mon ... 6=Sun
  int? _monthlyDay; // 1..31
  DateTime? _yearlyDate; // only month/day used
  int? _customInterval; // days

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initialTitle ?? '');
    _note = TextEditingController(text: widget.initialNote ?? '');
    _date = widget.initialDate ?? DateTime.now();
    _start = widget.initialStart;
    _difficulty = widget.initialDifficulty ?? 0;
    _subtasks = widget.initialSubtasks ?? [];
    _useSubtasks = _subtasks.isNotEmpty;
    _category = widget.initialCategory ?? "Others";
    _remindIndex = widget.initialRemindIndex ?? 0;
    _repeatIndex = widget.initialRepeatIndex ?? 0;

    _weeklyDay = widget.initialWeeklyDay;
    _monthlyDay = widget.initialMonthlyDay;
    _yearlyDate = widget.initialYearlyDate;
    _customInterval = widget.initialCustomInterval;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickStart() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _start ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _start = picked);
  }

  TaskRepeat? _buildRepeat() {
    switch (_repeatIndex) {
      case 1: // Daily
        return TaskRepeat(type: RepeatType.daily, interval: 1);
      case 2: // Weekly
        final sundayBased = _weeklyDay == null ? null : ((_weeklyDay! + 1) % 7);
        return TaskRepeat(type: RepeatType.weekly, weekday: sundayBased ?? 1);
      case 3: // Monthly
        return TaskRepeat(type: RepeatType.monthly, monthDay: _monthlyDay ?? 1);
      case 4: // Yearly
        if (_yearlyDate != null) {
          return TaskRepeat(
            type: RepeatType.yearly,
            month: _yearlyDate!.month,
            monthDay: _yearlyDate!.day,
          );
        }
        return TaskRepeat(
          type: RepeatType.yearly,
          month: DateTime.now().month,
          monthDay: DateTime.now().day,
        );
      case 5: // Custom (every N days)
        return TaskRepeat(
          type: RepeatType.custom,
          interval: _customInterval ?? 1,
        );
      default: // None
        return TaskRepeat(type: RepeatType.none);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.onDelete == null ? 'Add Task' : 'Edit Task'),
        actions: [
          if (widget.onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: widget.onDelete,
              tooltip: 'Delete',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          const Text('Title', style: TextStyle(fontWeight: FontWeight.bold)),
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              hintText: 'Enter title here',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Toggle for subtasks
          SwitchListTile(
            title: const Text("Use Subtasks"),
            value: _useSubtasks,
            onChanged: (v) => setState(() => _useSubtasks = v),
          ),

          const SizedBox(height: 16),
          if (_useSubtasks)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Subtasks',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ..._subtasks.asMap().entries.map((entry) {
                  final i = entry.key;
                  final text = entry.value;
                  final controller = TextEditingController(text: text);
                  return Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          decoration: InputDecoration(
                            hintText: 'Subtask ${i + 1}',
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (val) => _subtasks[i] = val,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => setState(() => _subtasks.removeAt(i)),
                      ),
                    ],
                  );
                }),
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text("Add Subtask"),
                  onPressed: () => setState(() => _subtasks.add("")),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Note',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextField(
                  controller: _note,
                  decoration: const InputDecoration(
                    hintText: 'Enter note here',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),

          const SizedBox(height: 16),
          const Text('Date', style: TextStyle(fontWeight: FontWeight.bold)),
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              child: Text('${_date.month}/${_date.day}/${_date.year}'),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Start Time',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          InkWell(
            onTap: _pickStart,
            child: InputDecorator(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.access_time),
              ),
              child: Text(_start == null ? '--:--' : _start!.format(context)),
            ),
          ),

          const SizedBox(height: 16),
          const Text('Category', style: TextStyle(fontWeight: FontWeight.bold)),
          DropdownButtonFormField<String>(
            value: _category,
            items: Categories.all
                .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                .toList(),
            onChanged: (v) => setState(() => _category = v ?? "Others"),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),

          const SizedBox(height: 16),
          const Text(
            'Difficulty',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Easy')),
              ButtonSegment(value: 1, label: Text('Medium')),
              ButtonSegment(value: 2, label: Text('Hard')),
            ],
            selected: <int>{_difficulty},
            onSelectionChanged: (s) => setState(() => _difficulty = s.first),
          ),

          const SizedBox(height: 16),
          const Text('Remind', style: TextStyle(fontWeight: FontWeight.bold)),
          DropdownButtonFormField<int>(
            value: _remindIndex,
            items: const [
              DropdownMenuItem(value: 0, child: Text('None')),
              DropdownMenuItem(value: 1, child: Text('5 minutes early')),
              DropdownMenuItem(value: 2, child: Text('15 minutes early')),
              DropdownMenuItem(value: 3, child: Text('1 hour early')),
            ],
            onChanged: (v) => setState(() => _remindIndex = v ?? 0),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),

          const SizedBox(height: 16),
          const Text('Repeat', style: TextStyle(fontWeight: FontWeight.bold)),
          DropdownButtonFormField<int>(
            value: _repeatIndex,
            items: const [
              DropdownMenuItem(value: 0, child: Text('None')),
              DropdownMenuItem(value: 1, child: Text('Daily')),
              DropdownMenuItem(value: 2, child: Text('Weekly')),
              DropdownMenuItem(value: 3, child: Text('Monthly')),
              DropdownMenuItem(value: 4, child: Text('Yearly')),
              DropdownMenuItem(value: 5, child: Text('Custom')),
            ],
            onChanged: (v) => setState(() => _repeatIndex = v ?? 0),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),

          if (_repeatIndex == 2) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _weeklyDay,
              items: List.generate(
                7,
                (i) => DropdownMenuItem(
                  value: i,
                  child: Text(
                    ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i],
                  ),
                ),
              ),
              onChanged: (v) => setState(() => _weeklyDay = v),
              decoration: const InputDecoration(
                labelText: "Pick Day of Week",
                border: OutlineInputBorder(),
              ),
            ),
          ],

          if (_repeatIndex == 3) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _monthlyDay,
              items: List.generate(
                31,
                (i) =>
                    DropdownMenuItem(value: i + 1, child: Text("Day ${i + 1}")),
              ),
              onChanged: (v) => setState(() => _monthlyDay = v),
              decoration: const InputDecoration(
                labelText: "Pick Day of Month",
                border: OutlineInputBorder(),
              ),
            ),
          ],

          if (_repeatIndex == 4) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _yearlyDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _yearlyDate = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: "Pick Yearly Date",
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _yearlyDate == null
                      ? "--/--"
                      : "${_yearlyDate!.month}/${_yearlyDate!.day}",
                ),
              ),
            ),
          ],

          if (_repeatIndex == 5) ...[
            const SizedBox(height: 8),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Repeat every N days",
                border: OutlineInputBorder(),
              ),
              onChanged: (val) =>
                  setState(() => _customInterval = int.tryParse(val)),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: () async {
            if (_title.text.trim().isEmpty) return;

            await widget.onSubmit(
              _title.text.trim(),
              _useSubtasks ? null : _note.text.trim(),
              _date,
              _start,
              _difficulty,
              subtasks: _useSubtasks
                  ? _subtasks.where((t) => t.trim().isNotEmpty).toList()
                  : null,
              category: _category.isEmpty ? "Others" : _category,
              remindIndex: _remindIndex,
              repeatIndex: _repeatIndex,
              weeklyDay: _weeklyDay,
              monthlyDay: _monthlyDay,
              yearlyDate: _yearlyDate,
              customInterval: _customInterval,
              repeat: _buildRepeat(),
            );

            Navigator.of(context).pop();
          },
          child: Text(widget.onDelete == null ? 'Add Task' : 'Save Changes'),
        ),
      ),
    );
  }
}
