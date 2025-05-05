import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, int> _tasksPerDay = {};
  List<Map<String, dynamic>> _tasksForSelectedDay = [];

  @override
  void initState() {
    super.initState();
    _fetchTasksForMonth(_focusedDay);
    _fetchTasksForDay(_focusedDay);
  }

  Future<void> _fetchTasksForMonth(DateTime month) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);

    final tasksSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('todos')
        .where('dueAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('dueAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .get();

    final tasks = tasksSnapshot.docs.map((doc) => doc.data()).toList();

    final Map<DateTime, int> tasksCount = {};
    for (var task in tasks) {
      final dueAt = (task['dueAt'] as Timestamp).toDate();
      final day = DateTime(dueAt.year, dueAt.month, dueAt.day);
      tasksCount[day] = (tasksCount[day] ?? 0) + 1;
    }

    setState(() {
      _tasksPerDay = tasksCount;
    });
  }

  Future<void> _fetchTasksForDay(DateTime day) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final tasksSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('todos')
        .where('dueAt', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(day.year, day.month, day.day)))
        .where('dueAt', isLessThan: Timestamp.fromDate(DateTime(day.year, day.month, day.day + 1)))
        .get();

    setState(() {
      _tasksForSelectedDay = tasksSnapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.background,
        foregroundColor: Theme.of(context).colorScheme.onBackground,
        title: const Text('Calendar'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.background),
              child: Text(
                'Options',
                style: TextStyle(color: Theme.of(context).colorScheme.onBackground, fontSize: 24),
              ),
            ),
            ListTile(
              leading: Icon(Icons.home, color: Theme.of(context).colorScheme.onBackground),
              title: Text('Home', style: TextStyle(color: Theme.of(context).colorScheme.onBackground)),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/home');
              },
            ),
            const Divider(color: Colors.grey),
            ListTile(
              leading: Icon(Icons.calendar_today, color: Theme.of(context).colorScheme.onBackground),
              title: Text('Calendar', style: TextStyle(color: Theme.of(context).colorScheme.onBackground)),
              onTap: () {
                Navigator.pop(context); // Close drawer if already on Calendar
              },
            ),
            const Divider(color: Colors.grey),
            ListTile(
              leading: Icon(Icons.settings, color: Theme.of(context).colorScheme.onBackground),
              title: Text('Settings', style: TextStyle(color: Theme.of(context).colorScheme.onBackground)),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/settings');
              },
            ),
          ],
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                _fetchTasksForDay(selectedDay);
              },
              onPageChanged: (focusedDay) {
                _fetchTasksForMonth(focusedDay);
                setState(() {
                  _focusedDay = focusedDay;
                });
              },
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.background,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onBackground,
                  shape: BoxShape.circle,
                ),
                defaultTextStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                weekendTextStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                selectedTextStyle: TextStyle(color: Theme.of(context).colorScheme.background),
                todayTextStyle: TextStyle(color: Theme.of(context).colorScheme.onBackground),
                markersAlignment: Alignment.bottomCenter,
                markersMaxCount: 3,
                markerDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onBackground, // Adjusts to light/dark mode
                  shape: BoxShape.circle,
                ),
              ),
              eventLoader: (day) {
                final dayKey = DateTime(day.year, day.month, day.day);
                final taskCount = _tasksPerDay[dayKey] ?? 0;
                return List.generate(taskCount, (index) => 'Task $index');
              },
              headerStyle: HeaderStyle(
                titleTextStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                formatButtonVisible: false,
                leftChevronIcon: Icon(Icons.chevron_left, color: Theme.of(context).colorScheme.onSurface),
                rightChevronIcon: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                weekendStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
              ),
            ),
            const SizedBox(height: 16),
            if (_tasksForSelectedDay.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _tasksForSelectedDay.length,
                  itemBuilder: (context, index) {
                    final task = _tasksForSelectedDay[index];
                    return ListTile(
                      title: Text(
                        task['text'] ?? 'Unnamed Task',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      ),
                      subtitle: task['dueAt'] != null
                          ? Text(
                              'Due: ${DateFormat.yMMMd().add_jm().format((task['dueAt'] as Timestamp).toDate())}',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                            )
                          : null,
                    );
                  },
                ),
              )
            else
              Expanded(
                child: Center(
                  child: Text(
                    'No tasks due on this day',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

