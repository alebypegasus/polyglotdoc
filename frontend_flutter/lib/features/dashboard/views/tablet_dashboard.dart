import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../queue/views/task_list_view.dart';
import '../../queue/views/task_metrics_header.dart';
import '../../reader/views/standalone_reader_screen.dart';
import '../../settings/views/ai_settings_view.dart';
import '../../upload/views/language_selector.dart';
import '../../upload/views/upload_dropzone.dart';

class TabletDashboard extends ConsumerStatefulWidget {
  const TabletDashboard({super.key});

  @override
  ConsumerState<TabletDashboard> createState() => _TabletDashboardState();
}

class _TabletDashboardState extends ConsumerState<TabletDashboard> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          AppConstants.appName,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                CircleAvatar(radius: 3, backgroundColor: AppColors.success),
                SizedBox(width: 6),
                Text('Online', style: TextStyle(fontSize: 11, color: AppColors.success)),
              ],
            ),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTabIndex,
        onDestinationSelected: (index) => setState(() => _selectedTabIndex = index),
        backgroundColor: AppColors.surface,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Painel & Fila',
          ),
          NavigationDestination(
            icon: Icon(Icons.chrome_reader_mode_rounded),
            label: 'Leitor Dividido',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_rounded),
            label: 'Configurações IA',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedTabIndex) {
      case 1:
        return const StandaloneReaderScreen();
      case 2:
        return const AISettingsView();
      case 0:
      default:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const TaskMetricsHeader(),
              const SizedBox(height: 16),
              const LanguageSelector(),
              const SizedBox(height: 16),
              const UploadDropzone(),
              const SizedBox(height: 20),
              Container(
                height: 400,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: const TaskListView(),
              ),
            ],
          ),
        );
    }
  }
}
