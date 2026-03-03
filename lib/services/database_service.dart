import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task_model.dart';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'daily_tasks.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tasks(
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            description TEXT,
            scheduledTime TEXT NOT NULL,
            isMandatory INTEGER DEFAULT 0,
            isCompleted INTEGER DEFAULT 0,
            createdAt TEXT NOT NULL,
            completedAt TEXT,
            snoozeCount INTEGER DEFAULT 0,
            category TEXT DEFAULT 'Geral',
            priority INTEGER DEFAULT 2
          )
        ''');
      },
    );
  }

  Future<int> insertTask(Task task) async {
    final db = await database;
    return await db.insert(
      'tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateTask(Task task) async {
    final db = await database;
    return await db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> deleteTask(String id) async {
    final db = await database;
    return await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Task>> getTasks() async {
    final db = await database;
    final maps = await db.query('tasks', orderBy: 'scheduledTime ASC');
    return maps.map((map) => Task.fromMap(map)).toList();
  }

  Future<List<Task>> getTasksByDate(DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final maps = await db.query(
      'tasks',
      where: 'scheduledTime >= ? AND scheduledTime < ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'scheduledTime ASC',
    );
    return maps.map((map) => Task.fromMap(map)).toList();
  }

  Future<List<Task>> getTasksForWeek(DateTime weekStart) async {
    final db = await database;
    final weekEnd = weekStart.add(const Duration(days: 7));

    final maps = await db.query(
      'tasks',
      where: 'scheduledTime >= ? AND scheduledTime < ?',
      whereArgs: [weekStart.toIso8601String(), weekEnd.toIso8601String()],
      orderBy: 'scheduledTime ASC',
    );
    return maps.map((map) => Task.fromMap(map)).toList();
  }

  Future<List<Task>> getPendingMandatoryTasks() async {
    final db = await database;
    final now = DateTime.now();

    final maps = await db.query(
      'tasks',
      where: 'isMandatory = 1 AND isCompleted = 0 AND scheduledTime <= ?',
      whereArgs: [now.toIso8601String()],
      orderBy: 'scheduledTime ASC',
    );
    return maps.map((map) => Task.fromMap(map)).toList();
  }

  // ═══════════════════════════════════════════════════════════════
  //  COPY TASKS
  // ═══════════════════════════════════════════════════════════════

  /// Copy specific tasks from one day to another
  Future<List<Task>> copyTasksToDate({
    required List<Task> tasks,
    required DateTime targetDate,
  }) async {
    final copiedTasks = <Task>[];

    for (final task in tasks) {
      final newScheduledTime = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        task.scheduledTime.hour,
        task.scheduledTime.minute,
      );

      final copiedTask = Task(
        title: task.title,
        description: task.description,
        scheduledTime: newScheduledTime,
        isMandatory: task.isMandatory,
        isCompleted: false,
        snoozeCount: 0,
        category: task.category,
        priority: task.priority,
      );

      await insertTask(copiedTask);
      copiedTasks.add(copiedTask);
    }

    return copiedTasks;
  }

  /// Copy tasks from one week to the next week
  Future<List<Task>> copyWeekTasks({
    required DateTime sourceWeekStart,
    required DateTime targetWeekStart,
  }) async {
    final sourceTasks = await getTasksForWeek(sourceWeekStart);
    final copiedTasks = <Task>[];

    for (final task in sourceTasks) {
      // Calculate the day offset within the week
      final dayOffset = task.scheduledTime.difference(
        DateTime(sourceWeekStart.year, sourceWeekStart.month, sourceWeekStart.day),
      ).inDays;

      final targetDate = targetWeekStart.add(Duration(days: dayOffset));

      final newScheduledTime = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        task.scheduledTime.hour,
        task.scheduledTime.minute,
      );

      final copiedTask = Task(
        title: task.title,
        description: task.description,
        scheduledTime: newScheduledTime,
        isMandatory: task.isMandatory,
        isCompleted: false,
        snoozeCount: 0,
        category: task.category,
        priority: task.priority,
      );

      await insertTask(copiedTask);
      copiedTasks.add(copiedTask);
    }

    return copiedTasks;
  }
}
