import 'package:uuid/uuid.dart';

class Task {
  final String id;
  String title;
  String description;
  DateTime scheduledTime;
  bool isMandatory;
  bool isCompleted;
  DateTime createdAt;
  DateTime? completedAt;
  int snoozeCount;
  String category;
  int priority; // 1=low, 2=medium, 3=high

  Task({
    String? id,
    required this.title,
    this.description = '',
    required this.scheduledTime,
    this.isMandatory = false,
    this.isCompleted = false,
    DateTime? createdAt,
    this.completedAt,
    this.snoozeCount = 0,
    this.category = 'Geral',
    this.priority = 2,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'scheduledTime': scheduledTime.toIso8601String(),
      'isMandatory': isMandatory ? 1 : 0,
      'isCompleted': isCompleted ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'snoozeCount': snoozeCount,
      'category': category,
      'priority': priority,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'],
      description: map['description'] ?? '',
      scheduledTime: DateTime.parse(map['scheduledTime']),
      isMandatory: map['isMandatory'] == 1,
      isCompleted: map['isCompleted'] == 1,
      createdAt: DateTime.parse(map['createdAt']),
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'])
          : null,
      snoozeCount: map['snoozeCount'] ?? 0,
      category: map['category'] ?? 'Geral',
      priority: map['priority'] ?? 2,
    );
  }

  Task copyWith({
    String? title,
    String? description,
    DateTime? scheduledTime,
    bool? isMandatory,
    bool? isCompleted,
    DateTime? completedAt,
    int? snoozeCount,
    String? category,
    int? priority,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      isMandatory: isMandatory ?? this.isMandatory,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      snoozeCount: snoozeCount ?? this.snoozeCount,
      category: category ?? this.category,
      priority: priority ?? this.priority,
    );
  }

  String get priorityLabel {
    switch (priority) {
      case 1:
        return 'Baixa';
      case 2:
        return 'Média';
      case 3:
        return 'Alta';
      default:
        return 'Média';
    }
  }

  bool get isOverdue {
    return !isCompleted && scheduledTime.isBefore(DateTime.now());
  }
}
