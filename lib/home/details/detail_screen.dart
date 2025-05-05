import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../data/todo.dart';

class DetailScreen extends StatefulWidget {
  final Todo todo;

  const DetailScreen({super.key, required this.todo});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late TextEditingController _textController;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isDarkMode = true;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.todo.text);
    print('Todo image URL in initState: ${widget.todo.imageUrl}');
    print('Todo due date: ${widget.todo.dueAt}');
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
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
                  const SizedBox(height: 16),
                ],
              ),
            ),
      ],
    );
  }

  Future<void> _updateText(String newText) async {
    if (newText.trim().isEmpty || newText == widget.todo.text) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to update tasks');
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('todos')
          .doc(widget.todo.id)
          .update({'text': newText});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task updated successfully!')),
        );
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
            // Task name section
            const Text(
              'Task Description',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter task description',
                hintStyle: TextStyle(color: Colors.grey),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey, width: 1.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue, width: 2.0),
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 24),

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
            if (widget.todo.dueAt != null)
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
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _updateText(_textController.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}