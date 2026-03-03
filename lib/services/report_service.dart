import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import '../models/task_model.dart';

class ReportService {
  // ── Colors matching the app theme ──
  static const _primary = PdfColor.fromInt(0xFF1A1B2E);
  static const _accent = PdfColor.fromInt(0xFFFF6B6B);
  static const _success = PdfColor.fromInt(0xFF4ECB71);
  static const _warning = PdfColor.fromInt(0xFFFFB347);
  static const _danger = PdfColor.fromInt(0xFFFF6B6B);
  static const _info = PdfColor.fromInt(0xFF6C9EFF);
  static const _dark = PdfColor.fromInt(0xFF242645);
  static const _surface = PdfColor.fromInt(0xFF2E3050);
  static const _textLight = PdfColor.fromInt(0xFFF0F0F5);
  static const _textMuted = PdfColor.fromInt(0xFF9496B0);
  static const _white = PdfColors.white;
  static const _bgLight = PdfColor.fromInt(0xFFF5F7FA);
  static const _bgCard = PdfColor.fromInt(0xFFFFFFFF);

  Future<File> generatePdfReport(
      List<Task> tasks, DateTime weekStart) async {
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(),
    );
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm');
    final dayNameFormat = DateFormat('EEEE', 'pt_BR');
    final weekEnd = weekStart.add(const Duration(days: 6));

    final completed = tasks.where((t) => t.isCompleted).toList();
    final pending = tasks.where((t) => !t.isCompleted).toList();
    final mandatory = tasks.where((t) => t.isMandatory).toList();
    final mandatoryCompleted = tasks.where((t) => t.isMandatory && t.isCompleted).toList();
    final completionRate = tasks.isEmpty ? 0.0 : (completed.length / tasks.length) * 100;

    // Group by day
    final dailyData = <int, Map<String, dynamic>>{};
    for (int i = 0; i < 7; i++) {
      final day = weekStart.add(Duration(days: i));
      final dayTasks = tasks.where((t) =>
          t.scheduledTime.year == day.year &&
          t.scheduledTime.month == day.month &&
          t.scheduledTime.day == day.day).toList();
      dailyData[i] = {
        'date': day,
        'tasks': dayTasks,
        'completed': dayTasks.where((t) => t.isCompleted).length,
        'total': dayTasks.length,
      };
    }

    // Group by category
    final categories = <String, Map<String, int>>{};
    for (final task in tasks) {
      categories.putIfAbsent(task.category, () => {'total': 0, 'completed': 0});
      categories[task.category]!['total'] = categories[task.category]!['total']! + 1;
      if (task.isCompleted) {
        categories[task.category]!['completed'] = categories[task.category]!['completed']! + 1;
      }
    }

