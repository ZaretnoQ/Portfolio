import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'task_sorting.dart';

class ScheduleAI {
  final TaskSortingService _svc;
  final Iterable<DateTime> _blueDates;
  final _cache = <String, Future<List<Map<String, dynamic>>>>{};

  ScheduleAI(this._svc, this._blueDates);

  /// Generate sessions for one task by prompting your AI service.
  Future<List<Map<String, dynamic>>> getSuggestedSchedule(
      String task,
      DateTime due,
      String difficulty,
      List<Map<String, dynamic>> existingTasks,
      List<Map<String, dynamic>> classRecords,
      ) async {
    final now = DateTime.now();
    final formattedDue = DateFormat('yyyy-MM-dd').format(due);

    // 1) Gather existing blocks
    final existingBlocks = existingTasks
        .where((t) => t['sessions'] != null)
        .expand((t) => (t['sessions'] as List).map((s) {
      final startIso = (s['start'] as DateTime).toIso8601String();
      final endIso = (s['end'] as DateTime).toIso8601String();
      return '${t['task']}: $startIso to $endIso';
    }))
        .join('\n');

    // 2) Build prompt
    final prompt = '''
Today is ${DateFormat('yyyy-MM-dd').format(now)}.

You are helping a student create an efficient, balanced study-schedule.

📝 Task: "$task"   (difficulty: $difficulty)  
📅 Due date: $formattedDue

They already have these fixed blocks:
$existingBlocks

⚠️  **Hard rules**  
1. All suggested blocks must be **today or later** — never before “Today”.  
2. All blocks must end **on or before the due date**.  
3. Do not overlap any block listed above.

🤖 **Guidelines**  
• If the due date is more than 2 full days away **and** the task is Medium or Hard, split work into **at least 2 sessions**.  
• Hard ⇒ 60–90 min sessions.  
• Medium ⇒ 45–60 min sessions.  
• Easy ⇒ one 30–45 min session.  
• Leave sensible breaks between sessions.

📝 **Respond with JSON only** – an array like:

[
  { "start": "2025-05-11T14:00:00", "end": "2025-05-11T15:00:00" }
]

No markdown, no comments.
''';

    // 3) Call AI
    final raw = await _svc.simplePrompt(prompt);
    final cleaned =
    raw.trim().replaceAll('```json', '').replaceAll('```', '');

    // 4) Parse & filter
    final todayMid = DateTime(now.year, now.month, now.day);
    final dueMid = DateTime(due.year, due.month, due.day);
    final allowSameDay = todayMid == dueMid;
    List<Map<String, dynamic>> suggestions;

    try {
      final decoded = jsonDecode(cleaned) as List<dynamic>;
      suggestions = decoded.cast<Map<String, dynamic>>().where((blk) {
        final start = DateTime.parse(blk['start']);
        final end = DateTime.parse(blk['end']);

        if (!allowSameDay && start.isBefore(todayMid)) return false;
        if (end.isAfter(dueMid.add(const Duration(days: 1)))) return false;
        return !_conflictsWithClass(start, end, classRecords);
      }).map((blk) {
        return {
          'start': blk['start'],
          'end': blk['end'],
          'title': '${_generateTitlePrefix(task)} ${task.trim()}',
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ Failed to parse AI schedule: $e');
      suggestions = [];
    }

    // 5) Return if any
    if (suggestions.isNotEmpty) return suggestions;

    // 6) Fallback
    final fbDay = due.subtract(const Duration(days: 1));
    final s = DateTime(fbDay.year, fbDay.month, fbDay.day, 9);
    final e = s.add(const Duration(hours: 1));
    return [
      {
        'start': s.toIso8601String(),
        'end': e.toIso8601String(),
        'title': '${_generateTitlePrefix(task)} ${task.trim()}',
      }
    ];
  }

  // Helper: verb prefix
  String _generateTitlePrefix(String task) {
    final t = task.toLowerCase();
    if (t.contains('quiz') || t.contains('exam') || t.contains('test')) {
      return 'Study';
    } else if (t.contains('assignment') ||
        t.contains('paper') ||
        t.contains('project')) {
      return 'Work on';
    } else if (t.contains('read') ||
        t.contains('chapter') ||
        t.contains('book')) {
      return 'Read';
    } else if (t.contains('write') || t.contains('essay')) {
      return 'Write';
    } else if (t.contains('present') || t.contains('presentation')) {
      return 'Prepare';
    } else {
      return 'Do';
    }
  }

  // Helper: conflict with class
  bool _conflictsWithClass(
      DateTime start, DateTime end, List<Map<String, dynamic>> classRecords) {
    final dayName = DateFormat('EEEE').format(start);
    for (final c in classRecords) {
      if (c['day'] != dayName) continue;
      final classStart = c['start'] as TimeOfDay;
      final classEnd = c['end'] as TimeOfDay;
      final bStart = TimeOfDay(hour: start.hour, minute: start.minute);
      final bEnd = TimeOfDay(hour: end.hour, minute: end.minute);

      final overlap = !(bEnd.hour < classStart.hour ||
          (bEnd.hour == classStart.hour && bEnd.minute <= classStart.minute) ||
          bStart.hour > classEnd.hour ||
          (bStart.hour == classEnd.hour && bStart.minute >= classEnd.minute));
      if (overlap) return true;
    }
    return false;
  }

  /// Schedule all tasks in parallel, caching per-task results.
  Future<List<Map<String, dynamic>>> scheduleTasks(
      List<Map<String, dynamic>> tasks,
      List<Map<String, dynamic>> classRecords,
      ) async {
    // clear old sessions
    for (final t in tasks) {
      t['sessions'] = <Map<String, dynamic>>[];
    }

    // sort by difficulty, then due date
    const Map<String, int> weight = {'Hard': 0, 'Medium': 1, 'Easy': 2};
    tasks.sort((a, b) {
      final w = weight[a['difficulty'] ?? 'Medium']!
          .compareTo(weight[b['difficulty'] ?? 'Medium']!);
      if (w != 0) return w;
      return DateTime.parse(a['date']).compareTo(DateTime.parse(b['date']));
    });

    // launch all scheduling in parallel, with caching
    final futures = tasks.map((t) {
      final key = '${t['task']}|${t['date']}|${t['difficulty']}';
      return (_cache[key] ??= getSuggestedSchedule(
        t['task'] as String,
        DateTime.parse(t['date'] as String),
        t['difficulty'] as String,
        tasks,
        classRecords,
      )).then((blocks) {
        if (blocks.isNotEmpty) {
          t['sessions'] = blocks.map((b) {
            return {
              'start': DateTime.parse(b['start'] as String),
              'end': DateTime.parse(b['end'] as String),
              'title': b['title'] as String,
            };
          }).toList();
        }
      });
    }).toList();

    await Future.wait(futures);
    return tasks;
  }
}
