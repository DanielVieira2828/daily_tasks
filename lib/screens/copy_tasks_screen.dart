import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/task_provider.dart';
import '../models/task_model.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';

class CopyTasksScreen extends StatefulWidget {
  final DateTime currentDate;

  const CopyTasksScreen({super.key, required this.currentDate});

  @override
  State<CopyTasksScreen> createState() => _CopyTasksScreenState();
}

class _CopyTasksScreenState extends State<CopyTasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime? _sourceDate;
  DateTime? _targetDate;
  DateTime? _sourceWeekStart;
  DateTime? _targetWeekStart;
  List<Task> _sourceTasks = [];
  final Set<String> _selectedTaskIds = {};
  bool _isLoading = false;
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _sourceDate = widget.currentDate;
    _targetDate = widget.currentDate.add(const Duration(days: 1));

    final now = widget.currentDate;
    _sourceWeekStart = now.subtract(Duration(days: now.weekday - 1));
    _sourceWeekStart = DateTime(
        _sourceWeekStart!.year, _sourceWeekStart!.month, _sourceWeekStart!.day);
    _targetWeekStart = _sourceWeekStart!.add(const Duration(days: 7));

    _loadSourceTasks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSourceTasks() async {
    setState(() => _isLoading = true);
    final provider = context.read<TaskProvider>();

    if (_tabController.index == 0) {
      // Day mode
      _sourceTasks = await provider.getTasksByDate(_sourceDate!);
    } else {
      // Week mode
      _sourceTasks = await provider.getWeekTasks(_sourceWeekStart!);
    }

    _selectedTaskIds.clear();
    _selectAll = false;
    setState(() => _isLoading = false);
  }

  void _toggleSelectAll() {
    setState(() {
      _selectAll = !_selectAll;
      if (_selectAll) {
        _selectedTaskIds.addAll(_sourceTasks.map((t) => t.id));
      } else {
        _selectedTaskIds.clear();
      }
    });
  }

  Future<void> _copyTasks() async {
    if (_selectedTaskIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
              SizedBox(width: 8),
              Text('Selecione pelo menos uma tarefa'),
            ],
          ),
        ),
      );
      return;
    }

    HapticFeedback.heavyImpact();
    setState(() => _isLoading = true);

    final provider = context.read<TaskProvider>();
    final selectedTasks =
        _sourceTasks.where((t) => _selectedTaskIds.contains(t.id)).toList();

    int copiedCount = 0;

    if (_tabController.index == 0) {
      // Copy day tasks
      copiedCount =
          await provider.copyTasksToDate(selectedTasks, _targetDate!);
    } else {
      // Copy week tasks
      copiedCount = await provider.copyWeekTasks(
          _sourceWeekStart!, _targetWeekStart!);
    }

    setState(() => _isLoading = false);

    if (mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 20),
              const SizedBox(width: 8),
              Text('$copiedCount tarefa(s) copiada(s) com sucesso!'),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final dayNameFormat = DateFormat('EEEE, dd/MM', 'pt_BR');

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
                  const Expanded(
                    child: Text(
                      'Copiar Tarefas',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Tab bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: _tabController,
                onTap: (_) {
                  _loadSourceTasks();
                },
                indicator: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textMuted,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(text: '📅  Dia → Dia'),
                  Tab(text: '📆  Semana → Semana'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // ── Tab 1: Day to Day ──
                  _buildDayToDayTab(dateFormat, dayNameFormat),
                  // ── Tab 2: Week to Week ──
                  _buildWeekToWeekTab(dateFormat),
                ],
              ),
            ),

            // Bottom action bar
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_selectedTaskIds.length} tarefa(s) selecionada(s)',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            _tabController.index == 0
                                ? 'Copiar para ${_targetDate != null ? dateFormat.format(_targetDate!) : "..."}'
                                : 'Copiar semana inteira',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _isLoading ? null : _copyTasks,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.copy_rounded, size: 18),
                      label: Text(_isLoading ? 'Copiando...' : 'Copiar'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayToDayTab(DateFormat dateFormat, DateFormat dayNameFormat) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Source date picker
          _buildDatePickerCard(
            label: 'Copiar DE',
            sublabel: 'Selecione o dia de origem',
            icon: Icons.today_rounded,
            color: AppColors.info,
            date: _sourceDate!,
            formattedDate: dayNameFormat.format(_sourceDate!),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _sourceDate!,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                builder: (context, child) => Theme(
                  data: AppTheme.darkTheme.copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: AppColors.accent,
                      surface: AppColors.surface,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) {
                setState(() => _sourceDate = picked);
                _loadSourceTasks();
              }
            },
          ),

          const SizedBox(height: 10),

          // Arrow indicator
          const Center(
            child: Icon(Icons.arrow_downward_rounded,
                color: AppColors.accent, size: 28),
          ),

          const SizedBox(height: 10),

          // Target date picker
          _buildDatePickerCard(
            label: 'Copiar PARA',
            sublabel: 'Selecione o dia de destino',
            icon: Icons.event_rounded,
            color: AppColors.success,
            date: _targetDate!,
            formattedDate: dayNameFormat.format(_targetDate!),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _targetDate!,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                builder: (context, child) => Theme(
                  data: AppTheme.darkTheme.copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: AppColors.accent,
                      surface: AppColors.surface,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) {
                setState(() => _targetDate = picked);
              }
            },
          ),

          const SizedBox(height: 20),

          // Task list
          _buildTaskSelectionList(),
        ],
      ),
    );
  }

  Widget _buildWeekToWeekTab(DateFormat dateFormat) {
    final sourceEnd = _sourceWeekStart!.add(const Duration(days: 6));
    final targetEnd = _targetWeekStart!.add(const Duration(days: 6));

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Source week
          _buildWeekPickerCard(
            label: 'Semana ORIGEM',
            color: AppColors.info,
            weekStart: _sourceWeekStart!,
            weekEnd: sourceEnd,
            dateFormat: dateFormat,
            onPrev: () {
              setState(() => _sourceWeekStart =
                  _sourceWeekStart!.subtract(const Duration(days: 7)));
              _loadSourceTasks();
            },
            onNext: () {
              setState(() => _sourceWeekStart =
                  _sourceWeekStart!.add(const Duration(days: 7)));
              _loadSourceTasks();
            },
          ),

          const SizedBox(height: 10),
          const Center(
            child: Icon(Icons.arrow_downward_rounded,
                color: AppColors.accent, size: 28),
          ),
          const SizedBox(height: 10),

          // Target week
          _buildWeekPickerCard(
            label: 'Semana DESTINO',
            color: AppColors.success,
            weekStart: _targetWeekStart!,
            weekEnd: targetEnd,
            dateFormat: dateFormat,
            onPrev: () {
              setState(() => _targetWeekStart =
                  _targetWeekStart!.subtract(const Duration(days: 7)));
            },
            onNext: () {
              setState(() => _targetWeekStart =
                  _targetWeekStart!.add(const Duration(days: 7)));
            },
          ),

          const SizedBox(height: 20),

          // Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_sourceTasks.length} tarefas encontradas na semana',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ao copiar semana, TODAS as tarefas serão copiadas mantendo o mesmo dia da semana e horário.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildMiniChip('${_sourceTasks.length}', 'Total', AppColors.info),
                    _buildMiniChip(
                        '${_sourceTasks.where((t) => t.isMandatory).length}',
                        'Obrigatórias', AppColors.danger),
                    _buildMiniChip(
                        '${_sourceTasks.map((t) => t.category).toSet().length}',
                        'Categorias', AppColors.secondary),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Select all for week
          if (_sourceTasks.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.successSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppColors.success, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Todas as ${_sourceTasks.length} tarefas serão copiadas para a semana destino.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildTaskSelectionList() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
    }

    if (_sourceTasks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(30),
        alignment: Alignment.center,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.event_busy_rounded,
                  size: 36, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            const Text(
              'Nenhuma tarefa neste dia',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Select all toggle
        GestureDetector(
          onTap: _toggleSelectAll,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _selectAll ? AppColors.accentSoft : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _selectAll
                    ? AppColors.accent.withOpacity(0.3)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _selectAll
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  size: 20,
                  color: _selectAll ? AppColors.accent : AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  _selectAll
                      ? 'Desmarcar todas'
                      : 'Selecionar todas (${_sourceTasks.length})',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _selectAll ? AppColors.accent : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Task list
        ...(_sourceTasks.map((task) {
          final isSelected = _selectedTaskIds.contains(task.id);
          final priorityColor = AppColors.getPriorityColor(task.priority);
          final icon = AppConstants.categoryIcons[task.category] ?? '📋';

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                if (isSelected) {
                  _selectedTaskIds.remove(task.id);
                  _selectAll = false;
                } else {
                  _selectedTaskIds.add(task.id);
                  if (_selectedTaskIds.length == _sourceTasks.length) {
                    _selectAll = true;
                  }
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.accent.withOpacity(0.08)
                    : AppColors.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.accent.withOpacity(0.3)
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  // Checkbox
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      color: isSelected ? AppColors.accent : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.accent
                            : AppColors.textMuted.withOpacity(0.4),
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check_rounded,
                            size: 16, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  // Priority bar
                  Container(
                    width: 3,
                    height: 32,
                    decoration: BoxDecoration(
                      color: priorityColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(icon, style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                task.title,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (task.isMandatory)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.dangerSoft,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'OBRIG.',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.danger,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${DateFormat('HH:mm').format(task.scheduledTime)} · ${task.category} · ${task.priorityLabel}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList()),

        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildDatePickerCard({
    required String label,
    required String sublabel,
    required IconData icon,
    required Color color,
    required DateTime date,
    required String formattedDate,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                  const SizedBox(height: 2),
                  Text(
                    formattedDate,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.calendar_month_rounded,
                color: color.withOpacity(0.5), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekPickerCard({
    required String label,
    required Color color,
    required DateTime weekStart,
    required DateTime weekEnd,
    required DateFormat dateFormat,
    required VoidCallback onPrev,
    required VoidCallback onNext,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: onPrev,
                icon: const Icon(Icons.chevron_left_rounded, size: 24),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              Text(
                '${dateFormat.format(weekStart)} — ${dateFormat.format(weekEnd)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right_rounded, size: 24),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontSize: 10, color: color.withOpacity(0.8))),
        ],
      ),
    );
  }
}
