import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/document_task.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/file_saver.dart';
import '../../../core/utils/error_dialog_helper.dart';
import '../providers/task_queue_provider.dart';

class TaskCard extends ConsumerWidget {
  final DocumentTask task;
  final bool isSelected;
  final VoidCallback? onSelect;

  const TaskCard({
    super.key,
    required this.task,
    this.isSelected = false,
    this.onSelect,
  });

  Color _getStatusColor() {
    switch (task.status) {
      case TaskStatus.pending:
        return AppColors.warning;
      case TaskStatus.extracting:
        return AppColors.cyanAccent;
      case TaskStatus.translating:
        return AppColors.primaryLight;
      case TaskStatus.reconstructing:
        return Colors.purpleAccent;
      case TaskStatus.completed:
        return AppColors.success;
      case TaskStatus.failed:
        return AppColors.error;
    }
  }

  IconData _getStatusIcon() {
    switch (task.status) {
      case TaskStatus.pending:
        return Icons.schedule_rounded;
      case TaskStatus.extracting:
        return Icons.document_scanner_rounded;
      case TaskStatus.translating:
        return Icons.auto_awesome_rounded;
      case TaskStatus.reconstructing:
        return Icons.layers_rounded;
      case TaskStatus.completed:
        return Icons.check_circle_rounded;
      case TaskStatus.failed:
        return Icons.error_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = _getStatusColor();

    return InkWell(
      onTap: () {
        if (task.status == TaskStatus.failed) {
          ErrorDialogHelper.showErrorModal(
            context: context,
            title: 'Falha no Processamento do Documento',
            message: 'Ocorreu um erro ao processar o arquivo "${task.filename}".',
            technicalDetails: task.errorMessage ?? 'Erro não especificado durante a tradução da página.',
            actionLabel: 'Tentar Novamente',
            onAction: () => ref.read(taskQueueProvider.notifier).retryTask(task.taskId),
          );
        } else if (onSelect != null) {
          onSelect!();
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceElevated : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primaryLight : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: File name, language badge and status chip
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_getStatusIcon(), color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.filename,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.arrow_forward_rounded, size: 11, color: AppColors.cyanAccent),
                                const SizedBox(width: 4),
                                Text(
                                  task.targetLanguage,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.cyanAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (task.formattedFileSize.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              task.formattedFileSize,
                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    task.status.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Progress bar and page indicators
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: task.status == TaskStatus.completed
                    ? 1.0
                    : (task.percentage / 100.0).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: AppColors.surfaceElevated,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),

            const SizedBox(height: 10),

            // Progress details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  task.status == TaskStatus.completed
                      ? 'Processamento Finalizado (${task.totalPages} págs)'
                      : (task.status == TaskStatus.failed
                          ? (task.errorMessage ?? 'Falha no processamento')
                          : 'Página ${task.currentPage} de ${task.totalPages} • ${task.percentage.toStringAsFixed(1)}%'),
                  style: TextStyle(
                    fontSize: 12,
                    color: task.status == TaskStatus.failed ? AppColors.error : AppColors.textSecondary,
                  ),
                ),
                if (task.estimatedSecondsRemaining != null &&
                    task.estimatedSecondsRemaining! > 0 &&
                    task.status != TaskStatus.completed &&
                    task.status != TaskStatus.failed)
                  Text(
                    '~${task.estimatedSecondsRemaining}s restantes',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
              ],
            ),

            // Strict translated output name badge and actions
            if (task.status == TaskStatus.completed) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded, color: AppColors.success, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        task.outputFilename,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: onSelect,
                    icon: const Icon(Icons.chrome_reader_mode_rounded, size: 14),
                    label: const Text('Leitor Comparativo', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.cyanAccent,
                      side: const BorderSide(color: AppColors.cyanAccent),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      FileSaverHelper.saveDocument(
                        context: context,
                        apiService: ref.read(apiServiceProvider),
                        task: task,
                      );
                    },
                    icon: const Icon(Icons.download_rounded, size: 14),
                    label: const Text('Baixar', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                  ),
                ],
              ),
            ] else if (task.status == TaskStatus.failed) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      ErrorDialogHelper.showErrorModal(
                        context: context,
                        title: 'Diagnóstico de Erro no Arquivo',
                        message: 'Ocorreu um erro durante a tradução de "${task.filename}".',
                        technicalDetails: task.errorMessage ?? 'Erro durante a requisição com a API de IA ou limites de cota.',
                        actionLabel: 'Tentar Novamente',
                        onAction: () => ref.read(taskQueueProvider.notifier).retryTask(task.taskId),
                      );
                    },
                    icon: const Icon(Icons.info_outline_rounded, size: 14),
                    label: const Text('Ver Detalhes do Erro', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => ref.read(taskQueueProvider.notifier).retryTask(task.taskId),
                    icon: const Icon(Icons.refresh_rounded, size: 14),
                    label: const Text('Tentar Novamente', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
