import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'task_sorting.dart';
import 'task_form.dart';
import 'task_styles.dart';

class TaskDisplay extends StatelessWidget {
  final List<Map<String, dynamic>> tasks;
  final void Function(int oldIndex, int newIndex) onReorder;
  final TaskSortingService sortingService;
  final void Function(int index, Map<String, dynamic> newTask) onEditTask;
  final void Function(Map<String, dynamic> task) onRemoveTask;  // ← new
  final bool isSchedule;

  const TaskDisplay({
    Key? key,
    required this.tasks,
    required this.onReorder,
    required this.sortingService,
    required this.onEditTask,
    required this.onRemoveTask,    // ← new
    this.isSchedule = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const itemH = 95.0;

    return SizedBox(
      height: itemH * tasks.length,
      child: ReorderableListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: tasks.length,
        onReorder: onReorder,
        itemBuilder: (_, i) {
          final t = tasks[i];
          final diff = t['difficulty'] as String;

          // badge colour
          final badgeColor = switch (diff) {
            'Easy'   => Colors.green,
            'Medium' => Colors.blue,
            'Hard'   => Colors.red,
            _        => Colors.grey,
          };

          // border colour
          final border = isSchedule ? TaskColors.blue : TaskColors.yellowDark;

          return Container(
            key: ValueKey(t['id']),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            decoration: cardBorder(border),
            child: ListTile(
              minLeadingWidth: 0,
              leading: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(diff,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 11)),
              ),
              title: Text(t['task'] as String),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.play_circle_fill),
                    onPressed: () async {
                      final links = await sortingService
                          .getYouTubeRecommendations(t['task'] as String);
                      if (!context.mounted) return;
                      await showModalBottomSheet(
                        context: context,
                        builder: (_) => ListView(
                          padding: const EdgeInsets.all(12),
                          children: links
                              .map((url) => SelectableText(
                            url,
                            style: const TextStyle(fontSize: 13),
                          ))
                              .toList(),
                        ),
                      );
                    },
                  ),

                  // ← repurposed check button to delete
                  IconButton(
                    icon: const Icon(Icons.check_box),
                    tooltip: isSchedule
                        ? 'Remove scheduled session'
                        : 'Remove task',
                    onPressed: () {
                      onRemoveTask(t);
                    },
                  ),
                ],
              ),
              onTap: () async {
                final edited = await showDialog<Map<String, dynamic>>(
                  context: context,
                  builder: (ctx) => Dialog(
                    child: TaskForm(
                      onAddTask: (task, date, diff) =>
                          Navigator.pop(ctx, {
                            'task': task,
                            'date': date,
                            'difficulty': diff,
                          }),
                      initialTask: t,
                    ),
                  ),
                );
                if (context.mounted && edited != null) {
                  onEditTask(i, {...t, ...edited});
                }
              },
            ),
          );
        },
      ),
    );
  }
}
