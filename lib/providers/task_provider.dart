import 'package:flutter/material.dart';
import '../../../models/task_model.dart';
import '../../../services/database_service.dart';
import '../../../services/notification_service.dart';

class TaskProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final NotificationService _notificationService = NotificationService();

  List<Task> _tasks = [];
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  List<Task> get tasks => _tasks;
  DateTime get selectedDate => _selectedDate;
  bool get isLoading => _isLoading;

  List<Task> get todayTasks {
    final now = DateTime.now();
    return _tasks
        .where((t) =>
            t.scheduledTime.year == now.year &&
            t.scheduledTime.month == now.month &&
            t.scheduledTime.day == now.day)
        .toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
  }

  List<Task> get selectedDateTasks {
    return _tasks
        .where((t) =>
            t.scheduledTime.year == _selectedDate.year &&
            t.scheduledTime.month == _selectedDate.month &&
            t.scheduledTime.day == _selectedDate.day)
        .toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
  }

  List<Task> get pendingMandatoryTasks {
    return _tasks
        .where((t) =>
            t.isMandatory &&
            !t.isCompleted &&
            t.scheduledTime.isBefore(DateTime.now()))
        .toList();
  }

  int get completedCount => _tasks.where((t) => t.isCompleted).length;
  int get pendingCount => _tasks.where((t) => !t.isCompleted).length;
  int get mandatoryPendingCount => pendingMandatoryTasks.length;

  double get completionRate {
    if (_tasks.isEmpty) return 0;
    return completedCount / _tasks.length;
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  Future<void> loadTasks() async {
    _isLoading = true;
    notifyListeners();

    try {
      _tasks = await _db.getTasks();
    } catch (e) {
      debugPrint('Error loading tasks: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadTasksByDate(DateTime date) async {
    _isLoading = true;
    notifyListeners();

    try {
      _tasks = await _db.getTasksByDate(date);
    } catch (e) {
      debugPrint('Error loading tasks by date: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addTask(Task task) async {
    await _db.insertTask(task);
    await _notificationService.scheduleTaskNotification(task);

    if (task.isMandatory) {
      await _notificationService.scheduleMandatoryRecurring(task);
    }

    await loadTasks();
  }

  Future<void> updateTask(Task task) async {
    await _db.updateTask(task);
    await _notificationService.cancelTaskNotifications(task.id);
    await _notificationService.scheduleTaskNotification(task);

    if (task.isMandatory && !task.isCompleted) {
      await _notificationService.scheduleMandatoryRecurring(task);
    }

    await loadTasks();
  }

  Future<void> completeTask(String taskId) async {
    final taskIndex = _tasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) return;

    final task = _tasks[taskIndex].copyWith(
      isCompleted: true,
      completedAt: DateTime.now(),
    );

    await _db.updateTask(task);
    await _notificationService.cancelTaskNotifications(taskId);

    await loadTasks();
  }

  Future<void> uncompleteTask(String taskId) async {
    final taskIndex = _tasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) return;

    final task = _tasks[taskIndex].copyWith(
      isCompleted: false,
    );
    // Reset completedAt
    final updatedTask = Task(
      id: task.id,
      title: task.title,
      description: task.description,
      scheduledTime: task.scheduledTime,
      isMandatory: task.isMandatory,
      isCompleted: false,
      createdAt: task.createdAt,
      completedAt: null,
      snoozeCount: task.snoozeCount,
      category: task.category,
      priority: task.priority,
    );

    await _db.updateTask(updatedTask);
    await _notificationService.scheduleTaskNotification(updatedTask);

    if (updatedTask.isMandatory) {
      await _notificationService.scheduleMandatoryRecurring(updatedTask);
    }

    await loadTasks();
  }

  Future<void> snoozeTask(String taskId) async {
    final taskIndex = _tasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) return;

    final task = _tasks[taskIndex];
    final snoozedTask = Task(
      id: task.id,
      title: task.title,
      description: task.description,
      scheduledTime: DateTime.now().add(const Duration(hours: 1)),
      isMandatory: task.isMandatory,
      isCompleted: false,
      createdAt: task.createdAt,
      snoozeCount: task.snoozeCount + 1,
      category: task.category,
      priority: task.priority,
    );

    await _db.updateTask(snoozedTask);
    await _notificationService.cancelTaskNotifications(taskId);
    await _notificationService.scheduleTaskNotification(snoozedTask);

    if (snoozedTask.isMandatory) {
      await _notificationService.scheduleMandatoryRecurring(snoozedTask);
    }

    await loadTasks();
  }

  Future<void> deleteTask(String taskId) async {
    await _db.deleteTask(taskId);
    await _notificationService.cancelTaskNotifications(taskId);
    await loadTasks();
  }

  Future<List<Task>> getWeekTasks(DateTime weekStart) async {
    return await _db.getTasksForWeek(weekStart);
  }

  /// Check for pending mandatory tasks and reschedule alerts
  Future<void> checkMandatoryTasks() async {
    final pending = await _db.getPendingMandatoryTasks();
    for (final task in pending) {
      await _notificationService.scheduleMandatoryRecurring(task);
    }
  }
}
