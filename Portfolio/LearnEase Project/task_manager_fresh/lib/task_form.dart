import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'widgets/ad_dialog.dart';


class TaskForm extends StatefulWidget {
  final Future<void> Function(String task, DateTime date, String difficulty) onAddTask;
  final Map<String, dynamic>? initialTask;

  const TaskForm({
    Key? key,
    required this.onAddTask,
    this.initialTask,
  }) : super(key: key);

  @override
  State<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<TaskForm> {
  final _formKey = GlobalKey<FormState>();
  final _taskController = TextEditingController();
  late DateTime _selectedDate;
  late String _selectedDifficulty;

  /// Builds the “Add Task / Save Changes” button.
  /// Keeping it separate keeps `build()` shorter.
  Widget _buildSaveButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        if (!_formKey.currentState!.validate()) return;

        final task = _taskController.text;
        final date = _selectedDate;
        final diff = _selectedDifficulty;

        if (widget.initialTask == null) {
          // 1) kick off scheduling immediately
          final scheduling = widget.onAddTask(task, date, diff);

          // 2) show 10-second ad while that runs
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) =>
            const AdDialog(duration: Duration(seconds: 10)),
          );

          // 3) ensure scheduling is done, then close form
          await scheduling;
          Navigator.of(context).pop();
        } else {
          // editing existing task—no ad
          Navigator.of(context).pop({
            'task': task,
            'date': date,
            'difficulty': diff,
          });
        }
      },
      child: Text(widget.initialTask == null ? 'Add Task' : 'Save Changes'),
    );
  }

  @override
  void initState() {
    super.initState();
    // Initialize fields, optionally from initialTask
    _selectedDate = widget.initialTask?['date'] as DateTime? ?? DateTime.now();
    _selectedDifficulty = widget.initialTask?['difficulty'] as String? ?? 'Medium';
    if (widget.initialTask != null) {
      _taskController.text = widget.initialTask!['task'] as String? ?? '';
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20,
      ),
      child: SingleChildScrollView(
        child: Material(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _taskController,
                    decoration: const InputDecoration(
                      labelText: 'Task Description',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                    (v == null || v.isEmpty) ? 'Please enter a task' : null,
                  ),
                  const SizedBox(height: 16),

                  /* ---- WRAP prevents any overflow ---- */
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                        width: 240, // makes sure field doesn’t get huge
                        child: InkWell(
                          onTap: _pickDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Due Date',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(DateFormat('MMM dd, yyyy')
                                .format(_selectedDate)),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 160,
                        child: DropdownButtonFormField<String>(
                          value: _selectedDifficulty,
                          decoration: const InputDecoration(
                            labelText: 'Difficulty',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: ['Easy', 'Medium', 'Hard']
                              .map((d) => DropdownMenuItem(
                            value: d,
                            child: Text(d),
                          ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedDifficulty = v ?? 'Medium'),
                        ),
                      ),
                    ],
                  ),
                  /* ------------------------------------- */

                  const SizedBox(height: 24),
                  _buildSaveButton(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
