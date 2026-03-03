import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/background_service.dart';

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

  Future<List<Task>> getTasksByDate(DateTime date) async {
    return await _db.getTasksByDate(date);
  }

  Future<void> addTask(Task task) async {
    await _db.insertTask(task);
    await _notificationService.scheduleTaskNotification(task);
    // Trigger background service to ensure alerts work with app closed
    await BackgroundService.triggerImmediateCheck();
    await loadTasks();
  }

  Future<void> updateTask(Task task) async {
    await _db.updateTask(task);
    await _notificationService.cancelTaskNotifications(task.id);
    await _notificationService.scheduleTaskNotification(task);
    if (task.isMandatory && !task.isCompleted) {
      await BackgroundService.triggerImmediateCheck();
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
    // Cancel ALL notifications when completed — stops the recurring alerts
    await _notificationService.cancelTaskNotifications(taskId);
    await loadTasks();
  }

  Future<void> uncompleteTask(String taskId) async {
    final taskIndex = _tasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) return;

    final updatedTask = Task(
      id: _tasks[taskIndex].id,
      title: _tasks[taskIndex].title,
      description: _tasks[taskIndex].description,
      scheduledTime: _tasks[taskIndex].scheduledTime,
      isMandatory: _tasks[taskIndex].isMandatory,
      isCompleted: false,
      createdAt: _tasks[taskIndex].createdAt,
      completedAt: null,
      snoozeCount: _tasks[taskIndex].snoozeCount,
      category: _tasks[taskIndex].category,
      priority: _tasks[taskIndex].priority,
    );

    await _db.updateTask(updatedTask);
    await _notificationService.scheduleTaskNotification(updatedTask);
    if (updatedTask.isMandatory) {
      await BackgroundService.triggerImmediateCheck();
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
    await BackgroundService.triggerImmediateCheck();
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

  // ═══════════════════════════════════════════════════════════════
  //  COPY TASKS
  // ═══════════════════════════════════════════════════════════════

  /// Copy selected tasks to a target date. Returns count of copied tasks.
  Future<int> copyTasksToDate(List<Task> tasks, DateTime targetDate) async {
    final copiedTasks = await _db.copyTasksToDate(
      tasks: tasks,
      targetDate: targetDate,
    );

    // Schedule notifications for each copied task
    for (final task in copiedTasks) {
      await _notificationService.scheduleTaskNotification(task);
    }

    await BackgroundService.triggerImmediateCheck();
    await loadTasks();
    return copiedTasks.length;
  }

  /// Copy all tasks from one week to another. Returns count.
  Future<int> copyWeekTasks(
      DateTime sourceWeekStart, DateTime targetWeekStart) async {
    final copiedTasks = await _db.copyWeekTasks(
      sourceWeekStart: sourceWeekStart,
      targetWeekStart: targetWeekStart,
    );

    for (final task in copiedTasks) {
      await _notificationService.scheduleTaskNotification(task);
    }

    await BackgroundService.triggerImmediateCheck();
    await loadTasks();
    return copiedTasks.length;
  }

  /// Check for pending mandatory tasks and reschedule alerts
  Future<void> checkMandatoryTasks() async {
    final pending = await _db.getPendingMandatoryTasks();
    await _notificationService.recheckMandatoryTasks(pending);
  }
}
