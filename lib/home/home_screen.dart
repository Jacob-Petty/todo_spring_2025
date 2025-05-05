import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/todo.dart';
import 'details/detail_screen.dart';
import 'filter/filter_sheet.dart';
import 'tasks/task_creation_popup.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  StreamSubscription<List<Todo>>? _todoSub;

  List<Todo> _todos = [];
  List<Todo>? _filtered;
  FilterSheetResult _filters = FilterSheetResult(sortBy: 'date', order: 'descending');

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _todoSub = _userTodos(user.uid).listen((t) {
        setState(() {
          _todos = t;
          _filtered = _applyFilters();
        });
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _todoSub?.cancel();
    super.dispose();
  }

  Stream<List<Todo>> _userTodos(String uid) => FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('todos')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((qs) => qs.docs.map(Todo.fromSnapshot).toList());

  List<Todo> _applyFilters() {
    final query = _searchController.text.toLowerCase();

    final list = _todos.where((t) => t.text.toLowerCase().contains(query)).toList();

    int compareDates(DateTime a, DateTime b) =>
        _filters.order == 'ascending' ? a.compareTo(b) : b.compareTo(a);

    switch (_filters.sortBy) {
      case 'completed':
        list.sort(
              (a, b) => compareDates(a.completedAt ?? DateTime(0), b.completedAt ?? DateTime(0)),
        );
      case 'date':
      default:
        list.sort((a, b) => compareDates(a.createdAt, b.createdAt));
    }
    return list;
  }

  String _readableDue(DateTime due) {
    final now = DateTime.now();
    final diff = due.difference(now);

    if (diff.inDays == 0) {
      final h = diff.inHours + 1;
      return 'Due in $h hour${h > 1 ? 's' : ''}';
    }
    if (diff.inDays == 1) {
      return 'Due tomorrow at ${DateFormat.jm().format(due)}';
    }
    if (diff.inDays < 7) {
      return 'Due in ${diff.inDays} day${diff.inDays > 1 ? 's' : ''}';
    }
    return 'Due on ${DateFormat.yMMMd().format(due)}';
  }

  Future<void> _showCreateTaskPopup() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const TaskCreationPopup(),
    );

    // If result is true, a task was created
    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task created successfully!')),
      );
    }
  }

  Widget _buildTodoList() {
    if (_filtered?.isEmpty ?? true) {
      return const Expanded(
        child: Center(
          child: Text(
            'No tasks found',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Expanded(
        child: Center(
            child: Text(
              'You need to be logged in to view tasks',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            )
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: _filtered!.length,
        itemBuilder: (_, i) {
          final todo = _filtered![i];
          return Card(
            color: Colors.grey[850],
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: ListTile(
              leading: Checkbox(
                value: todo.completedAt != null,
                fillColor: MaterialStateProperty.resolveWith<Color>((states) {
                  if (states.contains(MaterialState.selected)) {
                    return _getPriorityColor(todo);
                  }
                  return Colors.grey;
                }),
                onChanged: (v) => FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('todos')
                    .doc(todo.id)
                    .update({'completedAt': v! ? FieldValue.serverTimestamp() : null}),
              ),
              title: Text(
                todo.text,
                style: TextStyle(
                  color: Colors.white,
                  decoration: todo.completedAt != null
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (todo.dueAt != null)
                    Text(
                      _readableDue(todo.dueAt!),
                      style: TextStyle(
                        fontSize: 12,
                        color: todo.dueAt!.isBefore(DateTime.now())
                            ? Colors.red[300]
                            : Colors.grey,
                      ),
                    ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (todo.imageUrl != null)
                    const Icon(Icons.image, color: Colors.blue, size: 20),
                  const SizedBox(width: 4),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _getPriorityColor(todo),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white70),
                ],
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DetailScreen(todo: todo)),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getPriorityColor(Todo todo) {
    // Default to medium priority (orange) if not specified
    final priority = todo.priority ?? 'medium';

    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'med':
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.orange; // Default to medium priority color
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('My Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Navigate to settings screen
              // Navigator.pushNamed(context, '/settings');
            },
          ),
          TextButton(
            style: TextButton.styleFrom(backgroundColor: Colors.grey[800]),
            child: const Text('Log Out', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: Colors.grey[900],
                  title: const Text('Log Out', style: TextStyle(color: Colors.white)),
                  content: const Text('Are you sure you want to log out?',
                      style: TextStyle(color: Colors.white)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Log Out'),
                    ),
                  ],
                ),
              );
              if (confirm == true) await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (_, constraints) {
          final wide = constraints.maxWidth > 600;
          final width = wide ? 600.0 : double.infinity;

          return Center(
            child: SizedBox(
              width: width,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        labelText: 'Search Tasks',
                        labelStyle: const TextStyle(color: Colors.grey),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.filter_list, color: Colors.grey),
                          onPressed: () async {
                            final res = await showModalBottomSheet<FilterSheetResult>(
                              context: context,
                              builder: (_) => FilterSheet(initialFilters: _filters),
                            );
                            if (res != null) setState(() => _filters = res);
                          },
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey, width: 1.0),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue, width: 2.0),
                        ),
                      ),
                      onChanged: (_) => setState(() => _filtered = _applyFilters()),
                    ),
                  ),

                  // Todo list
                  _buildTodoList(),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green[700],
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: _showCreateTaskPopup,
      ),
    );
  }
}