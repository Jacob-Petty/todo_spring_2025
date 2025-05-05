import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Add this import for formatting time

import '../data/todo.dart';
import 'details/detail_screen.dart';
import 'filter/filter_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controller = TextEditingController();
  final _searchController = TextEditingController();
  StreamSubscription<List<Todo>>? _todoSubscription;
  List<Todo> _todos = [];
  List<Todo>? _filteredTodos;
  FilterSheetResult _filters = FilterSheetResult(
    sortBy: 'date',
    order: 'descending',
  );
  bool _isSidePanelOpen = false; // Track if the side panel is open
  DateTime? _selectedDueDate; // Add a variable to store the selected due date

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _todoSubscription = getTodosForUser(user.uid).listen((todos) {
        setState(() {
          _todos = todos;
          _filteredTodos = filterTodos();
        });
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    _todoSubscription?.cancel();
    super.dispose();
  }

  List<Todo> filterTodos() {
    List<Todo> filteredTodos = _todos.where((todo) {
      return todo.text.toLowerCase().contains(_searchController.text.toLowerCase());
    }).toList();

    if (_filters.sortBy == 'date') {
      filteredTodos.sort((a, b) =>
          _filters.order == 'ascending' ? a.createdAt.compareTo(b.createdAt) : b.createdAt.compareTo(a.createdAt));
    } else if (_filters.sortBy == 'completed') {
      filteredTodos.sort((a, b) => _filters.order == 'ascending'
          ? (a.completedAt ?? DateTime(0)).compareTo(b.completedAt ?? DateTime(0))
          : (b.completedAt ?? DateTime(0)).compareTo(a.completedAt ?? DateTime(0)));
    }

    return filteredTodos;
  }

  Stream<List<Todo>> getTodosForUser(String userId) {
    return FirebaseFirestore.instance
        .collection('todos')
        .where('uid', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((querySnapshot) => querySnapshot.docs.map((doc) => Todo.fromSnapshot(doc)).toList());
  }

  String _getReadableDueDate(DateTime dueDate) {
    final now = DateTime.now();
    final difference = dueDate.difference(now);

    if (difference.inDays == 0) {
      final hoursLeft = (difference.inHours + 1); // Round up
      return 'Due in $hoursLeft hour${hoursLeft > 1 ? 's' : ''}';
    } else if (difference.inDays == 1) {
      final formattedTime = DateFormat.jm().format(dueDate); // Format time in 12-hour format
      return 'Due tomorrow at $formattedTime';
    } else if (difference.inDays < 7) {
      return 'Due in ${difference.inDays} day${difference.inDays > 1 ? 's' : ''}';
    } else {
      return 'Due on ${DateFormat.yMMMd().format(dueDate)}'; // Format as "MMM dd, yyyy"
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return MaterialApp(
      title: 'TODO App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              title: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isSidePanelOpen = true; // Open the side panel
                      });
                    },
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 40, // Adjust the height as needed
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Home'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    final shouldLogout = await showDialog<bool>(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text('Log Out'),
                          content: const Text('Are you sure you want to log out?'),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop(false); // User canceled
                              },
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop(true); // User confirmed
                              },
                              child: const Text('Log Out'),
                            ),
                          ],
                        );
                      },
                    );

                    if (shouldLogout == true) {
                      await FirebaseAuth.instance.signOut();
                    }
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.black, // Match the black color of the logo
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), // Add padding
                  ),
                  child: const Text(
                    'Log Out',
                    style: TextStyle(color: Colors.white), // Ensure text is visible
                  ),
                ),
              ],
            ),
            endDrawer: Drawer(
              child: Column(
                children: [
                  DrawerHeader(
                    decoration: BoxDecoration(color: Theme.of(context).primaryColor),
                    child: const Center(
                      child: Text(
                        'Side Window',
                        style: TextStyle(color: Colors.white, fontSize: 20),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.info),
                    title: const Text('Option 1'),
                    onTap: () {
                      // Handle option 1 tap
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text('Option 2'),
                    onTap: () {
                      // Handle option 2 tap
                    },
                  ),
                ],
              ),
            ),
            body: LayoutBuilder(
              builder: (context, constraints) {
                bool isDesktop = constraints.maxWidth > 600;
                return Center(
                  child: SizedBox(
                    width: isDesktop ? 600 : double.infinity,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search),
                              labelText: 'Search TODOs',
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.filter_list),
                                onPressed: () async {
                                  final result = await showModalBottomSheet<FilterSheetResult>(
                                    context: context,
                                    builder: (context) {
                                      return FilterSheet(initialFilters: _filters);
                                    },
                                  );

                                  if (result != null) {
                                    setState(() {
                                      _filters = result;
                                      _filteredTodos = filterTodos();
                                    });
                                  }
                                },
                              ),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _filteredTodos = filterTodos();
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: _filteredTodos?.isEmpty ?? true
                              ? const Center(child: Text('No TODOs found'))
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  itemCount: _filteredTodos?.length ?? 0,
                                  itemBuilder: (context, index) {
                                    final todo = _filteredTodos?[index];
                                    if (todo == null) return const SizedBox.shrink();
                                    return ListTile(
                                      leading: Checkbox(
                                        value: todo.completedAt != null,
                                        onChanged: (bool? value) {
                                          final updateData = {
                                            'completedAt': value == true ? FieldValue.serverTimestamp() : null
                                          };
                                          FirebaseFirestore.instance.collection('todos').doc(todo.id).update(updateData);
                                        },
                                      ),
                                      trailing: Icon(Icons.arrow_forward_ios),
                                      title: Text(
                                        todo.text,
                                        style: todo.completedAt != null
                                            ? const TextStyle(decoration: TextDecoration.lineThrough)
                                            : null,
                                      ),
                                      subtitle: todo.dueAt != null
                                          ? Text(
                                              _getReadableDueDate(todo.dueAt!),
                                              style: const TextStyle(
                                                color: Colors.black, // Match the font color to the aesthetic
                                                fontSize: 14, // Ensure consistent font size
                                              ),
                                            )
                                          : null,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => DetailScreen(todo: todo),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                        ),
                        Container(
                          color: Colors.green[100],
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      keyboardType: TextInputType.text,
                                      controller: _controller,
                                      decoration: const InputDecoration(
                                        labelText: 'Enter Task:',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () async {
                                      if (user != null && _controller.text.isNotEmpty) {
                                        await FirebaseFirestore.instance.collection('todos').add({
                                          'text': _controller.text,
                                          'createdAt': FieldValue.serverTimestamp(),
                                          'uid': user.uid,
                                          'dueAt': _selectedDueDate != null
                                              ? Timestamp.fromDate(_selectedDueDate!)
                                              : null,
                                        });
                                        _controller.clear();
                                        setState(() {
                                          _selectedDueDate = null; // Reset the due date
                                        });
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white, // Match the background color
                                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                    ),
                                    child: const Text(
                                      'Add Task',
                                      style: TextStyle(
                                        color: Colors.black, // Match the font color
                                        fontSize: 14, // Match the font size
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8.0, // Horizontal spacing between buttons
                                runSpacing: 8.0, // Vertical spacing between rows of buttons
                                children: [
                                  ElevatedButton(
                                    onPressed: () async {
                                      if (_selectedDueDate == null) {
                                        final selectedDate = await showDatePicker(
                                          context: context,
                                          initialDate: DateTime.now(),
                                          firstDate: DateTime.now(),
                                          lastDate: DateTime(2100),
                                        );

                                        if (selectedDate != null) {
                                          final selectedTime = await showTimePicker(
                                            context: context,
                                            initialTime: TimeOfDay.now(),
                                          );

                                          if (selectedTime != null) {
                                            setState(() {
                                              _selectedDueDate = DateTime(
                                                selectedDate.year,
                                                selectedDate.month,
                                                selectedDate.day,
                                                selectedTime.hour,
                                                selectedTime.minute,
                                              );
                                            });
                                          }
                                        }
                                      } else {
                                        showDialog(
                                          context: context,
                                          builder: (context) {
                                            return AlertDialog(
                                              title: const Text(
                                                'Select Date & Time',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                ),
                                              ),
                                              content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  ElevatedButton(
                                                    onPressed: () async {
                                                      final selectedDate = await showDatePicker(
                                                        context: context,
                                                        initialDate: _selectedDueDate ?? DateTime.now(),
                                                        firstDate: DateTime.now(),
                                                        lastDate: DateTime(2100),
                                                      );

                                                      if (selectedDate != null) {
                                                        final selectedTime = await showTimePicker(
                                                          context: context,
                                                          initialTime: TimeOfDay.fromDateTime(
                                                              _selectedDueDate ?? DateTime.now()),
                                                        );

                                                        if (selectedTime != null) {
                                                          setState(() {
                                                            _selectedDueDate = DateTime(
                                                              selectedDate.year,
                                                              selectedDate.month,
                                                              selectedDate.day,
                                                              selectedTime.hour,
                                                              selectedTime.minute,
                                                            );
                                                          });
                                                        }
                                                      }
                                                      Navigator.of(context).pop();
                                                    },
                                                    child: const Text(
                                                      'Pick Date & Time',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.black,
                                                      ),
                                                    ),
                                                  ),
                                                  if (_selectedDueDate != null)
                                                    ElevatedButton(
                                                      onPressed: () {
                                                        setState(() {
                                                          _selectedDueDate = null;
                                                        });
                                                        Navigator.of(context).pop();
                                                      },
                                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                      child: const Text(
                                                        'Remove Date & Time',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.of(context).pop();
                                                  },
                                                  child: const Text(
                                                    'Cancel',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white, // Match the background color
                                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                    ),
                                    child: Text(
                                      _selectedDueDate != null
                                          ? 'Due: ${DateFormat.yMMMd().add_jm().format(_selectedDueDate!)}'
                                          : 'Date & Time',
                                      style: const TextStyle(
                                        color: Colors.black, // Match the font color
                                        fontSize: 14, // Match the font size
                                      ),
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) {
                                          return AlertDialog(
                                            title: const Text('Add Image'),
                                            content: const SizedBox.shrink(),
                                            actions: [
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                },
                                                child: const Text('Close'),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white, // Match the background color
                                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                    ),
                                    child: const Text(
                                      'Image',
                                      style: TextStyle(
                                        color: Colors.black, // Match the font color
                                        fontSize: 14, // Match the font size
                                      ),
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) {
                                          return AlertDialog(
                                            title: const Text('Add Description'),
                                            content: const SizedBox.shrink(),
                                            actions: [
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                },
                                                child: const Text('Close'),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white, // Match the background color
                                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                    ),
                                    child: const Text(
                                      'Description',
                                      style: TextStyle(
                                        color: Colors.black, // Match the font color
                                        fontSize: 14, // Match the font size
                                      ),
                                    ),
                                  ),
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
          if (_isSidePanelOpen)
            Positioned(
              top: 0,
              left: 0, // Change to left for the panel to slide in from the left
              bottom: 0,
              width: 300, // Adjust the width of the side panel
              child: Material(
                elevation: 8,
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      color: Colors.black, // Change the color to black
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Side Panel',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () {
                              setState(() {
                                _isSidePanelOpen = false; // Close the side panel
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Hello',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
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
}

