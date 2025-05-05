import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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

class _HomeScreenState extends State<HomeScreen> {
  final _taskController = TextEditingController();
  final _searchController = TextEditingController();

  late final stt.SpeechToText _speech;
  StreamSubscription<List<Todo>>? _todoSub;

  List<Todo> _todos = [];
  List<Todo>? _filtered;
  FilterSheetResult _filters = FilterSheetResult(sortBy: 'date', order: 'descending');

  bool _isListening = false;
  bool _drawerOpen = false;
  DateTime? _selectedDue;
  String? _selectedImagePath;
  String? _selectedImageUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();

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
    _taskController.dispose();
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

  Future<void> _addTodo(User user) async {
    if (_taskController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task description')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      String? imageUrl;

      // If there's a selected image, upload it first
      if (_selectedImagePath != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('users/${user.uid}/images/${DateTime.now().millisecondsSinceEpoch}.jpg');

        await storageRef.putFile(File(_selectedImagePath!));
        imageUrl = await storageRef.getDownloadURL();
      }

      // Add the todo with the image URL if available
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('todos')
          .add({
        'text': _taskController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'dueAt': _selectedDue == null ? null : Timestamp.fromDate(_selectedDue!),
        'imageUrl': imageUrl ?? _selectedImageUrl,
      });

      // Reset all input fields
      _taskController.clear();
      setState(() {
        _selectedDue = null;
        _selectedImagePath = null;
        _selectedImageUrl = null;
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task added successfully!')),
      );
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add task: $e')),
      );
    }
  }

  Future<void> _selectImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImagePath = pickedFile.path;
        // No need to upload yet - we'll do that when adding the task
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image selected! Add a task to save it.')),
      );
    }
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

  IconButton _micButton() => IconButton(
    icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
    onPressed: _isListening ? _stopListening : _startListening,
  );

  Future<void> _startListening() async {
    if (await _speech.initialize(
      onStatus: (s) => debugPrint('Speech status: $s'),
      onError: (e) => debugPrint('Speech error : $e'),
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

  Widget _imageButton(User user) {
    // Show different button based on whether an image is selected
    if (_selectedImagePath != null) {
      return ElevatedButton.icon(
        icon: const Icon(Icons.check_circle),
        label: const Text('Image Selected', style: TextStyle(color: Colors.green, fontSize: 14)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: Colors.green, width: 2),
        ),
        onPressed: () => _selectImage(),
      );
    } else {
      return ElevatedButton.icon(
        icon: const Icon(Icons.image),
        label: const Text('Add Image', style: TextStyle(color: Colors.black, fontSize: 14)),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
        onPressed: () => _selectImage(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return MaterialApp(
      title: 'TODO App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: Stack(
        children: [
          Scaffold(
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
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Log Out')),
                        ],
                      ),
                    );
                    if (confirm == true) await FirebaseAuth.instance.signOut();
                  },
                ),
              ],
            ),
            body: LayoutBuilder(
              builder: (_, c) {
                final wide = c.maxWidth > 600;
                final width = wide ? 600.0 : double.infinity;

                return Center(
                  child: SizedBox(
                    width: width,
                    child: Column(
                      children: [
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
                        Expanded(
                          child: _filtered?.isEmpty ?? true
                              ? const Center(child: Text('No TODOs found'))
                              : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            itemCount: _filtered!.length,
                            itemBuilder: (_, i) {
                              final t = _filtered![i];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                child: ListTile(
                                  leading: Checkbox(
                                    value: t.completedAt != null,
                                    onChanged: (v) => FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(user!.uid)
                                        .collection('todos')
                                        .doc(t.id)
                                        .update({'completedAt': v! ? FieldValue.serverTimestamp() : null}),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (t.imageUrl != null)
                                        const Icon(Icons.image, color: Colors.blue),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.arrow_forward_ios),
                                    ],
                                  ),
                                  title: Text(
                                    t.text,
                                    style: t.completedAt != null
                                        ? const TextStyle(decoration: TextDecoration.lineThrough)
                                        : null,
                                  ),
                                  subtitle: t.dueAt == null
                                      ? null
                                      : Text(_readableDue(t.dueAt!), style: const TextStyle(fontSize: 14)),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => DetailScreen(todo: t)),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Container(
                          color: Colors.green[100],
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Show selected image preview
                              if (_selectedImagePath != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: Image.file(
                                          File(_selectedImagePath!),
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: const Text('Image will be attached to your task'),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close),
                                        onPressed: () => setState(() => _selectedImagePath = null),
                                      ),
                                    ],
                                  ),
                                ),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _taskController,
                                      decoration: const InputDecoration(
                                        labelText: 'Enter Task:',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _micButton(),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      child: _isUploading
                                          ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                          : const Text('Add Task',
                                          style: TextStyle(color: Colors.black, fontSize: 16)),
                                      onPressed: _isUploading ? null : () => user == null ? null : _addTodo(user),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  // Date & Time button
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.calendar_today, size: 16),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                                    label: Text(
                                      _selectedDue == null
                                          ? 'Set Due Date'
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
                                                ElevatedButton(
                                                  onPressed: () async {
                                                    await pickDateTime();
                                                    Navigator.pop(context);
                                                  },
                                                  child: const Text('Pick Date & Time'),
                                                ),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                  onPressed: () {
                                                    setState(() => _selectedDue = null);
                                                    Navigator.pop(context);
                                                  },
                                                  child: const Text('Remove Date & Time'),
                                                ),
                                              ],
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: const Text('Cancel'),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    },
                                  ),

                                  // Image button - now only selects image without creating a task
                                  _imageButton(user!),
                                ],
                              ),
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
        ],
      ),
    );
  }
}