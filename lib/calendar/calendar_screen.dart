import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../home/details/detail_screen.dart'; // Import DetailScreen
import '../data/todo.dart'; // Import Todo

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
  CalendarFormat _calendarFormat = CalendarFormat.month; // Add calendar format state

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
      _tasksForSelectedDay = tasksSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Include the document ID
        data['category'] = data['category'] ?? 'uncategorized'; // Ensure category is included
        return data;
      }).toList();
    });
  }

  String _formatDueDate(DateTime dueAt) {
    final now = DateTime.now();
    final difference = dueAt.difference(now);

    if (difference.isNegative) {
      if (now.day == dueAt.day && now.month == dueAt.month && now.year == dueAt.year) {
        final overdueMinutes = -difference.inMinutes;
        final overdueHours = overdueMinutes ~/ 60;
        final remainingMinutes = overdueMinutes % 60;
        return 'Overdue by ${overdueHours > 0 ? '$overdueHours hr${overdueHours > 1 ? 's' : ''} ' : ''}${remainingMinutes > 0 ? '$remainingMinutes min${remainingMinutes > 1 ? 's' : ''}' : ''}';
      }
      return 'Overdue';
    }

    if (now.day == dueAt.day && now.month == dueAt.month && now.year == dueAt.year) {
      final hours = difference.inHours;
      final minutes = difference.inMinutes % 60;
      return 'Due in ${hours > 0 ? '$hours hr${hours > 1 ? 's' : ''} ' : ''}${minutes > 0 ? '$minutes min${minutes > 1 ? 's' : ''}' : ''}';
    }

    return 'Due at ${DateFormat.jm().format(dueAt)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        title: const Text('Calendar'),
        actions: [
          DropdownButton<CalendarFormat>(
            value: _calendarFormat,
            dropdownColor: Theme.of(context).colorScheme.surface,
            icon: Icon(Icons.arrow_drop_down, color: Theme.of(context).colorScheme.onSurface),
            underline: Container(),
            onChanged: (CalendarFormat? newFormat) {
              if (newFormat != null) {
                setState(() {
                  _calendarFormat = newFormat;
                });
              }
            },
            items: [
              DropdownMenuItem(
                value: CalendarFormat.month,
                child: Text(
                  'Month View',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                ),
              ),
              DropdownMenuItem(
                value: CalendarFormat.week,
                child: Text(
                  'Week View',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                ),
              ),
            ],
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
              child: Text(
                'Options',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 24),
              ),
            ),
            ListTile(
              leading: Icon(Icons.home, color: Theme.of(context).colorScheme.onSurface),
              title: Text('Home', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/home');
              },
            ),
            const Divider(color: Colors.grey),
            ListTile(
              leading: Icon(Icons.calendar_today, color: Theme.of(context).colorScheme.onSurface),
              title: Text('Calendar', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              onTap: () {
                Navigator.pop(context); // Close drawer if already on Calendar
              },
            ),
            const Divider(color: Colors.grey),
            ListTile(
              leading: Icon(Icons.settings, color: Theme.of(context).colorScheme.onSurface),
              title: Text('Settings', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/settings');
              },
            ),
          ],
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
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
              calendarFormat: _calendarFormat, // Use the selected calendar format
              onFormatChanged: (format) {
                setState(() {
                  _calendarFormat = format;
                });
              },
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface,
                  shape: BoxShape.circle,
                ),
                defaultTextStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                weekendTextStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues()),
                selectedTextStyle: TextStyle(color: Theme.of(context).colorScheme.surface),
                todayTextStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                markersAlignment: Alignment.bottomCenter,
                markersMaxCount: 3,
                markerDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface, // Adjusts to light/dark mode
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
                weekdayStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues()),
                weekendStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues()),
              ),
            ),
            const SizedBox(height: 16),
            if (_tasksForSelectedDay.isNotEmpty)
              Expanded(
                child: ListView.separated(
                  itemCount: _tasksForSelectedDay.length,
                  itemBuilder: (context, index) {
                    final task = _tasksForSelectedDay[index];
                    return GestureDetector(
                      onTap: () async {
                        // Navigate to the detail screen and wait for it to return
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DetailScreen(
                              todo: Todo(
                                id: task['id'], // Pass the document ID
                                text: task['text'] ?? 'Unnamed Task',
                                uid: FirebaseAuth.instance.currentUser?.uid ?? '',
                                description: task['description'] ?? '',
                                dueAt: task['dueAt'] != null
                                    ? (task['dueAt'] as Timestamp).toDate()
                                    : null,
                                priority: task['priority'] ?? 'medium',
                                category: task['category'], // Pass the category
                                imageUrl: task['imageUrl'],
                                createdAt: task['createdAt'] != null
                                    ? (task['createdAt'] as Timestamp).toDate()
                                    : DateTime.now(),
                                completedAt: task['completedAt'] != null
                                    ? (task['completedAt'] as Timestamp).toDate()
                                    : null,
                              ),
                            ),
                          ),
                        );

                        // If the detail screen indicates that changes were made or a task was deleted, refresh the tasks
                        if (result == true) {
                          await _fetchTasksForDay(_selectedDay ?? _focusedDay);
                          await _fetchTasksForMonth(_focusedDay);
                        }
                      },
                      child: ListTile(
                        title: Text(
                          task['text'] ?? 'Unnamed Task',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (task['dueAt'] != null)
                              Text(
                                _formatDueDate((task['dueAt'] as Timestamp).toDate()),
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                              ),
                            if (task['category'] != null)
                              Text(
                                'Category: ${task['category'][0].toUpperCase()}${task['category'].substring(1)}',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (context, index) => Divider(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    thickness: 1,
                  ),
                ),
              )
            else
              Expanded(
                child: Center(
                  child: Text(
                    'No tasks due on this day',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(),
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

