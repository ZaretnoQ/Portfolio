import 'package:flutter/material.dart';
import '../models/class_schedule.dart';

class ClassScheduleGrid extends StatelessWidget {
  final List<ClassSchedule> schedules;

  const ClassScheduleGrid({super.key, required this.schedules});

  @override
  Widget build(BuildContext context) {
    final hours = List.generate(28, (i) => TimeOfDay(hour: 6 + (i ~/ 2), minute: (i % 2) * 30));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        columnWidths: const {0: FixedColumnWidth(60)},
        border: TableBorder.all(color: Colors.grey.shade300),
        children: [
          TableRow(
            children: [const SizedBox()] +
                List.generate(7, (i) => Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i],
                    textAlign: TextAlign.center,
                  ),
                )),
          ),
          ...hours.map((time) {
            return TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text("${time.format(context)}", textAlign: TextAlign.center),
                ),
                ...List.generate(7, (i) {
                  final daySchedules = schedules.where((s) =>
                  s.day.weekday == i + 1 &&
                      s.startTime.hour == time.hour &&
                      s.startTime.minute == time.minute);
                  return Container(
                    height: 40,
                    color: daySchedules.isEmpty ? null : Colors.lightBlueAccent.withOpacity(0.4),
                    alignment: Alignment.center,
                    child: Text(
                      daySchedules.map((s) => s.subject).join(', '),
                      style: const TextStyle(fontSize: 11),
                    ),
                  );
                }),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }
}
