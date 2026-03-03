import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../models/task_model.dart';
import '../../../utils/app_theme.dart';
import '../../../utils/constants.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onComplete;
  final VoidCallback onDelete;
  final VoidCallback onSnooze;
  final VoidCallback? onTap;

  const TaskCard({
    super.key,
    required this.task,
    required this.onComplete,
    required this.onDelete,
    required this.onSnooze,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');
    final priorityColor = AppColors.getPriorityColor(task.priority);
    final icon = AppConstants.categoryIcons[task.category] ?? '📋';
    final isOverdue = task.isOverdue;

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        HapticFeedback.mediumImpact();
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Excluir Tarefa'),
            content: Text('Deseja excluir "${task.title}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: const Text('Excluir'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete(),
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline_rounded,
            color: AppColors.danger, size: 28),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: task.isCompleted
                ? AppColors.cardBg.withOpacity(0.5)
                : AppColors.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOverdue && task.isMandatory
                  ? AppColors.danger.withOpacity(0.5)
                  : task.isMandatory && !task.isCompleted
                      ? AppColors.accent.withOpacity(0.3)
                      : Colors.transparent,
              width: isOverdue && task.isMandatory ? 1.5 : 1,
            ),
            boxShadow: [
              if (isOverdue && task.isMandatory)
                BoxShadow(
                  color: AppColors.danger.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Row(
            children: [
              // Completion button
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onComplete();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: task.isCompleted
                        ? AppColors.success
                        : Colors.transparent,
                    border: Border.all(
                      color: task.isCompleted
                          ? AppColors.success
                          : priorityColor.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: task.isCompleted
                      ? const Icon(Icons.check_rounded,
                          size: 16, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 14),

              // Priority indicator
              Container(
                width: 4,
                height: 44,
                decoration: BoxDecoration(
                  color: priorityColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 14),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(icon, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: task.isCompleted
                                  ? AppColors.textMuted
                                  : AppColors.textPrimary,
                              decoration: task.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: AppColors.textMuted,
                            ),
                          ),
                        ),
                        if (task.isMandatory)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isOverdue
                                  ? AppColors.dangerSoft
                                  : AppColors.accentSoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isOverdue ? 'ATRASADA' : 'OBRIGATÓRIA',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: isOverdue
                                    ? AppColors.danger
                                    : AppColors.accent,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: isOverdue
                              ? AppColors.danger
                              : AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          timeFormat.format(task.scheduledTime),
                          style: TextStyle(
                            fontSize: 13,
                            color: isOverdue
                                ? AppColors.danger
                                : AppColors.textSecondary,
                            fontWeight:
                                isOverdue ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                        if (task.snoozeCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.warningSoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.snooze_rounded,
                                    size: 10, color: AppColors.warning),
                                const SizedBox(width: 3),
                                Text(
                                  '${task.snoozeCount}x',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.warning,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          task.category,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    if (task.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        task.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Snooze button for mandatory overdue
              if (isOverdue && task.isMandatory && !task.isCompleted) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    onSnooze();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.warningSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.snooze_rounded,
                      size: 20,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
