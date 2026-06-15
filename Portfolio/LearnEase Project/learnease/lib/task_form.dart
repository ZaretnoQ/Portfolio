import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TaskForm extends StatefulWidget {
  final void Function(String task, DateTime date, String difficulty) onAddTask;
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
      // adjust for keyboard
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
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
                    validator: (value) =>
                    (value == null || value.isEmpty) ? 'Please enter a task' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Due Date',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(DateFormat('MMM dd, yyyy').format(_selectedDate)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedDifficulty,
                          decoration: const InputDecoration(
                            labelText: 'Difficulty',
                            border: OutlineInputBorder(),
                          ),
                          items: ['Easy', 'Medium', 'Hard']
                              .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _selectedDifficulty = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      if (!_formKey.currentState!.validate()) return;
                      final task = _taskController.text;
                      final date = _selectedDate;
                      final diff = _selectedDifficulty;

                      final result = {
                        'task': task,
                        'date': date,
                        'difficulty': diff,
                      };

                      if (widget.initialTask == null) {
                        // New task: call callback AND close dialog
                        widget.onAddTask(task, date, diff);
                        Navigator.of(context).pop();
                      } else {
                        // Editing existing: return edited map
                        Navigator.of(context).pop(result);
                      }
                    },
                    child: Text(widget.initialTask == null ? 'Add Task' : 'Save Changes'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
