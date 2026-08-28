import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/document_task.dart';
import '../../../core/theme/app_colors.dart';
import '../../queue/providers/task_queue_provider.dart';
import 'split_reader_view.dart';

class StandaloneReaderScreen extends ConsumerStatefulWidget {
  const StandaloneReaderScreen({super.key});

  @override
  ConsumerState<StandaloneReaderScreen> createState() => _StandaloneReaderScreenState();
}

class _StandaloneReaderScreenState extends ConsumerState<StandaloneReaderScreen> {
  String? _selectedTaskId;

  @override
  Widget build(BuildContext context) {
    final queueState = ref.watch(taskQueueProvider);
    final tasks = queueState.tasks;
    final completedTasks = tasks.where((t) => t.status == TaskStatus.completed).toList();

    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.menu_book_rounded, color: AppColors.textMuted, size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nenhum documento na fila ainda',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Envie um documento no Painel & Fila para habilitar a visualização dividida.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    final availableList = completedTasks.isNotEmpty ? completedTasks : tasks;
    final currentTask = availableList.firstWhere(
      (t) => t.taskId == _selectedTaskId,
      orElse: () => availableList.first,
    );

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Document Selector Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.folder_open_rounded, color: AppColors.cyanAccent, size: 20),
                const SizedBox(width: 12),
                const Text(
                  'Documento Ativo:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: currentTask.taskId,
                      dropdownColor: AppColors.surfaceElevated,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.cyanAccent),
                      items: availableList.map((t) {
                        return DropdownMenuItem<String>(
                          value: t.taskId,
                          child: Text(
                            '${t.filename} -> ${t.targetLanguage} [${t.status.label}]',
                            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (newId) {
                        if (newId != null) {
                          setState(() => _selectedTaskId = newId);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Split Reader View
          Expanded(
            child: SplitReaderView(
              key: ValueKey(currentTask.taskId),
              task: currentTask,
            ),
          ),
        ],
      ),
    );
  }
}
