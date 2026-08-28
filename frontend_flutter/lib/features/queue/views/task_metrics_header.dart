import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/document_task.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/task_queue_provider.dart';

class TaskMetricsHeader extends ConsumerWidget {
  const TaskMetricsHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(taskQueueProvider);
    final tasks = state.tasks;

    final totalFiles = tasks.length;
    final totalProcessing = state.totalProcessingCount;
    final totalCompleted = state.completedCount;
    final totalPagesTranslated = tasks.fold<int>(
      0,
      (sum, item) => sum + (item.status == TaskStatus.completed ? item.totalPages : item.currentPage),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;

        return GridView.count(
          crossAxisCount: isNarrow ? 2 : 4,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: isNarrow ? 1.8 : 2.2,
          children: [
            _buildMetricCard(
              title: 'Total de Arquivos',
              value: '$totalFiles',
              icon: Icons.folder_copy_rounded,
              color: AppColors.primaryLight,
            ),
            _buildMetricCard(
              title: 'Em Processamento',
              value: '$totalProcessing',
              icon: Icons.sync_rounded,
              color: AppColors.cyanAccent,
            ),
            _buildMetricCard(
              title: 'Páginas Traduzidas',
              value: '$totalPagesTranslated',
              icon: Icons.auto_stories_rounded,
              color: Colors.purpleAccent,
            ),
            _buildMetricCard(
              title: 'Concluídos',
              value: '$totalCompleted',
              icon: Icons.task_alt_rounded,
              color: AppColors.success,
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
