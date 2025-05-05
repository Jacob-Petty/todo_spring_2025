import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../data/todo.dart';

// Priority levels for tasks
enum TaskPriority { high, medium, low }

class DetailScreen extends StatefulWidget {
  final Todo todo;

  const DetailScreen({super.key, required this.todo});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  bool _isLoading = false;
  String? _errorMessage;
  TaskPriority _priority = TaskPriority.medium;
  DateTime? _selectedDueDate;

  // Add this to track edit mode
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.todo.text);
    _descriptionController = TextEditingController(text: widget.todo.description ?? '');
    _selectedDueDate = widget.todo.dueAt;

    // Set initial priority from todo
    if (widget.todo.priority != null) {
      switch (widget.todo.priority) {
        case 'high':
          _priority = TaskPriority.high;
          break;
        case 'medium':
          _priority = TaskPriority.medium;
          break;
        case 'low':
          _priority = TaskPriority.low;
          break;
      }
    }

    print('Todo image URL in initState: ${widget.todo.imageUrl}');
    print('Todo due date: ${widget.todo.dueAt}');
    print('Todo priority: ${widget.todo.priority}');
    print('Todo description: ${widget.todo.description}');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    // Prevent this action if not in edit mode
    if (!_isEditMode) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          throw Exception('You must be logged in to upload images');
        }

        // Upload image to Firebase Storage
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('users/${user.uid}/images/${DateTime.now().millisecondsSinceEpoch}.jpg');

        await storageRef.putFile(File(pickedFile.path));
        final imageUrl = await storageRef.getDownloadURL();

        // Update Firestore document
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('todos')
            .doc(widget.todo.id)
            .update({'imageUrl': imageUrl});

        // Update local state
        setState(() {
          widget.todo.imageUrl = imageUrl;
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image updated successfully!')),
          );
        }
      } catch (error) {
        print('Error uploading image: $error');
        setState(() {
          _errorMessage = 'Failed to upload image: $error';
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload image: $error')),
          );
        }
      }
    }
  }

  Future<void> _deleteImage() async {
    // Prevent this action if not in edit mode
    if (!_isEditMode) return;

    if (widget.todo.imageUrl == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to delete images');
      }

      // First try to delete the image from storage if possible
      try {
        final ref = FirebaseStorage.instance.refFromURL(widget.todo.imageUrl!);
        await ref.delete();
      } catch (e) {
        // It's okay if we can't delete from storage (might be external URL)
        print('Could not delete from storage: $e');
      }

      // Update Firestore document first to prevent race conditions
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('todos')
          .doc(widget.todo.id)
          .update({'imageUrl': null});

      // Then update local state
      setState(() {
        widget.todo.imageUrl = null;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image deleted successfully!')),
        );
      }
    } catch (error) {
      print('Error deleting image: $error');
      setState(() {
        _errorMessage = 'Failed to delete image: $error';
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete image: $error')),
        );
      }
    }
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Image',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),

        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_errorMessage != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[800],
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => setState(() => _errorMessage = null),
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
            ),
          )
        else if (widget.todo.imageUrl != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: widget.todo.imageUrl!,
                    placeholder: (context, url) => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    errorWidget: (context, url, error) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Icon(Icons.error, color: Colors.red, size: 48),
                            const SizedBox(height: 8),
                            Text(
                              'Error loading image: $error',
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    fit: BoxFit.cover,
                    height: 200,
                  ),
                ),
                if (_isEditMode) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.edit),
                          label: const Text('Change Image'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[800],
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _pickAndUploadImage,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.delete),
                          label: const Text('Delete Image'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[800],
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _deleteImage,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            )
          else
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  const Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No image attached to this task',
                    style: TextStyle(color: Colors.grey),
                  ),
                  if (_isEditMode) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text('Add Image'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[800],
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _pickAndUploadImage,
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
      ],
    );
  }

  Widget _buildPrioritySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Priority',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        _isEditMode
            ? Row(
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
        )
            : Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: _getColorForPriority(_priority).withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _getColorForPriority(_priority),
              width: 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.flag,
                color: _getColorForPriority(_priority),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _getPriorityLabel(_priority),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // Build the due date section
  Widget _buildDueDateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Due Date',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        _isEditMode
            ? Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  _selectedDueDate == null
                      ? 'Set Due Date'
                      : 'Due: ${DateFormat.yMMMd().add_jm().format(_selectedDueDate!)}',
                  style: const TextStyle(overflow: TextOverflow.ellipsis),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _selectDueDate(context),
              ),
            ),
            if (_selectedDueDate != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.clear, color: Colors.white),
                tooltip: 'Clear due date',
                onPressed: () => setState(() => _selectedDueDate = null),
              ),
            ],
          ],
        )
            : _selectedDueDate == null
            ? Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.grey,
              width: 1,
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.event_busy,
                color: Colors.grey,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'No due date set',
                style: TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        )
            : Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: _getDueDateColor(_selectedDueDate!).withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _getDueDateColor(_selectedDueDate!),
              width: 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.event,
                color: _getDueDateColor(_selectedDueDate!),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _formatDueDate(_selectedDueDate!),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // Method to select a due date
  Future<void> _selectDueDate(BuildContext context) async {
    final DateTime initialDate = _selectedDueDate ?? DateTime.now();
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)), // Allow selecting past dates for flexibility
      lastDate: DateTime.now().add(const Duration(days: 3650)), // 10 years into future
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.blue[700]!,
              onPrimary: Colors.white,
              surface: Colors.grey[900]!,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: Colors.grey[900],
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      // Now, select time
      final TimeOfDay initialTime = _selectedDueDate != null
          ? TimeOfDay.fromDateTime(_selectedDueDate!)
          : TimeOfDay.now();

      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: initialTime,
        builder: (context, child) {
          return Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: ColorScheme.dark(
                primary: Colors.blue[700]!,
                onPrimary: Colors.white,
                surface: Colors.grey[900]!,
                onSurface: Colors.white,
              ),
              dialogBackgroundColor: Colors.grey[900],
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDueDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  // Helper method to get due date color
  Color _getDueDateColor(DateTime dueDate) {
    final now = DateTime.now();

    // If due date is in the past, show red
    if (dueDate.isBefore(now)) {
      return Colors.red;
    }

    // If due date is today, show orange
    if (dueDate.year == now.year && dueDate.month == now.month && dueDate.day == now.day) {
      return Colors.orange;
    }

    // If due date is tomorrow, show yellow
    final tomorrow = now.add(const Duration(days: 1));
    if (dueDate.year == tomorrow.year && dueDate.month == tomorrow.month && dueDate.day == tomorrow.day) {
      return Colors.yellow;
    }

    // Otherwise, show blue
    return Colors.blue;
  }

  // Helper method to get priority color
  Color _getColorForPriority(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return Colors.red;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.low:
        return Colors.green;
    }
  }

  // Helper method to get priority label
  String _getPriorityLabel(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return 'High Priority';
      case TaskPriority.medium:
        return 'Medium Priority';
      case TaskPriority.low:
        return 'Low Priority';
    }
  }

  Future<void> _updateTask() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task title cannot be empty')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to update tasks');
      }

      // Convert priority to string
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

      // Update Firestore document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('todos')
          .doc(widget.todo.id)
          .update({
        'text': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'priority': priorityString,
        'dueAt': _selectedDueDate != null ? Timestamp.fromDate(_selectedDueDate!) : null,
      });

      // Update local todo object
      setState(() {
        widget.todo.dueAt = _selectedDueDate;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task updated successfully!')),
        );
        // Exit edit mode after successful update
        setState(() {
          _isEditMode = false;
        });
      }
    } catch (error) {
      print('Error updating task: $error');
      setState(() {
        _errorMessage = 'Failed to update task: $error';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update task: $error')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteTodo() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Delete Task', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this task?',
            style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to delete tasks');
      }

      // If there's an image, try to delete it from storage
      if (widget.todo.imageUrl != null) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(widget.todo.imageUrl!);
          await ref.delete();
        } catch (e) {
          // Continue even if we can't delete the image
          print('Could not delete image from storage: $e');
        }
      }

      // Delete the Firestore document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('todos')
          .doc(widget.todo.id)
          .delete();

      if (mounted) {
        Navigator.pop(context); // Go back to previous screen
      }
    } catch (error) {
      print('Error deleting task: $error');
      setState(() {
        _errorMessage = 'Failed to delete task: $error';
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete task: $error')),
        );
      }
    }
  }

  // Toggle edit mode
  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
    });
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today, ${_formatTime(date)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday, ${_formatTime(date)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago, ${_formatTime(date)}';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${_formatTime(date)}';
    }
  }

  String _formatDueDate(DateTime dueDate) {
    final now = DateTime.now();
    final difference = dueDate.difference(now);

    if (difference.inDays == 0) {
      final hours = difference.inHours;
      if (hours > 0) {
        return 'Due in $hours hour${hours != 1 ? 's' : ''}, ${_formatTime(dueDate)}';
      } else {
        final minutes = difference.inMinutes;
        if (minutes > 0) {
          return 'Due in $minutes minute${minutes != 1 ? 's' : ''}, ${_formatTime(dueDate)}';
        } else {
          return 'Due now, ${_formatTime(dueDate)}';
        }
      }
    } else if (difference.inDays > 0) {
      if (difference.inDays == 1) {
        return 'Due tomorrow, ${_formatTime(dueDate)}';
      } else if (difference.inDays < 7) {
        return 'Due in ${difference.inDays} days, ${_formatTime(dueDate)}';
      } else {
        return 'Due on ${DateFormat('yyyy-MM-dd').format(dueDate)}, ${_formatTime(dueDate)}';
      }
    } else { // Past due date
      if (difference.inDays == -1) {
        return 'Due yesterday, ${_formatTime(dueDate)}';
      } else {
        return 'Overdue by ${-difference.inDays} day${-difference.inDays != 1 ? 's' : ''}, ${_formatTime(dueDate)}';
      }
    }
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('Task Details'),
          actions: [
            // Edit button
            if (!_isEditMode)
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit Task',
                onPressed: _toggleEditMode,
              ),
            // Delete button (always visible)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Delete Task',
              onPressed: _isLoading ? null : _deleteTodo,
            ),
          ],
        ),
        body: _isLoading && _errorMessage == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    // Task title section
    const Text(
    'Task Title',
    style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    ),
    ),
    const SizedBox(height: 8),
    _isEditMode
    ? TextField(
    controller: _titleController,
    style: const TextStyle(color: Colors.white),
    decoration: const InputDecoration(
    border: OutlineInputBorder(),
    hintText: 'Enter task title',
    hintStyle: TextStyle(color: Colors.grey),
    enabledBorder: OutlineInputBorder(
    borderSide: BorderSide(color: Colors.grey, width: 1.0),
    ),
    focusedBorder: OutlineInputBorder(
    borderSide: BorderSide(color: Colors.blue, width: 2.0),
    ),
    ),
    maxLines: null,
    textInputAction: TextInputAction.next,
    )
        : Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
    color: Colors.grey[900],
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: Colors.grey, width: 1.0),
    ),
    width: double.infinity,
    child: Text(
    widget.todo.text,
    style: const TextStyle(
    color: Colors.white,
    fontSize: 16,
    ),
    ),
    ),
    ),
    const SizedBox(height: 24),

    // Task description section
    const Text(
    'Description',
    style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    ),
    ),
    const SizedBox(height: 8),
    _isEditMode
    ? TextField(
    controller: _descriptionController,
    style: const TextStyle(color: Colors.white),
    decoration: const InputDecoration(
    border: OutlineInputBorder(),
    hintText: 'Enter task description (optional)',
    hintStyle: TextStyle(color: Colors.grey),
    enabledBorder: OutlineInputBorder(
    borderSide: BorderSide(color: Colors.grey, width: 1.0),
    ),
    focusedBorder: OutlineInputBorder(
    borderSide: BorderSide(color: Colors.blue, width: 2.0),
    ),
    ),
    maxLines: 3,
    textInputAction: TextInputAction.next,
    )
        : Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey, width: 1.0),
        ),
        width: double.infinity,
        child: Text(
          widget.todo.description ?? 'No description',
          style: TextStyle(
            color: widget.todo.description == null || widget.todo.description!.isEmpty
                ? Colors.grey
                : Colors.white,
            fontSize: 16,
            fontStyle: widget.todo.description == null || widget.todo.description!.isEmpty
                ? FontStyle.italic
                : FontStyle.normal,
          ),
        ),
      ),
    ),
      const SizedBox(height: 24),

      // Due Date section (new)
      _buildDueDateSection(),
      const SizedBox(height: 16),

      // Priority section
      _buildPrioritySection(),
      const SizedBox(height: 16),

      // Image section
      _buildImageSection(),

      // Show creation and completion dates
      const SizedBox(height: 24),
      Text(
        'Created: ${_formatDate(widget.todo.createdAt)}',
        style: const TextStyle(color: Colors.grey),
      ),
      if (widget.todo.completedAt != null)
        Text(
          'Completed: ${_formatDate(widget.todo.completedAt!)}',
          style: const TextStyle(color: Colors.green),
        ),
      if (widget.todo.dueAt != null && _selectedDueDate == null) // Show original due date if not modified
        Text(
          'Due: ${_formatDueDate(widget.todo.dueAt!)}',
          style: TextStyle(
            color: widget.todo.dueAt!.isBefore(DateTime.now())
                ? Colors.red
                : Colors.orange,
          ),
        ),
    ],
    ),
        ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: _isEditMode
              ? Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _updateTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Save Changes'),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _toggleEditMode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
                child: const Text('Cancel'),
              ),
            ],
          )
              : Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _toggleEditMode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Edit Task'),
                ),
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
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.3) : Colors.grey[800],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color : Colors.grey,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: isSelected ? color : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}