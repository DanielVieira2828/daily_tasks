import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/task_model.dart';
import '../../providers/task_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';

class AddTaskScreen extends StatefulWidget {
  final DateTime initialDate;
  final Task? editTask;

  const AddTaskScreen({
    super.key,
    required this.initialDate,
    this.editTask,
  });

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TimeOfDay _selectedTime;
  late bool _isMandatory;
  late String _selectedCategory;
  late int _selectedPriority;

  bool get isEditing => widget.editTask != null;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.editTask?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.editTask?.description ?? '');
    _selectedTime = widget.editTask != null
        ? TimeOfDay.fromDateTime(widget.editTask!.scheduledTime)
        : TimeOfDay.now();
    _isMandatory = widget.editTask?.isMandatory ?? false;
    _selectedCategory = widget.editTask?.category ?? 'Geral';
    _selectedPriority = widget.editTask?.priority ?? 2;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 24),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surfaceLight,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEditing ? 'Editar Tarefa' : 'Nova Tarefa',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _saveTask,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isEditing ? 'Salvar' : 'Criar',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                physics: const BouncingScrollPhysics(),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      _buildSectionLabel('Título'),
                      TextFormField(
                        controller: _titleController,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Ex: Reunião com equipe',
                          prefixIcon: Icon(Icons.edit_rounded,
                              color: AppColors.textMuted, size: 20),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Informe o título da tarefa';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      // Description
                      _buildSectionLabel('Descrição (opcional)'),
                      TextFormField(
                        controller: _descriptionController,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Detalhes sobre a tarefa...',
                          prefixIcon: Icon(Icons.notes_rounded,
                              color: AppColors.textMuted, size: 20),
                        ),
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                      ),

                      const SizedBox(height: 24),

                      // Time picker
                      _buildSectionLabel('Horário'),
                      GestureDetector(
                        onTap: _pickTime,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.infoSoft,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.access_time_rounded,
                                  color: AppColors.info,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Horário do Alerta',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _selectedTime.format(context),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.textMuted.withOpacity(0.5),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Category
                      _buildSectionLabel('Categoria'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: AppConstants.categories.map((cat) {
                          final isSelected = _selectedCategory == cat;
                          final catIndex = AppConstants.categories.indexOf(cat);
                          final color = AppColors.getCategoryColor(catIndex);
                          final icon = AppConstants.categoryIcons[cat] ?? '📋';

                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedCategory = cat);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? color.withOpacity(0.2)
                                    : AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? color.withOpacity(0.5)
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(icon,
                                      style: const TextStyle(fontSize: 14)),
                                  const SizedBox(width: 6),
                                  Text(
                                    cat,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: isSelected
                                          ? color
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 24),

                      // Priority
                      _buildSectionLabel('Prioridade'),
                      Row(
                        children: [
                          _buildPriorityChip(1, 'Baixa', AppColors.priorityLow,
                              Icons.arrow_downward_rounded),
                          const SizedBox(width: 10),
                          _buildPriorityChip(2, 'Média',
                              AppColors.priorityMedium, Icons.remove_rounded),
                          const SizedBox(width: 10),
                          _buildPriorityChip(3, 'Alta', AppColors.priorityHigh,
                              Icons.arrow_upward_rounded),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // Mandatory toggle
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _isMandatory
                                ? [
                                    AppColors.danger.withOpacity(0.15),
                                    AppColors.danger.withOpacity(0.05),
                                  ]
                                : [
                                    AppColors.surfaceLight,
                                    AppColors.surfaceLight,
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isMandatory
                                ? AppColors.danger.withOpacity(0.3)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _isMandatory
                                    ? AppColors.dangerSoft
                                    : AppColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _isMandatory
                                    ? Icons.notifications_active_rounded
                                    : Icons.notifications_outlined,
                                color: _isMandatory
                                    ? AppColors.danger
                                    : AppColors.textMuted,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tarefa Obrigatória',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: _isMandatory
                                          ? AppColors.danger
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _isMandatory
                                        ? 'Alerta a cada hora até concluir!'
                                        : 'Ativar alerta persistente',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _isMandatory
                                          ? AppColors.danger.withOpacity(0.7)
                                          : AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _isMandatory,
                              onChanged: (value) {
                                HapticFeedback.mediumImpact();
                                setState(() => _isMandatory = value);
                              },
                              activeColor: AppColors.danger,
                              activeTrackColor:
                                  AppColors.danger.withOpacity(0.3),
                            ),
                          ],
                        ),
                      ),

                      if (_isMandatory) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.warningSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  color: AppColors.warning, size: 18),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Se não for concluída no horário, o alerta será reagendado para a próxima hora automaticamente.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.warning,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildPriorityChip(
      int priority, String label, Color color, IconData icon) {
    final isSelected = _selectedPriority == priority;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedPriority = priority);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color:
                isSelected ? color.withOpacity(0.15) : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color.withOpacity(0.5) : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16, color: isSelected ? color : AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? color : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: AppTheme.darkTheme.copyWith(
            timePickerTheme: AppTheme.darkTheme.timePickerTheme,
          ),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() => _selectedTime = time);
    }
  }

  void _saveTask() {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.heavyImpact();

    final scheduledDateTime = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final provider = context.read<TaskProvider>();

    if (isEditing) {
      final updatedTask = widget.editTask!.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        scheduledTime: scheduledDateTime,
        isMandatory: _isMandatory,
        category: _selectedCategory,
        priority: _selectedPriority,
      );
      provider.updateTask(updatedTask);
    } else {
      final task = Task(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        scheduledTime: scheduledDateTime,
        isMandatory: _isMandatory,
        category: _selectedCategory,
        priority: _selectedPriority,
      );
      provider.addTask(task);
    }

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 20),
            const SizedBox(width: 8),
            Text(
              isEditing ? 'Tarefa atualizada!' : 'Tarefa criada!',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            if (_isMandatory) ...[
              const SizedBox(width: 8),
              const Text('🔔', style: TextStyle(fontSize: 14)),
            ],
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
