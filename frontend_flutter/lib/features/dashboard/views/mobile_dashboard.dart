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

class MobileDashboard extends ConsumerStatefulWidget {
  const MobileDashboard({super.key});

  @override
  ConsumerState<MobileDashboard> createState() => _MobileDashboardState();
}

class _MobileDashboardState extends ConsumerState<MobileDashboard> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          AppConstants.appName,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: false,
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
            label: 'Leitor',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_rounded),
            label: 'IA & Config',
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const TaskMetricsHeader(),
              const SizedBox(height: 14),
              const LanguageSelector(),
              const SizedBox(height: 14),
              const UploadDropzone(),
              const SizedBox(height: 16),
              Container(
                height: 380,
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
