import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'services/local_storage_service.dart';
import 'dart:math';


class ClassSchedulePage extends StatefulWidget {
  final void Function(List<Map<String, dynamic>>) onRecordsChanged;
  const ClassSchedulePage({super.key, required this.onRecordsChanged});

  @override
  ClassSchedulePageState createState() => ClassSchedulePageState();
}

class ClassSchedulePageState extends State<ClassSchedulePage> {
  List<Map<String, dynamic>> _records = [];

  final List<String> _days = const [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];
  final List<Color> _palette = [
    Colors.blue, Colors.green, Colors.orange,
    Colors.purple, Colors.red, Colors.teal, Colors.amber,
  ];

  Color _colorFor(String subj) => _palette[subj.hashCode % _palette.length];

  @override
  void initState() {
    super.initState();
    LocalStorageService.readList('classes').then((saved) {
      final loaded = saved.map((m) {
        return {
          'subject': m['subject'],
          'day': m['day'],
          'start': TimeOfDay(hour: m['startHour'], minute: m['startMinute']),
          'end': TimeOfDay(hour: m['endHour'], minute: m['endMinute']),
        };
      }).toList();
      setState(() => _records = loaded);
      widget.onRecordsChanged(_records);
    });
  }

  // Convert TimeOfDay to minutes since midnight
  int _minutesOfDay(TimeOfDay t) => t.hour * 60 + t.minute;

  String _labelForSlot(int slot) {
    final mins = slot * 30;
    final h24 = mins ~/ 60;
    final m = mins % 60;
    final h12 = ((h24 + 11) % 12) + 1;
    final ampm = h24 >= 12 ? 'PM' : 'AM';
    return '$h12:${m.toString().padLeft(2, '0')}$ampm';
  }

  void _openEditor([Map<String, dynamic>? rec]) {
    final subjCtl = TextEditingController(text: rec?['subject'] ?? '');
    String day = rec?['day'] ?? _days.first;
    TimeOfDay start = rec?['start'] as TimeOfDay? ??
        const TimeOfDay(hour: 7, minute: 0);
    TimeOfDay end = rec?['end'] as TimeOfDay? ??
        const TimeOfDay(hour: 8, minute: 0);

    showDialog(
      context: context,
      builder: (_) =>
          StatefulBuilder(
            builder: (ctx, setLocal) =>
                AlertDialog(
                  title: Text(rec == null ? 'Add Class' : 'Edit Class'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: subjCtl,
                        decoration: const InputDecoration(labelText: 'Subject'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButton<String>(
                        value: day,
                        isExpanded: true,
                        onChanged: (v) => setLocal(() => day = v!),
                        items: _days
                            .map((d) =>
                            DropdownMenuItem(value: d, child: Text(d)))
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () async {
                              final t = await showTimePicker(
                                context: context,
                                initialTime: start,
                              );
                              if (t != null) setLocal(() => start = t);
                            },
                            child: Text('Start: ${start.format(context)}'),
                          ),
                          TextButton(
                            onPressed: () async {
                              final t = await showTimePicker(
                                context: context,
                                initialTime: end,
                              );
                              if (t != null) setLocal(() => end = t);
                            },
                            child: Text('End:   ${end.format(context)}'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  actions: [
                    if (rec != null)
                      TextButton(
                        onPressed: () {
                          setState(() => _records.remove(rec));
                          _saveClasses();
                          widget.onRecordsChanged(_records);
                          Navigator.pop(context);
                        },
                        child: const Text(
                            'Delete', style: TextStyle(color: Colors.red)),
                      ),
                    TextButton(
                      onPressed: () {
                        final subj = subjCtl.text.trim();
                        if (subj.isEmpty) return;
                        setState(() {
                          if (rec != null) _records.remove(rec);
                          _records.add({
                            'subject': subj,
                            'day': day,
                            'start': start,
                            'end': end,
                          });
                        });
                        _saveClasses();
                        widget.onRecordsChanged(_records);
                        Navigator.pop(context);
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _saveClasses() async {
    final toSave = _records.map((r) {
      return {
        'subject': r['subject'],
        'day': r['day'],
        'startHour': (r['start'] as TimeOfDay).hour,
        'startMinute': (r['start'] as TimeOfDay).minute,
        'endHour': (r['end'] as TimeOfDay).hour,
        'endMinute': (r['end'] as TimeOfDay).minute,
      };
    }).toList();
    await LocalStorageService.writeList('classes', toSave);
  }

  void openEditor([Map<String, dynamic>? rec]) {
    _openEditor(rec);
  }

  @override
  Widget build(BuildContext context) {
    // 1) Gather all start & end minutes
    final starts = _records.map((r) => _minutesOfDay(r['start'] as TimeOfDay)).toList();
    final ends   = _records.map((r) => _minutesOfDay(r['end']   as TimeOfDay)).toList();

    // 2) Default window if no classes
    final rawMin = starts.isEmpty ? 7 * 60 : starts.reduce(min);
    final rawMax = ends.isEmpty   ? 19 * 60 : ends.reduce(max);

    // 3) Snap to nearest half-hour
    final gridStartMin = (rawMin ~/ 30) * 30;            // e.g. 07:10 → 07:00
    final gridEndMin   = ((rawMax + 29) ~/ 30) * 30;     // e.g. 18:40 → 19:00
    final totalMinutes = gridEndMin - gridStartMin;
    final slotCount    = (totalMinutes / 30).ceil();     // number of 30-min slots

    // 4) Fixed scale: 36 px per 30 min  (1.2 px per min)
    const double pxPerMin = 36.0 / 30.0;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(            // vertical scroll
            scrollDirection: Axis.vertical,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─ Time labels column ─
                Column(
                  children: [
                    const SizedBox(height: 44),
                    for (int i = 0; i <= slotCount; i++)
                      Container(
                        width: 72,
                        height: pxPerMin * 30,
                        margin: const EdgeInsets.symmetric(vertical: 0.25),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _labelForSlot((gridStartMin ~/ 30) + i),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                  ],
                ),

                // ─ Day columns (horizontal scroll) ─
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _days.map((day) {
                        final dayRecs = _records.where((r) => r['day'] == day).toList();
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Column(
                            children: [
                              // Day header
                              Container(
                                height: 44,
                                width: 124,
                                margin: const EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: Text(day,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 13)),
                              ),

                              // Grid + class blocks
                              Stack(
                                children: [
                                  // empty grid lines (exactly one per slot)
                                  Column(
                                    children: List.generate(slotCount + 1, (_) {      // +1 spacer row
                                      return Container(
                                        width: 124,
                                        height: pxPerMin * 30,
                                        color: Colors.white,
                                        child: Divider(
                                            height: 1, color: Colors.grey.shade300),
                                      );
                                    }),
                                  ),

                                  // class rectangles
                                  for (var rec in dayRecs)
                                    Positioned(
                                      top: (_minutesOfDay(rec['start'] as TimeOfDay) -
                                          gridStartMin) *
                                          pxPerMin,
                                      left: 4,
                                      right: 4,
                                      height: ((_minutesOfDay(rec['end'] as TimeOfDay) -
                                          _minutesOfDay(rec['start'] as TimeOfDay)) + 30) * pxPerMin,

                                      child: GestureDetector(
                                        onTap: () => openEditor(rec),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6),
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: _colorFor(rec['subject'] as String)
                                                .withOpacity(0.9),
                                            borderRadius: BorderRadius.circular(6),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.05),
                                                blurRadius: 3,
                                                offset: const Offset(0, 1),
                                              )
                                            ],
                                          ),
                                          child: Text(
                                            rec['subject'] as String,
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}