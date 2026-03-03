import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../../../models/task_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Function(String?)? onNotificationTap;

  Future<void> initialize() async {
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        onNotificationTap?.call(response.payload);
      },
    );

    // Request permissions
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> scheduleTaskNotification(Task task) async {
    final scheduledDate = tz.TZDateTime.from(task.scheduledTime, tz.local);

    // Don't schedule if time has passed and task isn't mandatory
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local)) &&
        !task.isMandatory) {
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      'task_channel',
      'Tarefas',
      channelDescription: 'Notificações de tarefas',
      importance: task.isMandatory ? Importance.max : Importance.high,
      priority: task.isMandatory ? Priority.max : Priority.high,
      fullScreenIntent: task.isMandatory,
      ongoing: task.isMandatory,
      autoCancel: !task.isMandatory,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      styleInformation: BigTextStyleInformation(
        task.description.isNotEmpty
            ? task.description
            : (task.isMandatory
                ? '⚠️ TAREFA OBRIGATÓRIA - Deve ser concluída!'
                : 'Hora de realizar sua tarefa!'),
        contentTitle: '📋 ${task.title}',
        summaryText: task.isMandatory ? 'OBRIGATÓRIA' : task.category,
      ),
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'complete',
          '✅ Concluir',
          showsUserInterface: true,
        ),
        if (task.isMandatory)
          const AndroidNotificationAction(
            'snooze',
            '⏰ Adiar 1h',
            showsUserInterface: true,
          ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final notificationId = task.id.hashCode.abs() % 2147483647;

    if (scheduledDate.isAfter(tz.TZDateTime.now(tz.local))) {
      await _notifications.zonedSchedule(
        notificationId,
        task.isMandatory ? '🔴 ${task.title}' : '📋 ${task.title}',
        task.isMandatory
            ? '⚠️ OBRIGATÓRIA: ${task.description.isNotEmpty ? task.description : "Realize esta tarefa agora!"}'
            : task.description.isNotEmpty
                ? task.description
                : 'Hora de realizar sua tarefa!',
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: task.id,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } else if (task.isMandatory && !task.isCompleted) {
      // Show immediately for overdue mandatory tasks
      await _notifications.show(
        notificationId,
        '🔴 ATRASADA: ${task.title}',
        '⚠️ TAREFA OBRIGATÓRIA PENDENTE! Conclua agora!',
        details,
        payload: task.id,
      );
    }
  }

  /// Schedule recurring alert for mandatory task (every hour)
  Future<void> scheduleMandatoryRecurring(Task task) async {
    if (!task.isMandatory || task.isCompleted) return;

    final nextAlert = tz.TZDateTime.from(
      task.scheduledTime.add(Duration(hours: task.snoozeCount + 1)),
      tz.local,
    );

    if (nextAlert.isBefore(tz.TZDateTime.now(tz.local))) {
      // Schedule for next hour from now
      final now = tz.TZDateTime.now(tz.local);
      final nextHour = now.add(const Duration(hours: 1));
      await _scheduleRecurringNotification(task, nextHour);
    } else {
      await _scheduleRecurringNotification(task, nextAlert);
    }
  }

  Future<void> _scheduleRecurringNotification(
      Task task, tz.TZDateTime time) async {
    final androidDetails = AndroidNotificationDetails(
      'mandatory_channel',
      'Tarefas Obrigatórias',
      channelDescription: 'Alertas persistentes para tarefas obrigatórias',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: false,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      styleInformation: BigTextStyleInformation(
        '⚠️ Esta tarefa ainda não foi concluída! Já foi adiada ${task.snoozeCount + 1}x.',
        contentTitle: '🔴 PENDENTE: ${task.title}',
        summaryText: 'OBRIGATÓRIA - Adiada ${task.snoozeCount + 1}x',
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final recurringId = (task.id.hashCode.abs() + 10000) % 2147483647;

    await _notifications.zonedSchedule(
      recurringId,
      '🔴 PENDENTE: ${task.title}',
      '⚠️ Tarefa obrigatória! Adiada ${task.snoozeCount + 1}x. Conclua agora!',
      time,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: '${task.id}_recurring',
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelTaskNotifications(String taskId) async {
    final notificationId = taskId.hashCode.abs() % 2147483647;
    final recurringId = (taskId.hashCode.abs() + 10000) % 2147483647;
    await _notifications.cancel(notificationId);
    await _notifications.cancel(recurringId);
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}
