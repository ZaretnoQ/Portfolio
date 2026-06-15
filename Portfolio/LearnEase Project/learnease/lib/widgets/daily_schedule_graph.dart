import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DailyScheduleGraph extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final DateTime selectedDate;

  const DailyScheduleGraph({
    super.key,
    required this.records,
    required this.selectedDate,
  });

  @override
  Widget build(BuildContext context) {
    const double slotWidth = 60.0;
    const double rowHeight = 100.0;
    const int startHour = 6;
    const int endHour = 22;

    final selectedDayName = DateFormat('EEEE').format(selectedDate);

    // Separate class vs AI sessions
    final classBlocks = <Map<String, dynamic>>[];
    final aiTasks = <Map<String, dynamic>>[];

    for (var r in records) {
      final dayName = (r['day'] as String).toLowerCase();
      final matchesDay = dayName == selectedDayName.toLowerCase();

      final isClass = r['isAI'] == false;
      final isAI    = r['isAI'] == true;

      if (matchesDay && isClass) {
        classBlocks.add(r);
      }
      if (isAI) {
        final dt = r['start'] as DateTime;
        if (DateFormat('yyyy-MM-dd').format(dt) ==
            DateFormat('yyyy-MM-dd').format(selectedDate)) {
          aiTasks.add(r);
        }
      }
    }

    if (classBlocks.isEmpty && aiTasks.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No schedule for $selectedDayName.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    // Build half-hour slots labels
    final slots = List.generate((endHour - startHour) * 2, (i) {
      final totalMins = startHour * 60 + i * 30;
      final h24 = totalMins ~/ 60;
      final m = totalMins % 60;
      final h12 = ((h24 + 11) % 12) + 1;
      final ampm = h24 >= 12 ? 'PM' : 'AM';
      return '$h12:${m.toString().padLeft(2, '0')}$ampm';
    });

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time labels row
          Row(
            children: [
              const SizedBox(width: 40),
              ...slots.map((label) => Container(
                width: slotWidth,
                height: 30,
                alignment: Alignment.center,
                child: Text(label, style: const TextStyle(fontSize: 11)),
              )),
            ],
          ),
          // Schedule blocks
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day label
              RotatedBox(
                quarterTurns: 1,
                child: Text(
                  selectedDayName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(
                width: slotWidth * slots.length,
                height: rowHeight,
                child: Stack(
                  children: [
                    // Class blocks (non-AI)
                    ...classBlocks.map((r) {
                      final startDT = r['start'] as DateTime;
                      final endDT   = r['end']   as DateTime;
                      final startMin = startDT.hour * 60 + startDT.minute;
                      final endMin   = endDT.hour   * 60 + endDT.minute;
                      final offset = ((startMin - startHour * 60) / 30) * slotWidth;
                      final width  = ((endMin - startMin) / 30) * slotWidth;

                      final color = _colorFor(r['subject'] as String);

                      return Positioned(
                        left: offset,
                        top: 0,
                        width: width,
                        height: rowHeight,
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            r['subject'] as String,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }),
                    // AI tasks
                    ...aiTasks.map((r) {
                      final startDT = r['start'] as DateTime;
                      final endDT   = r['end']   as DateTime;
                      final startMin = startDT.hour * 60 + startDT.minute;
                      final endMin   = endDT.hour   * 60 + endDT.minute;
                      final offset = ((startMin - startHour * 60) / 30) * slotWidth;
                      final width  = ((endMin - startMin) / 30) * slotWidth;

                      return Positioned(
                        left: offset,
                        top: 0,
                        width: width,
                        height: rowHeight,
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            r['subject'] ?? 'AI Task',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _colorFor(String subj) {
    const palette = [
      Colors.green, Colors.orange, Colors.purple,
      Colors.red,   Colors.teal,   Colors.amber,
      Colors.deepOrange, Colors.pink,
    ];
    return palette[subj.hashCode % palette.length];
  }
}
