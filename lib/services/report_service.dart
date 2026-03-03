import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../../../models/task_model.dart';

class ReportService {
  String _generateHtmlReport(List<Task> tasks, DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm');

    final completed = tasks.where((t) => t.isCompleted).toList();
    final pending = tasks.where((t) => !t.isCompleted).toList();
    final mandatory = tasks.where((t) => t.isMandatory).toList();
    final completionRate =
        tasks.isEmpty ? 0 : ((completed.length / tasks.length) * 100).round();

    final buffer = StringBuffer();
    buffer.writeln('📊 RELATÓRIO SEMANAL DE TAREFAS');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln(
        'Período: ${dateFormat.format(weekStart)} - ${dateFormat.format(weekEnd)}');
    buffer.writeln('');
    buffer.writeln('📈 RESUMO:');
    buffer.writeln('• Total de tarefas: ${tasks.length}');
    buffer.writeln('• Concluídas: ${completed.length} ✅');
    buffer.writeln('• Pendentes: ${pending.length} ⏳');
    buffer.writeln('• Obrigatórias: ${mandatory.length} 🔴');
    buffer.writeln('• Taxa de conclusão: $completionRate%');
    buffer.writeln('');

    if (completed.isNotEmpty) {
      buffer.writeln('✅ TAREFAS CONCLUÍDAS:');
      buffer.writeln('─────────────────────');
      for (final task in completed) {
        final mandatoryFlag = task.isMandatory ? ' [OBRIGATÓRIA]' : '';
        buffer.writeln(
            '  • ${task.title}$mandatoryFlag - ${timeFormat.format(task.scheduledTime)}');
        if (task.snoozeCount > 0) {
          buffer.writeln('    ↳ Adiada ${task.snoozeCount}x antes de concluir');
        }
        if (task.description.isNotEmpty) {
          buffer.writeln('    ↳ ${task.description}');
        }
      }
      buffer.writeln('');
    }

    if (pending.isNotEmpty) {
      buffer.writeln('⏳ TAREFAS PENDENTES:');
      buffer.writeln('─────────────────────');
      for (final task in pending) {
        final mandatoryFlag = task.isMandatory ? ' [OBRIGATÓRIA]' : '';
        buffer.writeln(
            '  • ${task.title}$mandatoryFlag - ${timeFormat.format(task.scheduledTime)}');
        if (task.description.isNotEmpty) {
          buffer.writeln('    ↳ ${task.description}');
        }
      }
      buffer.writeln('');
    }

    // Group by category
    final categories = <String, List<Task>>{};
    for (final task in tasks) {
      categories.putIfAbsent(task.category, () => []).add(task);
    }

    buffer.writeln('📁 POR CATEGORIA:');
    buffer.writeln('─────────────────');
    for (final entry in categories.entries) {
      final catCompleted = entry.value.where((t) => t.isCompleted).length;
      buffer.writeln(
          '  ${entry.key}: ${catCompleted}/${entry.value.length} concluídas');
    }

    // Group by day
    buffer.writeln('');
    buffer.writeln('📅 POR DIA:');
    buffer.writeln('─────────────');
    for (int i = 0; i < 7; i++) {
      final day = weekStart.add(Duration(days: i));
      final dayTasks = tasks
          .where((t) =>
              t.scheduledTime.year == day.year &&
              t.scheduledTime.month == day.month &&
              t.scheduledTime.day == day.day)
          .toList();
      if (dayTasks.isNotEmpty) {
        final dayName = DateFormat('EEEE, dd/MM', 'pt_BR').format(day);
        final dayCompleted = dayTasks.where((t) => t.isCompleted).length;
        buffer.writeln(
            '  $dayName: ${dayCompleted}/${dayTasks.length} concluídas');
      }
    }

    buffer.writeln('');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('Gerado por Daily Tasks App');

    return buffer.toString();
  }

  Future<void> sendWeeklyReportByEmail(
      List<Task> tasks, DateTime weekStart, String email) async {
    final report = _generateHtmlReport(tasks, weekStart);
    final dateFormat = DateFormat('dd/MM/yyyy');
    final weekEnd = weekStart.add(const Duration(days: 6));
    final subject =
        'Relatório Semanal - ${dateFormat.format(weekStart)} a ${dateFormat.format(weekEnd)}';

    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': subject,
        'body': report,
      },
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<File> generatePdfReport(List<Task> tasks, DateTime weekStart) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm');
    final weekEnd = weekStart.add(const Duration(days: 6));

    final completed = tasks.where((t) => t.isCompleted).toList();
    final pending = tasks.where((t) => !t.isCompleted).toList();
    final mandatory = tasks.where((t) => t.isMandatory).toList();
    final completionRate =
        tasks.isEmpty ? 0 : ((completed.length / tasks.length) * 100).round();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Relatório Semanal de Tarefas',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Text(
            '${dateFormat.format(weekStart)} - ${dateFormat.format(weekEnd)}',
            style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn('Total', '${tasks.length}'),
                _buildStatColumn('Concluídas', '${completed.length}'),
                _buildStatColumn('Pendentes', '${pending.length}'),
                _buildStatColumn('Obrigatórias', '${mandatory.length}'),
                _buildStatColumn('Taxa', '$completionRate%'),
              ],
            ),
          ),
          pw.SizedBox(height: 24),
          if (completed.isNotEmpty) ...[
            pw.Header(level: 1, child: pw.Text('Tarefas Concluídas ✅')),
            pw.Table.fromTextArray(
              headers: ['Tarefa', 'Horário', 'Categoria', 'Obrigatória'],
              data: completed
                  .map((t) => [
                        t.title,
                        timeFormat.format(t.scheduledTime),
                        t.category,
                        t.isMandatory ? 'Sim' : 'Não',
                      ])
                  .toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
            ),
            pw.SizedBox(height: 16),
          ],
          if (pending.isNotEmpty) ...[
            pw.Header(level: 1, child: pw.Text('Tarefas Pendentes ⏳')),
            pw.Table.fromTextArray(
              headers: ['Tarefa', 'Horário', 'Categoria', 'Obrigatória'],
              data: pending
                  .map((t) => [
                        t.title,
                        timeFormat.format(t.scheduledTime),
                        t.category,
                        t.isMandatory ? 'Sim' : 'Não',
                      ])
                  .toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ],
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File(
        '${dir.path}/relatorio_semanal_${dateFormat.format(weekStart).replaceAll('/', '-')}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  pw.Widget _buildStatColumn(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
      ],
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
}
