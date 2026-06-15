import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import 'class_schedule_page.dart';
import 'schedule_ai.dart';
import 'services/local_storage_service.dart';
import 'task_display.dart';
import 'task_form.dart';
import 'task_sorting.dart';
import 'task_styles.dart';
import 'widgets/daily_schedule_graph.dart';
import 'chatbot_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LearnEase',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: TaskColors.yellowDark),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _classRecords = [];
  int _nav = 0;
  bool _showDailySchedule = false;
  bool _filteredByDay = false;
  late final TabController _weekTab;
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();

  late final TaskSortingService sorter;
  late final ScheduleAI scheduler;
  final GlobalKey<ClassSchedulePageState> _classKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    sorter = TaskSortingService(dotenv.env['OPENROUTER_API_KEY']!);
    scheduler = ScheduleAI(
      sorter,
      _tasks
          .where((t) => t['sessions'] != null)
          .expand((t) => (t['sessions'] as List).map((s) => s['start'] as DateTime)),
    );
    _weekTab = TabController(length: 2, vsync: this);

    LocalStorageService.readList('tasks').then((saved) {
      setState(() {
        _tasks = saved.map((m) {
          final date = DateTime.parse(m['date'] as String);
          return {
            'id': m['id'],
            'task': m['task'],
            'date': date,
            'difficulty': m['difficulty'],
            'completed': m['completed'] as bool? ?? false,
            if (m.containsKey('sessions'))
              'sessions': (m['sessions'] as List).map((s) {
                return {
                  'start': DateTime.parse(s['start'] as String),
                  'end': DateTime.parse(s['end'] as String),
                };
              }).toList(),
          };
        }).toList();
      });
    });

    LocalStorageService.readList('classes').then((saved) {
      setState(() {
        _classRecords = saved.map((m) {
          return {
            'subject': m['subject'],
            'day': m['day'],
            'start': TimeOfDay(hour: m['startHour'], minute: m['startMinute']),
            'end': TimeOfDay(hour: m['endHour'], minute: m['endMinute']),
          };
        }).toList();
      });
    });
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _saveTasks() async {
    final toSave = _tasks.map((t) {
      final m = {
        'id': t['id'],
        'task': t['task'],
        'date': (t['date'] as DateTime).toIso8601String(),
        'difficulty': t['difficulty'],
        'completed': t['completed'] as bool? ?? false,
      };
      if (t.containsKey('sessions')) {
        m['sessions'] = (t['sessions'] as List).map((s) {
          return {
            'start': (s['start'] as DateTime).toIso8601String(),
            'end': (s['end'] as DateTime).toIso8601String(),
          };
        }).toList();
      }
      return m;
    }).toList();
    await LocalStorageService.writeList('tasks', toSave);
  }

  Future<void> _addTask(String task, DateTime due, String diff) async {
    final blocks = await scheduler.getSuggestedSchedule(
        task, due, diff, _tasks, _classRecords);
    final now = DateTime.now().millisecondsSinceEpoch;
    final taskData = {
      'id': now,
      'task': task,
      'date': due,
      'difficulty': diff,
      'completed': false,
    };
    if (blocks.isNotEmpty) {
      taskData['sessions'] = blocks.map((b) {
        return {
          'start': DateTime.parse(b['start']),
          'end': DateTime.parse(b['end']),
        };
      }).toList();
    }
    setState(() {
      _tasks.add(taskData);
    });
    await _saveTasks();
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final taskEvents = _tasks
        .where((t) => _sameDay(t['date'] as DateTime, day))
        .map((_) => {'type': 'task'})
        .toList();
    final sessionEvents = _tasks
        .where((t) => t['sessions'] != null)
        .expand((t) => t['sessions'] as List)
        .where((s) => _sameDay(s['start'] as DateTime, day))
        .map((_) => {'type': 'session'})
        .toList();
    return [...taskEvents, ...sessionEvents];
  }

  Widget _buildGroup(List<Map<String, dynamic>> list,
      {bool isSchedule = false}) {
    if (list.isEmpty) return const Center(child: Text('Nothing here'));
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final t in list) {
      final d = isSchedule &&
          (t['sessions'] != null && (t['sessions'] as List).isNotEmpty)
          ? (t['sessions'] as List)[0]['start'] as DateTime
          : t['date'] as DateTime;
      final key = DateFormat('yyyy-MM-dd').format(d);
      grouped.putIfAbsent(key, () => []).add(t);
    }
    final keys = grouped.keys.toList()..sort();
    return ListView(
      children: keys.map((k) {
        final dt = DateTime.parse(k);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(left: 16, top: 12, bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isSchedule ? TaskColors.blue : TaskColors.yellowDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                DateFormat('MMM dd').format(dt),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            TaskDisplay(
              tasks: grouped[k]!,
              sortingService: sorter,
              isSchedule: isSchedule,
              onReorder: (_, __) {},
              onEditTask: (_, updated) async {
                setState(() {
                  final idx = _tasks.indexWhere((t) => t['id'] == updated['id']);
                  if (idx != -1) _tasks[idx] = updated;
                });
                await _saveTasks();
              },
              onRemoveTask: (task) async {
                setState(() {
                  _tasks.removeWhere((t) => t['id'] == task['id']);
                });
                await _saveTasks();
              },
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _homePage() {
    final now = DateTime.now();
    final weekStart = now.subtract(const Duration(days: 1));
    final weekEnd = now.add(const Duration(days: 7));
    final weekTasks = _tasks.where((t) {
      final d = t['date'] as DateTime;
      return d.isAfter(weekStart) && d.isBefore(weekEnd);
    }).toList();
    final weekSchedules = _tasks.where((t) => t['sessions'] != null).where((t) {
      return (t['sessions'] as List).any((s) {
        final dt = s['start'] as DateTime;
        return dt.isAfter(weekStart) && dt.isBefore(weekEnd);
      });
    }).toList();
    final dayTasks = _tasks.where((t) => _sameDay(t['date'] as DateTime, _selected)).toList();
    final daySchedules = _tasks.where((t) => t['sessions'] != null).where((t) {
      return (t['sessions'] as List).any((s) => _sameDay(s['start'] as DateTime, _selected));
    }).toList();
    final displayTasks = _filteredByDay ? dayTasks : weekTasks;
    final displaySchedules = _filteredByDay ? daySchedules : weekSchedules;

    return Column(
      children: [
        Material(
          elevation: 4,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
          ),
          child: _showDailySchedule
              ? DailyScheduleGraph(
            records: [
              // classes
              ..._classRecords.map((c) {
                final t0 = c['start'] as TimeOfDay;
                final t1 = c['end'] as TimeOfDay;
                final ds = DateTime(
                    _selected.year, _selected.month, _selected.day,
                    t0.hour, t0.minute);
                final de = DateTime(
                    _selected.year, _selected.month, _selected.day,
                    t1.hour, t1.minute);
                return {
                  'subject': c['subject'],
                  'start': ds,
                  'end': de,
                  'day': c['day'],
                  'isAI': false,
                };
              }),
              // AI sessions
              ..._tasks.where((t) => t['sessions'] != null)
                  .expand<Map<String, dynamic>>((t) {
                return (t['sessions'] as List).map((s) {
                  final dt0 = s['start'] as DateTime;
                  final dt1 = s['end'] as DateTime;
                  return {
                    'subject': t['task'],
                    'start': dt0,
                    'end': dt1,
                    'day': DateFormat('EEEE').format(dt0),
                    'isAI': true,
                  };
                });
              }),
            ],
            selectedDate: _selected,
          )
              : TableCalendar(
            firstDay: DateTime.utc(2020), lastDay: DateTime.utc(2100),
            focusedDay: _focused,
            selectedDayPredicate: (d) => _sameDay(d, _selected),
            onDaySelected: (sel, foc) => setState(() {
              _selected = sel;
              _focused = foc;
              _filteredByDay = true;
            }),
            headerStyle: const HeaderStyle(formatButtonVisible: false),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: TaskColors.yellow.withAlpha(80),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: TaskColors.yellowDark,
                shape: BoxShape.circle,
              ),
            ),
            eventLoader: _getEventsForDay,
            calendarBuilders: CalendarBuilders(
              markerBuilder: (ctx, date, events) {
                final types = <String>{ for (var e in events) (e as Map)['type'] };
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: types.map((type) {
                    final color = type == 'session'
                        ? TaskColors.blue
                        : TaskColors.yellowDark;
                    return Container(
                      width: 6, height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ),
        if (_filteredByDay)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to full view'),
              onPressed: () => setState(() => _filteredByDay = false),
            ),
          ),
        const SizedBox(height: 6),
        Container(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(controller: _weekTab, tabs: const [
            Tab(text: 'Tasks'), Tab(text: 'Schedule')
          ]),
        ),
        Expanded(
          child: TabBarView(controller: _weekTab, children: [
            _buildGroup(displayTasks),
            _buildGroup(displaySchedules, isSchedule: true),
          ]),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LearnEase', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_nav == 0)
            IconButton(
              icon: Icon(_showDailySchedule ? Icons.calendar_today : Icons.schedule),
              tooltip: _showDailySchedule ? 'Show Calendar' : 'Show Daily Schedule',
              onPressed: () => setState(() => _showDailySchedule = !_showDailySchedule),
            ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: _nav == 3 ? 'Add Class' : 'Add Task',
            onPressed: () async {
              if (_nav == 3) {
                _classKey.currentState?.openEditor();
              } else {
                final res = await showDialog<Map<String, dynamic>>(
                  context: context,
                  builder: (_) => Dialog(child: TaskForm(onAddTask: _addTask)),
                );
                if (res != null) {
                  await _addTask(res['task'], res['date'], res['difficulty']);
                }
              }
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _nav,
        children: [
          _homePage(),
          _buildGroup(_tasks),
          _buildGroup(_tasks, isSchedule: true),
          ClassSchedulePage(
            key: _classKey,
            onRecordsChanged: (recs) => setState(() => _classRecords = recs),
          ),
          const ChatbotPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _nav,
        onTap: (i) => setState(() {
          _nav = i; if (i != 0) _showDailySchedule = false;
        }),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Tasks'),
          BottomNavigationBarItem(icon: Icon(Icons.schedule), label: 'Schedule'),
          BottomNavigationBarItem(icon: Icon(Icons.school), label: 'Classes'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chatbot'),
        ],
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
