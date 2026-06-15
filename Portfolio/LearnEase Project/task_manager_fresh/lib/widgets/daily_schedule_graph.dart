import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../task_styles.dart';

class DailyScheduleGraph extends StatelessWidget {
  final List<Map<String, dynamic>> records;   // each map: start, end, subject, day, isAI
  final DateTime selectedDate;

  const DailyScheduleGraph({
    super.key,
    required this.records,
    required this.selectedDate,
  });

  // minutes since midnight
  int _minOfDay(DateTime dt) => dt.hour * 60 + dt.minute;

  String _labelForSlot(int slot) {
    final mins = slot * 30;
    final h24  = mins ~/ 60;
    final m    = mins % 60;
    final h12  = ((h24 + 11) % 12) + 1;
    final ampm = h24 >= 12 ? 'PM' : 'AM';
    return '$h12:${m.toString().padLeft(2, '0')}$ampm';
  }

  @override
  Widget build(BuildContext context) {
    // ───────── separate today’s class & AI sessions ─────────
    final selDayName = DateFormat('EEEE').format(selectedDate).toLowerCase();
    final todayStr   = DateFormat('yyyy-MM-dd').format(selectedDate);

    final classBlocks = <Map<String, dynamic>>[];
    final aiBlocks    = <Map<String, dynamic>>[];

    for (var r in records) {
      final isAI    = r['isAI'] == true;
      final isClass = !isAI;

      if (isClass) {
        final dayName = (r['day'] as String).toLowerCase();
        if (dayName == selDayName) classBlocks.add(r);
      } else {
        final startDt = r['start'] as DateTime;
        if (DateFormat('yyyy-MM-dd').format(startDt) == todayStr) aiBlocks.add(r);
      }
    }

    if (classBlocks.isEmpty && aiBlocks.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text('No schedule for ${DateFormat('EEEE').format(selectedDate)}',
              style: Theme.of(context).textTheme.bodyLarge),
        ),
      );
    }

    // ───────── dynamic time window ─────────
    final starts = [
      ...classBlocks.map((r) => _minOfDay(r['start'] as DateTime)),
      ...aiBlocks   .map((r) => _minOfDay(r['start'] as DateTime)),
    ];
    final ends = [
      ...classBlocks.map((r) => _minOfDay(r['end'] as DateTime)),
      ...aiBlocks   .map((r) => _minOfDay(r['end'] as DateTime)),
    ];

    final rawMin = starts.reduce(min);
    final rawMax = ends.reduce(max);

    final gridStartMin = (rawMin ~/ 30) * 30;          // snap down
    final gridEndMin   = ((rawMax + 29) ~/ 30) * 30;   // snap up
    final totalMinutes = gridEndMin - gridStartMin;
    final slotCount    = (totalMinutes / 30).ceil() + 1; // +1 spacer

    // ───────── visual constants ─────────
    const slotWidth  = 70.0;   // unified width for labels & grid
    // width of one 30-min slot
    const rowHeight  = 100.0;         // vertical lane height
    const pxPerMin   = slotWidth / 30;

    // time-axis labels
    final labels = List.generate(slotCount, (i) => _labelForSlot((gridStartMin ~/ 30) + i));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── time labels row ───
          Row(
            children: [
              const SizedBox(width: 40),
              ...labels.map((lab) => SizedBox(
                width: slotWidth,
                height: 30,
                child: Center(child: Text(lab, style: const TextStyle(fontSize: 11))),
              )),
            ],
          ),

          // ─── schedule lane ───
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // rotated day label
              RotatedBox(
                quarterTurns: 1,
                child: Text(
                  DateFormat('EEEE').format(selectedDate),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),

              // lane with grid + blocks
              SizedBox(
                width: slotWidth * slotCount,
                height: rowHeight,
                child: Stack(
                  children: [
                    // background half-hour grid
                    Row(
                      children: List.generate(slotCount, (_) {
                        return Container(
                          width: slotWidth,
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(color: Colors.grey.shade300, width: 0.5),
                            ),
                          ),
                        );
                      }),
                    ),

                    // class blocks
                    ...classBlocks.map((r) {
                      final start = r['start'] as DateTime;
                      final end   = r['end']   as DateTime;
                      final offset = (_minOfDay(start) - gridStartMin + 15) * pxPerMin;

                      final width  = (_minOfDay(end) - _minOfDay(start) + 30) * pxPerMin;

                      return Positioned(
                        left: offset,
                        top: 0,
                        width: width,
                        height: rowHeight,
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _colorFor(r['subject'] as String).withOpacity(0.85),
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

                    // AI blocks
                    ...aiBlocks.map((r) {
                      final start = r['start'] as DateTime;
                      final end   = r['end']   as DateTime;
                      final offset = (_minOfDay(start) - gridStartMin) * pxPerMin;
                      final width  = (_minOfDay(end) - _minOfDay(start) + 30) * pxPerMin;

                      return Positioned(
                        left: offset,
                        top: 0,
                        width: width,
                        height: rowHeight,
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: TaskColors.blue.withOpacity(0.9),
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

  // simple deterministic colour picker
  Color _colorFor(String subj) {
    const palette = [
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.amber,
      Colors.deepOrange,
      Colors.pink,
    ];
    return palette[subj.hashCode % palette.length];
  }
}
