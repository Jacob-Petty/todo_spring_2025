import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import '../../data/todo.dart';

// Priority levels for tasks
enum TaskPriority { high, medium, low }

// Task categories
enum TaskCategory { development, debugging, testing, deployment, docs, communication }

class TaskCreationPopup extends StatefulWidget {
  const TaskCreationPopup({super.key});

  @override
  State<TaskCreationPopup> createState() => _TaskCreationPopupState();
}

class _TaskCreationPopupState extends State<TaskCreationPopup> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  TaskPriority _priority = TaskPriority.medium;
  TaskCategory _category = TaskCategory.development; // Default category
  DateTime? _dueDate;
  String? _imagePath;
  bool _isLoading = false;

  // Speech recognition
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechEnabled = false;
  bool _isListeningForTitle = false;
  bool _isListeningForDescription = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  // Initialize speech recognition
  void _initSpeech() async {
    _speechEnabled = await _speech.initialize();
    setState(() {});
  }

  // Start listening for speech
  void _startListeningForTitle() {
    if (_speechEnabled) {
      setState(() {
        _isListeningForTitle = true;
        _isListeningForDescription = false;
      });
      _speech.listen(
        onResult: _onSpeechResultForTitle,
        listenFor: const Duration(seconds: 30),
        localeId: "en_US",
        cancelOnError: true,
        partialResults: true,
      );
    }
  }

  void _startListeningForDescription() {
    if (_speechEnabled) {
      setState(() {
        _isListeningForTitle = false;
        _isListeningForDescription = true;
      });
      _speech.listen(
        onResult: _onSpeechResultForDescription,
        listenFor: const Duration(seconds: 30),
        localeId: "en_US",
        cancelOnError: true,
        partialResults: true,
      );
    }
  }

  // Stop listening for speech
  void _stopListening() {
    _speech.stop();
    setState(() {
      _isListeningForTitle = false;
      _isListeningForDescription = false;
    });
  }

  // Handle speech results for title
  void _onSpeechResultForTitle(SpeechRecognitionResult result) {
    setState(() {
      _titleController.text = result.recognizedWords;
    });
  }

  // Handle speech results for description
  void _onSpeechResultForDescription(SpeechRecognitionResult result) {
    setState(() {
      _descriptionController.text = result.recognizedWords;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _imagePath = pickedFile.path;
      });
    }
  }

  void _removeImage() {
    setState(() {
      _imagePath = null;
    });
  }

  Future<void> _selectDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.green,
              onPrimary: Colors.white,
              surface: Colors.grey,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: Colors.grey[900],
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_dueDate ?? DateTime.now()),
        builder: (context, child) {
          return Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: Colors.green,
                onPrimary: Colors.white,
                surface: Colors.grey,
                onSurface: Colors.white,
              ),
              dialogBackgroundColor: Colors.grey[900],
            ),
            child: child!,
          );
        },
      );

      if (time != null) {
        setState(() {
          _dueDate = DateTime(
              date.year,
              date.month,
              date.day,
              time.hour,
              time.minute
          );
        });
      }
    }
  }

  // Convert TaskCategory enum to string
  String _categoryToString(TaskCategory category) {
    switch (category) {
      case TaskCategory.development:
        return 'development';
      case TaskCategory.debugging:
        return 'debugging';
      case TaskCategory.testing:
        return 'testing';
      case TaskCategory.deployment:
        return 'deployment';
      case TaskCategory.docs:
        return 'docs';
      case TaskCategory.communication:
        return 'communication';
    }
  }

  // Get display text for category
  String _getCategoryDisplayText(TaskCategory category) {
    switch (category) {
      case TaskCategory.development:
        return 'Development';
      case TaskCategory.debugging:
        return 'Debugging';
      case TaskCategory.testing:
        return 'Testing';
      case TaskCategory.deployment:
        return 'Deployment';
      case TaskCategory.docs:
        return 'Docs';
      case TaskCategory.communication:
        return 'Communication';
    }
  }

  Future<void> _createTask() async {
    // Validate inputs
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task title')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to create tasks');
      }

      String? imageUrl;

      // Upload image if selected
      if (_imagePath != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('users/${user.uid}/images/${DateTime.now().millisecondsSinceEpoch}.jpg');

        await storageRef.putFile(File(_imagePath!));
        imageUrl = await storageRef.getDownloadURL();
      }

      // Convert priority to string for storage
      String priorityString;
      switch (_priority) {
        case TaskPriority.high:
          priorityString = 'high';
          break;
        case TaskPriority.medium:
          priorityString = 'medium';
          break;
        case TaskPriority.low:
          priorityString = 'low';
          break;
      }

      // Convert category to string
      String categoryString = _categoryToString(_category);

      // Create the task in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('todos')
          .add({
        'text': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'priority': priorityString,
        'category': categoryString, // Add category to Firestore
        'createdAt': FieldValue.serverTimestamp(),
        'dueAt': _dueDate == null ? null : Timestamp.fromDate(_dueDate!),
        'imageUrl': imageUrl,
        'uid': user.uid,
      });

      // Success - close the popup
      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (error) {
      print('Error creating task: $error');

      // If there was an error and we had uploaded an image, try to delete it
      if (_imagePath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create task: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Create New Task',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Title field with voice input
              const Text(
                'Title',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _titleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Enter task title',
                        hintStyle: const TextStyle(color: Colors.grey),
                        border: const OutlineInputBorder(),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey, width: 1.0),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue, width: 2.0),
                        ),
                        suffixIcon: _isListeningForTitle
                            ? IconButton(
                          icon: const Icon(Icons.mic, color: Colors.red),
                          onPressed: _stopListening,
                        )
                            : IconButton(
                          icon: const Icon(Icons.mic, color: Colors.white),
                          onPressed: _speechEnabled ? _startListeningForTitle : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Description field with voice input
              const Text(
                'Description',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter task description',
                  hintStyle: const TextStyle(color: Colors.grey),
                  border: const OutlineInputBorder(),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey, width: 1.0),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue, width: 2.0),
                  ),
                  suffixIcon: _isListeningForDescription
                      ? IconButton(
                    icon: const Icon(Icons.mic, color: Colors.red),
                    onPressed: _stopListening,
                  )
                      : IconButton(
                    icon: const Icon(Icons.mic, color: Colors.white),
                    onPressed: _speechEnabled ? _startListeningForDescription : null,
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Category dropdown
              const Text(
                'Category',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey, width: 1.0),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                width: double.infinity,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<TaskCategory>(
                    value: _category,
                    dropdownColor: Colors.grey[800],
                    style: const TextStyle(color: Colors.white),
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                    items: TaskCategory.values.map((TaskCategory category) {
                      return DropdownMenuItem<TaskCategory>(
                        value: category,
                        child: Text(_getCategoryDisplayText(category)),
                      );
                    }).toList(),
                    onChanged: (TaskCategory? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _category = newValue;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Priority selection
              const Text(
                'Priority',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _PriorityButton(
                    label: 'High',
                    color: Colors.red,
                    isSelected: _priority == TaskPriority.high,
                    onTap: () => setState(() => _priority = TaskPriority.high),
                  ),
                  const SizedBox(width: 8),
                  _PriorityButton(
                    label: 'Medium',
                    color: Colors.orange,
                    isSelected: _priority == TaskPriority.medium,
                    onTap: () => setState(() => _priority = TaskPriority.medium),
                  ),
                  const SizedBox(width: 8),
                  _PriorityButton(
                    label: 'Low',
                    color: Colors.green,
                    isSelected: _priority == TaskPriority.low,
                    onTap: () => setState(() => _priority = TaskPriority.low),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Due date and Image buttons in a row with equal width
              Row(
                children: [
                  // Due date button
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        _dueDate == null
                            ? 'Set Due Date'
                            : 'Due: ${DateFormat.yMMMd().add_jm().format(_dueDate!)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _selectDueDate,
                    ),
                  ),
                  // Add clear button if date is set
                  if (_dueDate != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white),
                      onPressed: () => setState(() => _dueDate = null),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Image section with equal width button
              _imagePath == null
                  ? Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.image),
                      label: const Text('Add Image'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _pickImage,
                    ),
                  ),
                ],
              )
                  : Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_imagePath!),
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.delete),
                    label: const Text('Remove Image'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[800],
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _removeImage,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Create and Cancel buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _isLoading ? null : _createTask,
                      child: _isLoading
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Text('Create Task'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriorityButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _PriorityButton({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.7) : Colors.grey[800],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color : Colors.grey,
              width: 2,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}