    // ════════════════════════════════════════════════
    //  PAGE 1: Cover + Summary
    // ════════════════════════════════════════════════
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) => pw.Stack(
          children: [
            // Background gradient
            pw.Positioned.fill(
              child: pw.Container(color: _primary),
            ),
            // Decorative circles
            pw.Positioned(
              top: -60,
              right: -60,
              child: pw.Container(
                width: 250,
                height: 250,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  color: PdfColor.fromInt(0x15FF6B6B),
                ),
              ),
            ),
            pw.Positioned(
              bottom: -80,
              left: -80,
              child: pw.Container(
                width: 300,
                height: 300,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  color: PdfColor.fromInt(0x106C9EFF),
                ),
              ),
            ),
            // Content
            pw.Padding(
              padding: const pw.EdgeInsets.all(50),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(height: 60),
                  // Logo/Title area
                  pw.Container(
                    padding: const pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0x20FF6B6B),
                      borderRadius: pw.BorderRadius.circular(16),
                    ),
                    child: pw.Text(
                      'DAILY TASKS',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: _accent,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 30),
                  pw.Text(
                    'Relatório\nSemanal',
                    style: pw.TextStyle(
                      fontSize: 48,
                      fontWeight: pw.FontWeight.bold,
                      color: _white,
                      lineSpacing: 5,
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Container(
                    width: 80,
                    height: 4,
                    decoration: pw.BoxDecoration(
                      color: _accent,
                      borderRadius: pw.BorderRadius.circular(2),
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    '${dateFormat.format(weekStart)}  —  ${dateFormat.format(weekEnd)}',
                    style: pw.TextStyle(
                      fontSize: 18,
                      color: _textMuted,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Gerado em ${dateFormat.format(DateTime.now())} às ${timeFormat.format(DateTime.now())}',
                    style: pw.TextStyle(
                      fontSize: 11,
                      color: PdfColor.fromInt(0xFF6B6D88),
                    ),
                  ),

                  pw.Spacer(),

                  // Summary stats boxes
                  pw.Row(
                    children: [
                      _buildCoverStat('${completionRate.round()}%', 'Conclusão', _success),
                      pw.SizedBox(width: 12),
                      _buildCoverStat('${tasks.length}', 'Total', _info),
                      pw.SizedBox(width: 12),
                      _buildCoverStat('${completed.length}', 'Concluídas', _success),
                      pw.SizedBox(width: 12),
                      _buildCoverStat('${pending.length}', 'Pendentes', _warning),
                    ],
                  ),
                  pw.SizedBox(height: 16),
                  pw.Row(
                    children: [
                      _buildCoverStat('${mandatory.length}', 'Obrigatórias', _danger),
                      pw.SizedBox(width: 12),
                      _buildCoverStat('${mandatoryCompleted.length}', 'Obrig. Feitas', _success),
                      pw.SizedBox(width: 12),
                      _buildCoverStat(
                        '${tasks.fold<int>(0, (sum, t) => sum + t.snoozeCount)}',
                        'Adiamentos',
                        _warning,
                      ),
                      pw.SizedBox(width: 12),
                      _buildCoverStat(
                        '${categories.length}',
                        'Categorias',
                        _info,
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // ════════════════════════════════════════════════
    //  PAGE 2: Daily Breakdown
    // ════════════════════════════════════════════════
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildPageHeader('Visão Diária', 'Tarefas organizadas por dia da semana'),
            pw.SizedBox(height: 20),

            // Visual bar chart
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: _bgCard,
                borderRadius: pw.BorderRadius.circular(12),
                border: pw.Border.all(color: PdfColor.fromInt(0xFFE8EAF0)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Desempenho Diário', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 16),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: List.generate(7, (i) {
                      final data = dailyData[i]!;
                      final total = data['total'] as int;
                      final done = data['completed'] as int;
                      final maxTasks = dailyData.values.map((d) => d['total'] as int).reduce((a, b) => a > b ? a : b);
                      final barHeight = maxTasks > 0 ? (total / maxTasks) * 100 : 0.0;
                      final doneHeight = maxTasks > 0 ? (done / maxTasks) * 100 : 0.0;
                      final day = data['date'] as DateTime;
                      final dayNames = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

                      return pw.Expanded(
                        child: pw.Column(
                          children: [
                            pw.Text('$done/$total',
                                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                            pw.SizedBox(height: 4),
                            pw.Container(
                              height: 100,
                              alignment: pw.Alignment.bottomCenter,
                              child: pw.Stack(
                                alignment: pw.Alignment.bottomCenter,
                                children: [
                                  pw.Container(
                                    width: 28,
                                    height: barHeight > 0 ? barHeight : 4,
                                    decoration: pw.BoxDecoration(
                                      color: PdfColor.fromInt(0xFFE8EAF0),
                                      borderRadius: pw.BorderRadius.circular(4),
                                    ),
                                  ),
                                  pw.Container(
                                    width: 28,
                                    height: doneHeight > 0 ? doneHeight : 0,
                                    decoration: pw.BoxDecoration(
                                      color: _success,
                                      borderRadius: pw.BorderRadius.circular(4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            pw.SizedBox(height: 6),
                            pw.Text(dayNames[i],
                                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                            pw.Text(DateFormat('dd/MM').format(day),
                                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
                          ],
                        ),
                      );
                    }),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      _buildLegendDot(_success, 'Concluídas'),
                      pw.SizedBox(width: 16),
                      _buildLegendDot(PdfColor.fromInt(0xFFE8EAF0), 'Total'),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Category breakdown
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: _bgCard,
                borderRadius: pw.BorderRadius.circular(12),
                border: pw.Border.all(color: PdfColor.fromInt(0xFFE8EAF0)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Por Categoria', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 14),
                  ...categories.entries.map((entry) {
                    final total = entry.value['total']!;
                    final done = entry.value['completed']!;
                    final pct = total > 0 ? (done / total) : 0.0;
                    final catIcons = {
                      'Geral': '📋', 'Trabalho': '💼', 'Pessoal': '👤',
                      'Saúde': '❤️', 'Estudo': '📚', 'Finanças': '💰',
                      'Casa': '🏠', 'Fitness': '💪',
                    };
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 10),
                      child: pw.Row(
                        children: [
                          pw.SizedBox(
                            width: 90,
                            child: pw.Text(
                              '${catIcons[entry.key] ?? "📋"} ${entry.key}',
                              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                          pw.Expanded(
                            child: pw.Stack(
                              children: [
                                pw.Container(
                                  height: 14,
                                  decoration: pw.BoxDecoration(
                                    color: PdfColor.fromInt(0xFFE8EAF0),
                                    borderRadius: pw.BorderRadius.circular(7),
                                  ),
                                ),
                                pw.Container(
                                  height: 14,
                                  width: pct * 300,
                                  decoration: pw.BoxDecoration(
                                    color: _getBarColor(pct),
                                    borderRadius: pw.BorderRadius.circular(7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          pw.SizedBox(width: 10),
                          pw.Text(
                            '$done/$total (${(pct * 100).round()}%)',
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // ════════════════════════════════════════════════
    //  PAGE 3+: Detailed Task Lists
    // ════════════════════════════════════════════════
    // Build task rows for the table
    final allTaskRows = <pw.TableRow>[];

    // Header row
    allTaskRows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: _primary),
        children: [
          _buildTableHeader('Status'),
          _buildTableHeader('Tarefa'),
          _buildTableHeader('Horário'),
          _buildTableHeader('Categoria'),
          _buildTableHeader('Prioridade'),
          _buildTableHeader('Tipo'),
        ],
      ),
    );

    // Sort: pending mandatory first, then pending, then completed
    final sortedTasks = [...tasks]..sort((a, b) {
      if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
      if (a.isMandatory != b.isMandatory) return a.isMandatory ? -1 : 1;
      return a.scheduledTime.compareTo(b.scheduledTime);
    });

    for (int i = 0; i < sortedTasks.length; i++) {
      final task = sortedTasks[i];
      final isEven = i % 2 == 0;
      allTaskRows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: isEven ? _bgCard : PdfColor.fromInt(0xFFF8F9FC),
          ),
          children: [
            _buildTableCell(
              task.isCompleted ? '✅' : (task.isMandatory ? '🔴' : '⏳'),
              alignment: pw.Alignment.center,
            ),
            _buildTableCellWidget(
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    task.title,
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      decoration: task.isCompleted ? pw.TextDecoration.lineThrough : null,
                      color: task.isCompleted ? PdfColors.grey500 : PdfColors.grey800,
                    ),
                  ),
                  if (task.description.isNotEmpty)
                    pw.Text(
                      task.description,
                      style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
                      maxLines: 1,
                    ),
                  if (task.snoozeCount > 0)
                    pw.Text(
                      'Adiada ${task.snoozeCount}x',
                      style: pw.TextStyle(fontSize: 7, color: _warning, fontWeight: pw.FontWeight.bold),
                    ),
                ],
              ),
            ),
            _buildTableCell(
              '${timeFormat.format(task.scheduledTime)}\n${DateFormat('dd/MM').format(task.scheduledTime)}',
              fontSize: 8,
            ),
            _buildTableCell(task.category, fontSize: 8),
            _buildTableCellWidget(
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: pw.BoxDecoration(
                  color: _getPriorityBg(task.priority),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(
                  task.priorityLabel,
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                    color: _getPriorityColor(task.priority),
                  ),
                ),
              ),
            ),
            _buildTableCellWidget(
              task.isMandatory
                  ? pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromInt(0x20FF6B6B),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Text('OBRIG.',
                          style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _danger)),
                    )
                  : pw.Text('Normal', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
            ),
          ],
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => context.pageNumber > 1
            ? pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: _buildPageHeader(
                  'Lista Completa de Tarefas',
                  '${dateFormat.format(weekStart)} — ${dateFormat.format(weekEnd)}',
                ),
              )
            : pw.SizedBox(),
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 10),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Daily Tasks — Relatório Semanal',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
              ),
              pw.Text(
                'Página ${context.pageNumber} de ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
              ),
            ],
          ),
        ),
        build: (context) => [
          _buildPageHeader('Lista Completa de Tarefas', '${tasks.length} tarefas no período'),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFE8EAF0), width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(45),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FixedColumnWidth(55),
              3: const pw.FixedColumnWidth(65),
              4: const pw.FixedColumnWidth(55),
              5: const pw.FixedColumnWidth(50),
            },
            children: allTaskRows,
          ),
          pw.SizedBox(height: 24),

          // Summary box
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF0F4FF),
              borderRadius: pw.BorderRadius.circular(12),
              border: pw.Border.all(color: PdfColor.fromInt(0xFFD0DCFF)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('📊 Resumo Executivo',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF2D3748))),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Taxa de conclusão: ${completionRate.round()}% (${completed.length} de ${tasks.length} tarefas)',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  'Tarefas obrigatórias: ${mandatoryCompleted.length} de ${mandatory.length} concluídas',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  'Total de adiamentos: ${tasks.fold<int>(0, (sum, t) => sum + t.snoozeCount)}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                if (pending.isNotEmpty) ...[
                  pw.SizedBox(height: 8),
                  pw.Text(
                    '⚠️ ${pending.length} tarefa(s) pendente(s) — ${pending.where((t) => t.isMandatory).length} obrigatória(s)',
                    style: pw.TextStyle(fontSize: 10, color: _danger, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    // Save PDF
    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'relatorio_${dateFormat.format(weekStart).replaceAll('/', '-')}_a_${dateFormat.format(weekEnd).replaceAll('/', '-')}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  // ── Helper widgets for PDF ──

  pw.Widget _buildCoverStat(String value, String label, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromInt(0x15FFFFFF),
          borderRadius: pw.BorderRadius.circular(12),
          border: pw.Border.all(color: PdfColor.fromInt(0x20FFFFFF)),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: color),
            ),
            pw.SizedBox(height: 4),
            pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: _textMuted)),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildPageHeader(String title, String subtitle) {
    return pw.Row(
      children: [
        pw.Container(
          width: 4,
          height: 36,
          decoration: pw.BoxDecoration(
            color: _accent,
            borderRadius: pw.BorderRadius.circular(2),
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text(subtitle, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500)),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildLegendDot(PdfColor color, String label) {
    return pw.Row(
      children: [
        pw.Container(width: 10, height: 10, decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(3))),
        pw.SizedBox(width: 4),
        pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      ],
    );
  }

  pw.Widget _buildTableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _white)),
    );
  }

  pw.Widget _buildTableCell(String text, {double fontSize = 9, pw.Alignment alignment = pw.Alignment.centerLeft}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Align(alignment: alignment, child: pw.Text(text, style: pw.TextStyle(fontSize: fontSize))),
    );
  }

  pw.Widget _buildTableCellWidget(pw.Widget child) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: child,
    );
  }

  PdfColor _getBarColor(double pct) {
    if (pct >= 0.8) return _success;
    if (pct >= 0.5) return _info;
    if (pct >= 0.3) return _warning;
    return _danger;
  }

  PdfColor _getPriorityColor(int priority) {
    switch (priority) {
      case 1: return PdfColor.fromInt(0xFF4ECB71);
      case 3: return PdfColor.fromInt(0xFFFF6B6B);
      default: return PdfColor.fromInt(0xFFFFB347);
    }
  }

  PdfColor _getPriorityBg(int priority) {
    switch (priority) {
      case 1: return PdfColor.fromInt(0x204ECB71);
      case 3: return PdfColor.fromInt(0x20FF6B6B);
      default: return PdfColor.fromInt(0x20FFB347);
    }
  }

  // ── Public methods ──

  Future<void> sendReportByEmail(List<Task> tasks, DateTime weekStart, String email) async {
    final file = await generatePdfReport(tasks, weekStart);
    final dateFormat = DateFormat('dd/MM/yyyy');
    final weekEnd = weekStart.add(const Duration(days: 6));

    final subject = Uri.encodeComponent(
        'Relatório Semanal - ${dateFormat.format(weekStart)} a ${dateFormat.format(weekEnd)}');
    final body = Uri.encodeComponent(
        'Segue em anexo o relatório semanal de tarefas.\n\n'
        'Período: ${dateFormat.format(weekStart)} a ${dateFormat.format(weekEnd)}\n\n'
        'Gerado por Daily Tasks App');

    // Share the PDF via share sheet (email attachment)
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Relatório Semanal - ${dateFormat.format(weekStart)} a ${dateFormat.format(weekEnd)}',
      text: 'Segue o relatório semanal de tarefas em PDF.',
    );
  }

  Future<void> shareReport(List<Task> tasks, DateTime weekStart) async {
    final file = await generatePdfReport(tasks, weekStart);
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Relatório Semanal de Tarefas',
      text: 'Segue o relatório semanal de tarefas.',
    );
  }

  Future<void> openReport(List<Task> tasks, DateTime weekStart) async {
    final file = await generatePdfReport(tasks, weekStart);
    await OpenFile.open(file.path);
  }
}
