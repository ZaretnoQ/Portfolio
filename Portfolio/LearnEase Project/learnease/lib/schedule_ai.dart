import 'dart:convert';
import 'package:intl/intl.dart';
import 'task_sorting.dart';
import 'package:flutter/material.dart';

class ScheduleAI {
  final TaskSortingService _svc;
  final Iterable<DateTime> _blueDates;

  ScheduleAI(this._svc, this._blueDates);

  Future<List<Map<String, dynamic>>> getSuggestedSchedule(
      String task,
      DateTime due,
      String difficulty,
      List<Map<String, dynamic>> existingTasks,
      List<Map<String, dynamic>> classRecords,
      ) async {
    final now = DateTime.now();
    final formattedDue = DateFormat('yyyy-MM-dd').format(due);

    final existingBlocks = existingTasks
        .where((t) => t['start'] != null && t['end'] != null)
        .map((t) {
      final start = (t['start'] as DateTime).toIso8601String();
      final end = (t['end'] as DateTime).toIso8601String();
      final name = t['task'];
      return '$name: $start to $end';
    })
        .join('\n');

    final prompt = '''
Today is ${DateFormat('yyyy-MM-dd').format(now)}.

You are helping a student create an efficient, balanced study schedule.

Task: "$task" (difficulty: $difficulty)
Due date: $formattedDue

They already have the following scheduled blocks:
$existingBlocks

🎯 Your objective:
- Suggest 1 or more ideal time blocks for this task.
- Avoid overloading the student — prioritize efficiency, not just filling time.
- Ensure recommended times leave room for rest and other classes.
- Consider splitting sessions when helpful or the task is long or difficult.

⏱ General time guidance:
- Quizzes: recommend multiple short sessions (30–45 mins) spread out when time allows. Use longer blocks if due soon.
- Assignments/Writing: use 1–2 long blocks (60–90 mins), can be split.
- Creative work: prefer multiple short sessions (e.g. 3:00–3:30, 5:00–7:00).
- Reading: usually 1 block of 30–45 mins is enough.

📝 Format response as JSON only:
[
  {
    "start": "2025-05-11T14:00:00",
    "end": "2025-05-11T15:00:00"
  }
]
Only return the array. No markdown or explanation.
''';

    final raw = await _svc.simplePrompt(prompt);
    print('📥 RAW AI RESPONSE:\n$raw');

    // Extract clean JSON array using regex
    final match = RegExp(r'\[.*?\]', dotAll: true).firstMatch(raw);
    final cleaned = match?.group(0) ?? '';
    print('🔍 CLEANED JSON:\n$cleaned');

    try {
      final decoded = jsonDecode(cleaned) as List<dynamic>;
      final prefix = _generateTitlePrefix(task.toLowerCase());

      return decoded
          .cast<Map<String, dynamic>>()
          .where((block) {
        final start = DateTime.parse(block['start']);
        final end = DateTime.parse(block['end']);
        return !_conflictsWithClass(start, end, classRecords);
      })
          .map((block) {
        return {
          ...block,
          'title': '$prefix ${task.trim()}',
        };
      }).toList();
    } catch (e) {
      print('❌ Failed to parse AI schedule: $e');
      return [];
    }
  }

  String _generateTitlePrefix(String task) {
    if (task.contains('quiz') || task.contains('exam') || task.contains('test')) {
      return 'Study for';
    } else if (task.contains('assignment') || task.contains('paper') || task.contains('project')) {
      return 'Work on';
    } else if (task.contains('read')) {
      return 'Read';
    } else if (task.contains('watch') || task.contains('video')) {
      return 'Watch';
    } else {
      return 'Do';
    }
  }

  bool _conflictsWithClass(DateTime start, DateTime end, List<Map<String, dynamic>> classRecords) {
    final day = DateFormat('EEEE').format(start);
    for (final c in classRecords) {
      if (c['day'] != day) continue;
      final classStart = TimeOfDay(hour: c['start'].hour, minute: c['start'].minute);
      final classEnd = TimeOfDay(hour: c['end'].hour, minute: c['end'].minute);
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
}
