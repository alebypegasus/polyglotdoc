import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/document_task.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/websocket_service.dart';

class TaskQueueState {
  final List<DocumentTask> tasks;
  final String? selectedTaskId;
  final String targetLanguage;
  final String sourceLanguage;
  final bool preserveLayout;
  final bool isUploading;
  final String clientId;
  final String? errorMessage;

  const TaskQueueState({
    this.tasks = const [],
    this.selectedTaskId,
    this.targetLanguage = 'PT-BR',
    this.sourceLanguage = 'auto',
    this.preserveLayout = true,
    this.isUploading = false,
    this.clientId = 'client_local',
    this.errorMessage,
  });

  TaskQueueState copyWith({
    List<DocumentTask>? tasks,
    String? selectedTaskId,
    String? targetLanguage,
    String? sourceLanguage,
    bool? preserveLayout,
    bool? isUploading,
    String? clientId,
    String? errorMessage,
  }) {
    return TaskQueueState(
      tasks: tasks ?? this.tasks,
      selectedTaskId: selectedTaskId ?? this.selectedTaskId,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      preserveLayout: preserveLayout ?? this.preserveLayout,
      isUploading: isUploading ?? this.isUploading,
      clientId: clientId ?? this.clientId,
      errorMessage: errorMessage,
    );
  }

  DocumentTask? get selectedTask {
    if (selectedTaskId == null) return null;
    try {
      return tasks.firstWhere((t) => t.taskId == selectedTaskId);
    } catch (_) {
      return null;
    }
  }

  int get totalProcessingCount =>
      tasks.where((t) => t.status != TaskStatus.completed && t.status != TaskStatus.failed).length;

  int get completedCount => tasks.where((t) => t.status == TaskStatus.completed).length;
}

class TaskQueueNotifier extends StateNotifier<TaskQueueState> {
  final ApiService _apiService;
  final WebSocketService _wsService;
  StreamSubscription? _wsSubscription;

  TaskQueueNotifier({
    required ApiService apiService,
    required WebSocketService wsService,
  })  : _apiService = apiService,
        _wsService = wsService,
        super(TaskQueueState(clientId: 'client_${DateTime.now().millisecondsSinceEpoch}')) {
    _init();
  }

  void _init() {
    _wsService.connect(state.clientId);
    _wsSubscription = _wsService.progressStream.listen(_onWebSocketProgress);
    loadInitialTasks();
  }

  void _onWebSocketProgress(Map<String, dynamic> event) {
    final taskId = event['task_id'] as String?;
    if (taskId == null) return;

    final statusStr = event['status'] as String? ?? 'pending';
    final currentPage = event['current_page'] as int? ?? 0;
    final totalPages = event['total_pages'] as int? ?? 1;
    final percentage = (event['percentage'] is num) ? (event['percentage'] as num).toDouble() : 0.0;
    final remainingSecs = event['estimated_seconds_remaining'] as int?;

    final updatedTasks = state.tasks.map((task) {
      if (task.taskId == taskId) {
        return task.copyWith(
          status: TaskStatus.fromString(statusStr),
          currentPage: currentPage,
          totalPages: totalPages,
          percentage: percentage,
          estimatedSecondsRemaining: remainingSecs,
        );
      }
      return task;
    }).toList();

    state = state.copyWith(tasks: updatedTasks);
  }

  Future<void> loadInitialTasks() async {
    try {
      final tasks = await _apiService.fetchAllTasks();
      state = state.copyWith(tasks: tasks);
    } catch (_) {
      // Offline fallback: keep local tasks
    }
  }

  void setTargetLanguage(String langCode) {
    state = state.copyWith(targetLanguage: langCode);
  }

  void setSourceLanguage(String langCode) {
    state = state.copyWith(sourceLanguage: langCode);
  }

  void setPreserveLayout(bool preserve) {
    state = state.copyWith(preserveLayout: preserve);
  }

  void selectTask(String? taskId) {
    state = state.copyWith(selectedTaskId: taskId);
  }

  Future<void> uploadFiles(List<PlatformFile> files) async {
    if (files.isEmpty) return;

    state = state.copyWith(isUploading: true, errorMessage: null);

    try {
      final newTasks = await _apiService.uploadFiles(
        files: files,
        targetLanguage: state.targetLanguage,
        sourceLanguage: state.sourceLanguage,
        preserveLayout: state.preserveLayout,
        clientId: state.clientId,
      );

      final combined = [...newTasks, ...state.tasks];
      state = state.copyWith(
        tasks: combined,
        isUploading: false,
        selectedTaskId: newTasks.isNotEmpty ? newTasks.first.taskId : state.selectedTaskId,
      );
    } catch (e) {
      state = state.copyWith(
        isUploading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> retryTask(String taskId) async {
    try {
      await _apiService.retryTask(taskId);
      final updated = state.tasks.map((t) {
        if (t.taskId == taskId) {
          return t.copyWith(status: TaskStatus.pending, percentage: 0.0, errorMessage: null);
        }
        return t;
      }).toList();
      state = state.copyWith(tasks: updated);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  void clearCompleted() {
    final filtered = state.tasks.where((t) => t.status != TaskStatus.completed).toList();
    state = state.copyWith(tasks: filtered);
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }
}

final taskQueueProvider = StateNotifierProvider<TaskQueueNotifier, TaskQueueState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  final wsService = ref.watch(webSocketServiceProvider);
  return TaskQueueNotifier(apiService: apiService, wsService: wsService);
});
