import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'services/local_storage_service.dart';

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

  int _timeToSlot(TimeOfDay t) => t.hour * 2 + (t.minute >= 30 ? 1 : 0);
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
    TimeOfDay start = rec?['start'] ?? const TimeOfDay(hour: 7, minute: 30);
    TimeOfDay end = rec?['end'] ?? const TimeOfDay(hour: 8, minute: 30);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(rec == null ? 'Add Class' : 'Edit Class'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: subjCtl,
              decoration: const InputDecoration(labelText: 'Subject'),
            ),
            DropdownButton<String>(
              value: day,
              isExpanded: true,
              onChanged: (v) => setState(() => day = v!),
              items: _days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () async {
                    final t = await showTimePicker(context: context, initialTime: start);
                    if (t != null) setState(() => start = t);
                  },
                  child: Text('Start: ${start.format(context)}'),
                ),
                TextButton(
                  onPressed: () async {
                    final t = await showTimePicker(context: context, initialTime: end);
                    if (t != null) setState(() => end = t);
                  },
                  child: Text('End: ${end.format(context)}'),
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
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () {
              final subj = subjCtl.text.trim();
              if (subj.isEmpty) return;
              setState(() {
                if (rec != null) _records.remove(rec);
                _records.add({'subject': subj, 'day': day, 'start': start, 'end': end});
              });
              _saveClasses();
              widget.onRecordsChanged(_records);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveClasses() async {
    final toSave = _records.map((r) {
      return {
        'subject': r['subject'],
        'day': r['day'],
        'startHour': r['start'].hour,
        'startMinute': r['start'].minute,
        'endHour': r['end'].hour,
        'endMinute': r['end'].minute,
      };
    }).toList();
    await LocalStorageService.writeList('classes', toSave);
  }

  @override
  Widget build(BuildContext context) {
    final startSlot = _records.isEmpty
        ? 14
        : _records.map((r) => _timeToSlot(r['start'])).reduce((a, b) => a < b ? a : b);
    final endSlot = _records.isEmpty
        ? 18
        : _records.map((r) => _timeToSlot(r['end'])).reduce((a, b) => a > b ? a : b);
    final totalSlots = endSlot - startSlot;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time column
                Column(
                  children: [
                    const SizedBox(height: 44),
                    ...List.generate(totalSlots + 1, (i) {
                      return Container(
                        width: 72,
                        height: 36,
                        margin: const EdgeInsets.symmetric(vertical: 0.25),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _labelForSlot(startSlot + i),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                // Day columns
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _days.map((day) {
                        final dayRecs = _records.where((r) => r['day'] == day).toList();
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Day header
                              Container(
                                height: 36,
                                width: 124,
                                margin: const EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  day,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                              // Grid + classes
                              Stack(
                                children: [
                                  Column(
                                    children: List.generate(totalSlots + 1, (_) {
                                      return Stack(
                                        children: [
                                          Container(
                                            width: 124,
                                            height: 36,
                                            color: Colors.white,
                                          ),
                                          Positioned(
                                            top: 18,
                                            left: 0,
                                            right: 0,
                                            child: Container(
                                              height: 1,
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                        ],
                                      );
                                    }),
                                  ),
                                  ...dayRecs.map((rec) {
                                    final top = (_timeToSlot(rec['start']) - startSlot) * 36;
                                    final height = (_timeToSlot(rec['end']) - _timeToSlot(rec['start'])) * 36;
                                    return Positioned(
                                      top: top.toDouble(),
                                      left: 4,
                                      right: 4,
                                      height: height.toDouble(),
                                      child: GestureDetector(
                                        onTap: () => _openEditor(rec),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6),
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: _colorFor(rec['subject']).withOpacity(0.9),
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
                                            rec['subject'],
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
                                    );
                                  }).toList(),
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

  void openEditor([Map<String, dynamic>? rec]) => _openEditor(rec);
}
