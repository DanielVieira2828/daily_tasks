import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'notification_service.dart';
import '../models/task_model.dart';

/// Unique task names for WorkManager
const String kMandatoryCheckTask = 'com.dailytasks.mandatoryCheck';
const String kPeriodicCheckTask = 'com.dailytasks.periodicCheck';

/// TOP-LEVEL callback — WorkManager runs this in a separate isolate
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    debugPrint('[Background] Task executing: $taskName');

    try {
      // Initialize timezone in background isolate
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));

      // Initialize notifications in background
      final notificationService = NotificationService();
      await notificationService.initialize();

      // Open database directly (Provider not available in background)
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'daily_tasks.db');
      final db = await openDatabase(path);

      // Query pending mandatory tasks
      final now = DateTime.now().toIso8601String();
      final maps = await db.query(
        'tasks',
        where: 'isMandatory = 1 AND isCompleted = 0 AND scheduledTime <= ?',
        whereArgs: [now],
      );

      final pendingTasks = maps.map((m) => Task.fromMap(m)).toList();
      debugPrint('[Background] Found ${pendingTasks.length} pending mandatory tasks');

      // Trigger notifications for each pending mandatory task
      for (final task in pendingTasks) {
        await notificationService.scheduleTaskNotification(task);
      }

      await db.close();
      return true;
    } catch (e) {
      debugPrint('[Background] Error: $e');
      return false;
    }
  });
}

class BackgroundService {
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
    debugPrint('[BackgroundService] WorkManager initialized');
  }

  /// Register periodic task that checks mandatory tasks every 15 min
  static Future<void> registerPeriodicCheck() async {
    await Workmanager().registerPeriodicTask(
      kPeriodicCheckTask,
      kMandatoryCheckTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.not_required,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 5),
    );
    debugPrint('[BackgroundService] Periodic check registered (15 min)');
  }

  /// Trigger an immediate one-shot check
  static Future<void> triggerImmediateCheck() async {
    await Workmanager().registerOneOffTask(
      '${kMandatoryCheckTask}_immediate_${DateTime.now().millisecondsSinceEpoch}',
      kMandatoryCheckTask,
      constraints: Constraints(
        networkType: NetworkType.not_required,
      ),
    );
    debugPrint('[BackgroundService] Immediate check triggered');
  }

  /// Cancel all background tasks
  static Future<void> cancelAll() async {
    await Workmanager().cancelAll();
    debugPrint('[BackgroundService] All background tasks cancelled');
  }
}
