import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Function(String?)? onNotificationTap;

  /// Initialize notifications + timezone — call from main() BEFORE runApp
  Future<void> initialize() async {
    // ── Timezone setup ──
    tzdata.initializeTimeZones();
    try {
      final String tzName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzName));
      debugPrint('[Notification] Timezone set to: $tzName');
    } catch (e) {
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
      debugPrint('[Notification] Timezone fallback to America/Sao_Paulo');
    }

    // ── Android channel: create high-priority channel BEFORE init ──
    final androidPlugin = AndroidFlutterLocalNotificationsPlugin();

    // Channel for normal tasks
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'task_alerts',
            'Alertas de Tarefas',
            description: 'Notificações de tarefas agendadas',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
            showBadge: true,
          ),
        );

    // Channel for mandatory tasks — max priority, alarm-like
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'mandatory_alerts',
            'Tarefas Obrigatórias',
            description:
                'Alertas persistentes que tocam até a tarefa ser concluída',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            showBadge: true,
          ),
        );

    // ── Initialize plugin ──
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _notifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          _onBackgroundNotificationResponse,
    );

    // ── Request permissions ──
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // Notification permission (Android 13+)
      await androidPlugin.requestNotificationsPermission();
      // Exact alarm permission (Android 14+)
      await androidPlugin.requestExactAlarmsPermission();
    }
  }

  /// Handle notification tap in foreground
  static void _onNotificationResponse(NotificationResponse response) {
    debugPrint('[Notification] Tapped: ${response.payload}');
    onNotificationTap?.call(response.payload);
  }

  /// Handle notification tap from background/terminated — must be top-level
  @pragma('vm:entry-point')
  static void _onBackgroundNotificationResponse(NotificationResponse response) {
    debugPrint('[Notification] Background tap: ${response.payload}');
    // Save to SharedPreferences for the app to read when it opens
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('pending_notification_payload', response.payload ?? '');
    });
  }

  // ═══════════════════════════════════════════════════════════════
  //  SCHEDULE NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════════

  /// Schedule main notification for a task
  Future<void> scheduleTaskNotification(Task task) async {
    if (task.isCompleted) return;

    final now = tz.TZDateTime.now(tz.local);
    final scheduledDate = tz.TZDateTime.from(task.scheduledTime, tz.local);
    final notificationId = _getNotificationId(task.id);

    // Cancel any existing notification for this task first
    await cancelTaskNotifications(task.id);

    if (scheduledDate.isAfter(now)) {
      // ── Future task: schedule at exact time ──
      await _notifications.zonedSchedule(
        notificationId,
        task.isMandatory ? '🔴 ${task.title}' : '📋 ${task.title}',
        task.isMandatory
            ? '⚠️ OBRIGATÓRIA — ${task.description.isNotEmpty ? task.description : "Realize esta tarefa agora!"}'
            : task.description.isNotEmpty
                ? task.description
                : 'Hora de realizar sua tarefa!',
        scheduledDate,
        _getNotificationDetails(task, isRecurring: false),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: task.id,
      );
      debugPrint('[Notification] Scheduled "${task.title}" for $scheduledDate');

      // For mandatory tasks, also schedule the +1h recurring alert
      if (task.isMandatory) {
        await _scheduleMandatoryFollowUp(task, scheduledDate);
      }
    } else if (task.isMandatory) {
      // ── Overdue mandatory: show NOW + schedule next hour ──
      await _showImmediateMandatory(task);
      await _scheduleMandatoryFollowUp(task, now);
    }
  }

  /// Show mandatory alert immediately (overdue task)
  Future<void> _showImmediateMandatory(Task task) async {
    final notificationId = _getNotificationId(task.id);

    await _notifications.show(
      notificationId,
      '🔴 ATRASADA: ${task.title}',
      '⚠️ TAREFA OBRIGATÓRIA! ${task.snoozeCount > 0 ? "Já adiada ${task.snoozeCount}x. " : ""}Conclua agora!',
      _getNotificationDetails(task, isRecurring: true),
      payload: task.id,
    );
    debugPrint('[Notification] Showing immediate alert for "${task.title}"');
  }

  /// Schedule the +1h, +2h, +3h follow-up alerts for mandatory tasks
  Future<void> _scheduleMandatoryFollowUp(
      Task task, tz.TZDateTime fromTime) async {
    final now = tz.TZDateTime.now(tz.local);

    // Schedule alerts for the next 12 hours (1h intervals)
    for (int i = 1; i <= 12; i++) {
      final alertTime = fromTime.add(Duration(hours: i));

      // Only schedule future alerts
      if (alertTime.isAfter(now)) {
        final recurringId = _getRecurringId(task.id, i);

        await _notifications.zonedSchedule(
          recurringId,
          '🔴 PENDENTE: ${task.title}',
          '⚠️ Tarefa obrigatória não concluída! Adiada ${task.snoozeCount + i}x. Conclua AGORA!',
          alertTime,
          _getNotificationDetails(task, isRecurring: true),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: '${task.id}_mandatory_$i',
        );
        debugPrint('[Notification] Mandatory follow-up #$i at $alertTime');
      }
    }
  }

  /// Reschedule all mandatory tasks — called by WorkManager background task
  Future<void> recheckMandatoryTasks(List<Task> pendingMandatory) async {
    for (final task in pendingMandatory) {
      if (!task.isCompleted && task.isMandatory) {
        await scheduleTaskNotification(task);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  NOTIFICATION DETAILS (Android channels, sound, vibration)
  // ═══════════════════════════════════════════════════════════════

  NotificationDetails _getNotificationDetails(Task task,
      {required bool isRecurring}) {
    final isMandatory = task.isMandatory;

    final androidDetails = AndroidNotificationDetails(
      isMandatory ? 'mandatory_alerts' : 'task_alerts',
      isMandatory ? 'Tarefas Obrigatórias' : 'Alertas de Tarefas',
      channelDescription: isMandatory
          ? 'Alertas persistentes que tocam até a tarefa ser concluída'
          : 'Notificações de tarefas agendadas',
      // Priority & importance
      importance: isMandatory ? Importance.max : Importance.high,
      priority: isMandatory ? Priority.max : Priority.high,
      // Behavior
      fullScreenIntent: isMandatory,
      ongoing: isRecurring && isMandatory, // Can't dismiss mandatory recurring
      autoCancel: !isMandatory,
      // Sound & vibration
      playSound: true,
      enableVibration: true,
      vibrationPattern: isMandatory
          ? Int64List.fromList([0, 500, 200, 500, 200, 500]) // Long vibration
          : Int64List.fromList([0, 300, 100, 300]),
      // Visual
      category: isMandatory
          ? AndroidNotificationCategory.alarm
          : AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      // LED
      enableLights: true,
      ledColor: isMandatory ? const Color(0xFFFF6B6B) : const Color(0xFF6C9EFF),
      ledOnMs: 1000,
      ledOffMs: 500,
      // Big text style
      styleInformation: BigTextStyleInformation(
        isRecurring
            ? '⚠️ Esta tarefa OBRIGATÓRIA ainda não foi concluída! Alertando a cada hora até ser feita.'
            : (task.description.isNotEmpty
                ? task.description
                : (isMandatory
                    ? '⚠️ TAREFA OBRIGATÓRIA — Deve ser concluída!'
                    : 'Hora de realizar sua tarefa!')),
        contentTitle: isRecurring
            ? '🔴 PENDENTE: ${task.title}'
            : (isMandatory ? '🔴 ${task.title}' : '📋 ${task.title}'),
        summaryText: isMandatory
            ? (task.snoozeCount > 0
                ? 'OBRIGATÓRIA — Adiada ${task.snoozeCount}x'
                : 'OBRIGATÓRIA')
            : task.category,
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    return NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  // ═══════════════════════════════════════════════════════════════
  //  CANCEL NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════════

  Future<void> cancelTaskNotifications(String taskId) async {
    // Cancel main notification
    await _notifications.cancel(_getNotificationId(taskId));

    // Cancel all recurring follow-ups (up to 12)
    for (int i = 1; i <= 12; i++) {
      await _notifications.cancel(_getRecurringId(taskId, i));
    }
    debugPrint('[Notification] Cancelled all notifications for task $taskId');
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  // ═══════════════════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════════════════

  int _getNotificationId(String taskId) {
    return taskId.hashCode.abs() % 2147483647;
  }

  int _getRecurringId(String taskId, int index) {
    return (taskId.hashCode.abs() + (index * 1000)) % 2147483647;
  }
}
