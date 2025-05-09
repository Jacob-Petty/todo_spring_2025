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
    if (_todos.isEmpty) return [];

    // Start with text search filtering
    final query = _searchController.text.toLowerCase();
    var list = _todos.where((t) => t.text.toLowerCase().contains(query)).toList();

    // Apply priority filter if set
    if (_filters.priority != null) {
      list = list.where((t) => (t.priority ?? 'medium').toLowerCase() == _filters.priority).toList();
    }

    // Apply category filter if set (new)
    if (_filters.category != null) {
      list = list.where((t) => (t.category ?? 'development').toLowerCase() == _filters.category).toList();
    }

    // Apply due date filter if set
    if (_filters.dueDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      switch (_filters.dueDate) {
        case 'overdue':
          list = list.where((t) =>
          t.dueAt != null &&
              t.dueAt!.isBefore(now) &&
              t.completedAt == null
          ).toList();
          break;
        case 'today':
          list = list.where((t) =>
          t.dueAt != null &&
              t.dueAt!.isAfter(today.subtract(const Duration(seconds: 1))) &&
              t.dueAt!.isBefore(tomorrow)
          ).toList();
          break;
        case 'future':
          list = list.where((t) =>
          t.dueAt != null &&
              t.dueAt!.isAfter(tomorrow.subtract(const Duration(seconds: 1)))
          ).toList();
          break;
      }
    }

    // Apply sorting
    int compareDates(DateTime a, DateTime b) =>
        _filters.order == 'ascending' ? a.compareTo(b) : b.compareTo(a);

    switch (_filters.sortBy) {
      case 'completed':
        list.sort(
              (a, b) => compareDates(a.completedAt ?? DateTime(0), b.completedAt ?? DateTime(0)),
        );
        break;
      case 'priority':
        list.sort((a, b) {
          // Convert priority to numeric value (high=3, medium=2, low=1, default=0)
          int getPriorityValue(String? priority) {
            if (priority == null) return 0;
            switch (priority.toLowerCase()) {
              case 'high': return 3;
              case 'medium': return 2;
              case 'low': return 1;
              default: return 0;
            }
          }

          final aValue = getPriorityValue(a.priority);
          final bValue = getPriorityValue(b.priority);

          // Sort by priority, and then by creation date if same priority
          if (aValue != bValue) {
            return _filters.order == 'ascending' ? aValue - bValue : bValue - aValue;
          } else {
            return compareDates(a.createdAt, b.createdAt);
          }
        });
        break;
      case 'category': // New category sorting option
        list.sort((a, b) {
          final aCategory = a.category ?? 'development';
          final bCategory = b.category ?? 'development';

          // Sort by category alphabetically, then by creation date if same category
          final categoryComparison = _filters.order == 'ascending'
              ? aCategory.compareTo(bCategory)
              : bCategory.compareTo(aCategory);

          if (categoryComparison != 0) {
            return categoryComparison;
          } else {
            return compareDates(a.createdAt, b.createdAt);
          }
        });
        break;
      case 'due':
        list.sort((a, b) {
          if (a.dueAt == null && b.dueAt == null) {
            return compareDates(a.createdAt, b.createdAt); // Both null, sort by creation date
          } else if (a.dueAt == null) {
            return _filters.order == 'ascending' ? 1 : -1; // a null goes last in ascending, first in descending
          } else if (b.dueAt == null) {
            return _filters.order == 'ascending' ? -1 : 1; // b null goes last in ascending, first in descending
          } else {
            return compareDates(a.dueAt!, b.dueAt!); // Both have due dates, compare normally
          }
        });
        break;
      case 'date':
      default:
        list.sort((a, b) => compareDates(a.createdAt, b.createdAt));
        break;
    }

    return list;
  }

  // Get category icon
  IconData _getCategoryIcon(String? category) {
    if (category == null) return Icons.category;

    switch (category.toLowerCase()) {
      case 'development':
        return Icons.code;
      case 'debugging':
        return Icons.bug_report;
      case 'testing':
        return Icons.science;
      case 'deployment':
        return Icons.rocket_launch;
      case 'docs':
        return Icons.description;
      case 'communication':
        return Icons.chat;
      default:
        return Icons.category;
    }
  }

  // Get category color
  Color _getCategoryColor(String? category) {
    if (category == null) return Colors.grey;

    switch (category.toLowerCase()) {
      case 'development':
        return Colors.blue;
      case 'debugging':
        return Colors.purple;
      case 'testing':
        return Colors.amber;
      case 'deployment':
        return Colors.teal;
      case 'docs':
        return Colors.indigo;
      case 'communication':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }


  String _readableDue(DateTime due) {
    final now = DateTime.now();
    final diff = due.difference(now);
    if (diff.isNegative) {
      final overdue = now.difference(due);
      final days = overdue.inDays;
      final hours = overdue.inHours % 24;
      final minutes = overdue.inMinutes % 60;
      if (days > 0) {
        return 'Overdue by $days day${days > 1 ? 's' : ''}, $hours hour${hours > 1 ? 's' : ''}, $minutes minute${minutes > 1 ? 's' : ''}';
      } else if (hours > 0) {
        return 'Overdue by $hours hour${hours > 1 ? 's' : ''}, $minutes minute${minutes > 1 ? 's' : ''}';
      } else if (minutes > 0) {
        return 'Overdue by $minutes minute${minutes > 1 ? 's' : ''}';
      } else {
        return 'Overdue by less than a minute';
      }
    } else {
      final days = diff.inDays;
      final hours = diff.inHours % 24;
      final minutes = diff.inMinutes % 60;
      if (days > 0) {
        return 'Due in $days day${days > 1 ? 's' : ''}, $hours hour${hours > 1 ? 's' : ''}, $minutes minute${minutes > 1 ? 's' : ''}';
      } else if (hours > 0) {
        return 'Due in $hours hour${hours > 1 ? 's' : ''}, $minutes minute${minutes > 1 ? 's' : ''}';
      } else if (minutes > 0) {
        return 'Due in $minutes minute${minutes > 1 ? 's' : ''}';
      } else {
        return 'Due in less than a minute';
      }
    }
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
      return Expanded(
        child: Center(
          child: Text(
            'No tasks found',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              fontSize: 16,
            ),
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
                  // Show category with icon (new)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getCategoryIcon(todo.category),
                        color: _getCategoryColor(todo.category),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        todo.category != null
                            ? todo.category!.substring(0, 1).toUpperCase() + todo.category!.substring(1)
                            : 'Development',
                        style: TextStyle(
                          fontSize: 12,
                          color: _getCategoryColor(todo.category),
                        ),
                      ),
                    ],
                  ),
                  if (todo.description != null && todo.description!.isNotEmpty)
                    Text(
                      todo.description!.length > 30
                          ? '${todo.description!.substring(0, 30)}...'
                          : todo.description!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
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
      backgroundColor: Theme.of(context).colorScheme.surface,
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
                Navigator.pop(context);
              },
            ),
            const Divider(color: Colors.grey),
            ListTile(
              leading: Icon(Icons.calendar_today, color: Theme.of(context).colorScheme.onSurface),
              title: Text('Calendar', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/calendar');
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
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        title: Row(
          children: [
            const SizedBox(width: 0),
            Text('Home', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
          ],
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, size: 32),
            padding: const EdgeInsets.all(4.0),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.asset(
              'assets/images/logo.png',
              height: 75,
              width: 75,
            ),
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
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                        labelText: 'Search Tasks',
                        labelStyle: const TextStyle(color: Colors.grey),
                        suffixIcon: Stack(
                          alignment: Alignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.filter_list, color: Colors.grey),
                              onPressed: () async {
                                final res = await showModalBottomSheet<FilterSheetResult>(
                                  context: context,
                                  backgroundColor: Colors.grey[900],
                                  builder: (_) => FilterSheet(initialFilters: _filters),
                                );
                                if (res != null) {
                                  setState(() {
                                    _filters = res;
                                    _filtered = _applyFilters();
                                  });
                                }
                              },
                            ),
                            if (_filters.priority != null || _filters.dueDate != null || _filters.category != null) // Added category to condition
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 8,
                                    minHeight: 8,
                                  ),
                                ),
                              ),
                          ],
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
        backgroundColor: Colors.black,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: _showCreateTaskPopup,
      ),
    );
  }
}