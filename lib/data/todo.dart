import 'package:cloud_firestore/cloud_firestore.dart';

class Todo {
  final String id;
  final String text;
  final String? uid;
  final DateTime createdAt;
  DateTime? completedAt;
  DateTime? dueAt;
  String? imageUrl;
  final String? description;
  final String? priority;
  final String? category; // Added category field

  Todo({
    required this.id,
    required this.text,
    required this.uid,
    required this.createdAt,
    this.completedAt,
    this.dueAt,
    this.imageUrl,
    this.description,
    this.priority,
    this.category, // Added to constructor
  });

  Map<String, dynamic> toSnapshot() {
    return {
      'text': text,
      'uid': uid,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'dueAt': dueAt != null ? Timestamp.fromDate(dueAt!) : null,
      'imageUrl': imageUrl,
      'description': description,
      'priority': priority ?? 'medium', // Default to medium if not set
      'category': category, // Added to map
    };
  }

  factory Todo.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return Todo(
      id: snapshot.id,
      text: data['text'] ?? '',
      uid: data['uid'],
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
      completedAt: data['completedAt'] != null ? (data['completedAt'] as Timestamp).toDate() : null,
      dueAt: data['dueAt'] != null ? (data['dueAt'] as Timestamp).toDate() : null,
      imageUrl: data['imageUrl'],
      description: data['description'],
      priority: data['priority'] ?? 'medium',
      category: data['category'], // Added to factory constructor
    );
  }
}