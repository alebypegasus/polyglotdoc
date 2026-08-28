import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/document_task.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/task_queue_provider.dart';
import 'task_card.dart';

class TaskListView extends ConsumerStatefulWidget {
  final String? selectedTaskId;
  final Function(DocumentTask)? onTaskSelected;

  const TaskListView({
    super.key,
    this.selectedTaskId,
    this.onTaskSelected,
  });

  @override
  ConsumerState<TaskListView> createState() => _TaskListViewState();
}

class _TaskListViewState extends ConsumerState<TaskListView> {
  String _filter = 'all'; // all, processing, completed, failed

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(taskQueueProvider);
    final notifier = ref.read(taskQueueProvider.notifier);

    final filteredTasks = state.tasks.where((task) {
      if (_filter == 'processing') {
        return task.status != TaskStatus.completed && task.status != TaskStatus.failed;
      } else if (_filter == 'completed') {
        return task.status == TaskStatus.completed;
      } else if (_filter == 'failed') {
        return task.status == TaskStatus.failed;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter bar & batch actions
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('Todos (${state.tasks.length})', 'all'),
              const SizedBox(width: 8),
              _buildFilterChip('Em Fila (${state.totalProcessingCount})', 'processing'),
              const SizedBox(width: 8),
              _buildFilterChip('Concluídos (${state.completedCount})', 'completed'),
              if (state.completedCount > 0) ...[
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: () => notifier.clearCompleted(),
                  icon: const Icon(Icons.cleaning_services_rounded, size: 14),
                  label: const Text('Limpar Concluídos', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        if (filteredTasks.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_rounded, size: 44, color: AppColors.textMuted.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                const Text(
                  'Nenhum documento nesta categoria',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Envie novos arquivos na área de upload acima para iniciar.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredTasks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final task = filteredTasks[index];
              final isSelected = (widget.selectedTaskId ?? state.selectedTaskId) == task.taskId;

              return TaskCard(
                task: task,
                isSelected: isSelected,
                onSelect: () {
                  notifier.selectTask(task.taskId);
                  widget.onTaskSelected?.call(task);
                },
              );
            },
          ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;

    return InkWell(
      onTap: () => setState(() => _filter = value),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryLight : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
