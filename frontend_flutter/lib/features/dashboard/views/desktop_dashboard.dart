import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../queue/providers/task_queue_provider.dart';
import '../../queue/views/task_list_view.dart';
import '../../queue/views/task_metrics_header.dart';
import '../../reader/views/split_reader_view.dart';
import '../../reader/views/standalone_reader_screen.dart';
import '../../settings/views/ai_settings_view.dart';
import '../../upload/views/language_selector.dart';
import '../../upload/views/upload_dropzone.dart';

class DesktopDashboard extends ConsumerStatefulWidget {
  const DesktopDashboard({super.key});

  @override
  ConsumerState<DesktopDashboard> createState() => _DesktopDashboardState();
}

class _DesktopDashboardState extends ConsumerState<DesktopDashboard> {
  String? _selectedTaskId;
  int _selectedNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Left Navigation Sidebar
          _buildSidebar(),

          const VerticalDivider(width: 1, color: AppColors.border),

          // Main Center Workspace
          Expanded(
            child: _buildCurrentView(),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_selectedNavIndex) {
      case 1:
        return const StandaloneReaderScreen();
      case 2:
        return const AISettingsView();
      case 0:
      default:
        return _buildDashboardAndQueueView();
    }
  }

  Widget _buildDashboardAndQueueView() {
    final queueState = ref.watch(taskQueueProvider);
    final tasks = queueState.tasks;
    final selectedTask = _selectedTaskId != null
        ? tasks.where((t) => t.taskId == _selectedTaskId).firstOrNull
        : null;

    return Column(
      children: [
        // App Top Bar
        _buildTopBar(),

        const Divider(height: 1, color: AppColors.border),

        // Dashboard Content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Upload dropzone, language selector and metrics
                const SizedBox(
                  width: 420,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TaskMetricsHeader(),
                        SizedBox(height: 20),
                        LanguageSelector(),
                        SizedBox(height: 20),
                        UploadDropzone(),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 24),

                // Right Column: Task Queue & Live Split Reader (if selected)
                Expanded(
                  child: selectedTask != null
                      ? SplitReaderView(
                          key: ValueKey(selectedTask.taskId),
                          task: selectedTask,
                          onClose: () => setState(() => _selectedTaskId = null),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Expanded(
                                      child: Row(
                                        children: [
                                          Icon(Icons.queue_play_next_rounded, color: AppColors.cyanAccent, size: 20),
                                          SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              'Fila de Tradução & Reconstrução',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${tasks.length} documento(s)',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1, color: AppColors.border),
                              Expanded(
                                child: TaskListView(
                                  selectedTaskId: _selectedTaskId,
                                  onTaskSelected: (task) {
                                    setState(() {
                                      _selectedTaskId = task.taskId;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      color: AppColors.surface,
      child: Row(
        children: [
          const Icon(Icons.bolt_rounded, color: AppColors.cyanAccent, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Tradução Editorial de Alta Performance com IA',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Server status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                CircleAvatar(radius: 4, backgroundColor: AppColors.success),
                SizedBox(width: 6),
                Text(
                  'Backend Online',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 260,
      color: AppColors.surface,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App Brand Header
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/icon/app_icon_128.png',
                    width: 38,
                    height: 38,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      padding: const EdgeInsets.all(8),
                      color: AppColors.primary,
                      child: const Icon(Icons.translate_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppConstants.appName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'v1.0.0 Pro Edition',
                      style: TextStyle(fontSize: 11, color: AppColors.cyanAccent, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          const Text(
            'MENU PRINCIPAL',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 1.0),
          ),

          const SizedBox(height: 12),

          _buildNavItem(
            index: 0,
            icon: Icons.dashboard_rounded,
            title: 'Painel & Fila',
          ),
          _buildNavItem(
            index: 1,
            icon: Icons.chrome_reader_mode_rounded,
            title: 'Leitor Dividido',
          ),
          _buildNavItem(
            index: 2,
            icon: Icons.tune_rounded,
            title: 'Configurações de IA',
          ),

          const Spacer(),

          // System Stats Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield_rounded, color: AppColors.primaryLight, size: 16),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Nomenclatura Estrita',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  '[Nome] - Traduzido [SIGLA].[ext]',
                  style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String title,
  }) {
    final isSelected = _selectedNavIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedNavIndex = index;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primary.withValues(alpha: 0.4) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? AppColors.cyanAccent : AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
