import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../data/todo.dart';
import 'details/detail_screen.dart';
import 'filter/filter_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/* ────────────────────────────────────────────────────────────────────────── */

class _HomeScreenState extends State<HomeScreen> {
  final _taskController   = TextEditingController();
  final _searchController = TextEditingController();

  late final stt.SpeechToText _speech;
  StreamSubscription<List<Todo>>? _todoSub;

  List<Todo> _todos = [];
  List<Todo>? _filtered;
  FilterSheetResult _filters = FilterSheetResult(sortBy: 'date', order: 'descending');

  bool _isListening   = false;
  bool _drawerOpen    = false;
  DateTime? _selectedDue;

  /* ───────────────────────── Init / dispose ──────────────────────────── */

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _todoSub = _userTodos(user.uid).listen((t) {
        setState(() {
          _todos     = t;
          _filtered  = _applyFilters();
        });
      });
    }
  }

  @override
  void dispose() {
    _taskController.dispose();
    _searchController.dispose();
    _todoSub?.cancel();
    super.dispose();
  }

  /* ───────────────────── Speech-to-text helpers ─────────────────────── */

  Future<void> _startListening() async {
    if (await _speech.initialize(
      onStatus:  (s) => debugPrint('Speech status: $s'),
      onError:   (e) => debugPrint('Speech error : $e'),
    )) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (r) => setState(() => _taskController.text = r.recognizedWords),
      );
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  /* ─────────────────────── Todo-handling helpers ────────────────────── */

  Stream<List<Todo>> _userTodos(String uid) => FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('todos')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((qs) => qs.docs.map(Todo.fromSnapshot).toList());

  Future<void> _addTodo(User user) async {
    if (_taskController.text.trim().isEmpty) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('todos')
        .add({
      'text'      : _taskController.text.trim(),
      'createdAt' : FieldValue.serverTimestamp(),
      'dueAt'     : _selectedDue == null ? null : Timestamp.fromDate(_selectedDue!),
    });
    _taskController.clear();
    setState(() => _selectedDue = null);
  }

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
    final now  = DateTime.now();
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

  /* ────────────────────────── UI helpers ─────────────────────────────── */

  IconButton _micButton() => IconButton(
    icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
    onPressed: _isListening ? _stopListening : _startListening,
  );

  /* ───────────────────────────────── UI ──────────────────────────────── */

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return MaterialApp(
      title: 'TODO App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: Stack(
        children: [
          Scaffold(
            /* ───────────── AppBar ───────────── */
            appBar: AppBar(
              title: Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _drawerOpen = true),
                    child: Image.asset('assets/images/logo.png', height: 40),
                  ),
                  const SizedBox(width: 8),
                  const Text('Home'),
                ],
              ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(backgroundColor: Colors.black),
                  child: const Text('Log Out', style: TextStyle(color: Colors.white)),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Log Out'),
                        content: const Text('Are you sure you want to log out?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(context, true),  child: const Text('Log Out')),
                        ],
                      ),
                    );
                    if (confirm == true) await FirebaseAuth.instance.signOut();
                  },
                ),
              ],
            ),

            /* ───────────── Drawer ───────────── */
            endDrawer: Drawer(
              child: Column(
                children: [
                  DrawerHeader(
                    decoration: BoxDecoration(color: Theme.of(context).primaryColor),
                    child: const Center(
                      child: Text('Side Window', style: TextStyle(color: Colors.white, fontSize: 20)),
                    ),
                  ),
                  ListTile(leading: const Icon(Icons.info),     title: const Text('Option 1'), onTap: () {}),
                  ListTile(leading: const Icon(Icons.settings), title: const Text('Option 2'), onTap: () {}),
                  const SizedBox(height: 16),

                  /* drawer todo-list */
                  Expanded(
                    child: _filtered?.isEmpty ?? true
                        ? const Center(child: Text('No TODOs found'))
                        : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: _filtered!.length,
                      itemBuilder: (_, i) {
                        final t = _filtered![i];
                        return ListTile(
                          leading: Checkbox(
                            value: t.completedAt != null,
                            onChanged: (v) => FirebaseFirestore.instance
                                .collection('users')
                                .doc(user!.uid)
                                .collection('todos')
                                .doc(t.id)
                                .update({'completedAt': v! ? FieldValue.serverTimestamp() : null}),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          title: Text(
                            t.text,
                            style: t.completedAt != null ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
                          ),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(todo: t))),
                        );
                      },
                    ),
                  ),

                  /* drawer add-row (with mic) */
                  Container(
                    color: Colors.green[100],
                    padding: const EdgeInsets.all(32),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(controller: _taskController, decoration: const InputDecoration(labelText: 'Enter Task:')),
                        ),
                        const SizedBox(width: 8),
                        _micButton(),
                        ElevatedButton(child: const Text('Add'), onPressed: () => user == null ? null : _addTodo(user)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            /* ───────────── Body ───────────── */
            body: LayoutBuilder(
              builder: (_, c) {
                final wide = c.maxWidth > 600;
                final width = wide ? 600.0 : double.infinity;

                return Center(
                  child: SizedBox(
                    width: width,
                    child: Column(
                      children: [
                        /* search bar + filter */
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search),
                              labelText: 'Search TODOs',
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.filter_list),
                                onPressed: () async {
                                  final res = await showModalBottomSheet<FilterSheetResult>(
                                    context: context,
                                    builder: (_) => FilterSheet(initialFilters: _filters),
                                  );
                                  if (res != null) setState(() => _filters = res);
                                },
                              ),
                            ),
                            onChanged: (_) => setState(() => _filtered = _applyFilters()),
                          ),
                        ),
                        const SizedBox(height: 16),

                        /* main todo-list */
                        Expanded(
                          child: _filtered?.isEmpty ?? true
                              ? const Center(child: Text('No TODOs found'))
                              : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            itemCount: _filtered!.length,
                            itemBuilder: (_, i) {
                              final t = _filtered![i];
                              return ListTile(
                                leading: Checkbox(
                                  value: t.completedAt != null,
                                  onChanged: (v) => FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(user!.uid)
                                      .collection('todos')
                                      .doc(t.id)
                                      .update({'completedAt': v! ? FieldValue.serverTimestamp() : null}),
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios),
                                title: Text(
                                  t.text,
                                  style: t.completedAt != null ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
                                ),
                                subtitle: t.dueAt == null ? null : Text(_readableDue(t.dueAt!), style: const TextStyle(fontSize: 14)),
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(todo: t))),
                              );
                            },
                          ),
                        ),

                        /* add-task bar (mic permanently visible) */
                        Container(
                          color: Colors.green[100],
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _taskController,
                                      decoration: const InputDecoration(labelText: 'Enter Task:'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _micButton(),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                                    child: const Text('Add Task', style: TextStyle(color: Colors.black, fontSize: 14)),
                                    onPressed: () => user == null ? null : _addTodo(user),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              /* due-date & misc buttons (unchanged) */
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                                    child: Text(
                                      _selectedDue == null
                                          ? 'Date & Time'
                                          : 'Due: ${DateFormat.yMMMd().add_jm().format(_selectedDue!)}',
                                      style: const TextStyle(color: Colors.black, fontSize: 14),
                                    ),
                                    onPressed: () async {
                                      Future<void> pickDateTime() async {
                                        final date = await showDatePicker(
                                          context: context,
                                          initialDate: _selectedDue ?? DateTime.now(),
                                          firstDate: DateTime.now(),
                                          lastDate: DateTime(2100),
                                        );
                                        if (date != null) {
                                          final time = await showTimePicker(
                                            context: context,
                                            initialTime: TimeOfDay.fromDateTime(_selectedDue ?? DateTime.now()),
                                          );
                                          if (time != null) {
                                            setState(() {
                                              _selectedDue = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                                            });
                                          }
                                        }
                                      }

                                      if (_selectedDue == null) {
                                        await pickDateTime();
                                      } else {
                                        await showDialog(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text('Select Date & Time'),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                ElevatedButton(onPressed: () async { await pickDateTime(); Navigator.pop(context); }, child: const Text('Pick Date & Time')),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                  onPressed: () { setState(() => _selectedDue = null); Navigator.pop(context); },
                                                  child: const Text('Remove Date & Time'),
                                                ),
                                              ],
                                            ),
                                            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))],
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                  _placeholderBtn('Image'),
                                  _placeholderBtn('Description'),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          /* ───────────── simple left-side panel ───────────── */
          if (_drawerOpen)
            Positioned(
              top: 0,
              left: 0,
              bottom: 0,
              width: 300,
              child: Material(
                elevation: 8,
                color: Colors.white,
                child: Column(
                  children: [
                    Container(
                      color: Colors.black,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Side Panel', style: TextStyle(color: Colors.white, fontSize: 18)),
                          IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => setState(() => _drawerOpen = false)),
                        ],
                      ),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text('Hello', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /* helper for placeholder buttons */
  ElevatedButton _placeholderBtn(String label) => ElevatedButton(
    style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
    child: Text(label, style: const TextStyle(color: Colors.black, fontSize: 14)),
    onPressed: () => showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Add $label'),
        content: const SizedBox.shrink(),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    ),
  );
}