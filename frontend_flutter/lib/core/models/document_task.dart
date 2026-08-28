enum TaskStatus {
  pending,
  extracting,
  translating,
  reconstructing,
  completed,
  failed;

  static TaskStatus fromString(String status) {
    switch (status.toLowerCase().trim()) {
      case 'extracting':
        return TaskStatus.extracting;
      case 'translating':
        return TaskStatus.translating;
      case 'reconstructing':
        return TaskStatus.reconstructing;
      case 'completed':
        return TaskStatus.completed;
      case 'failed':
        return TaskStatus.failed;
      case 'pending':
      default:
        return TaskStatus.pending;
    }
  }

  String get label {
    switch (this) {
      case TaskStatus.pending:
        return 'Na fila';
      case TaskStatus.extracting:
        return 'Extraindo';
      case TaskStatus.translating:
        return 'Traduzindo';
      case TaskStatus.reconstructing:
        return 'Reconstruindo';
      case TaskStatus.completed:
        return 'Concluído';
      case TaskStatus.failed:
        return 'Erro';
    }
  }
}

class DocumentTask {
  final String taskId;
  final String clientId;
  final String? batchId;
  final String filename;
  final String outputFilename;
  final String targetLanguage;
  final String sourceLanguage;
  final bool preserveLayout;
  final TaskStatus status;
  final int currentPage;
  final int totalPages;
  final double percentage;
  final int? estimatedSecondsRemaining;
  final String? errorMessage;
  final int fileSizeBytes;
  final DateTime createdAt;

  DocumentTask({
    required this.taskId,
    this.clientId = 'default',
    this.batchId,
    required this.filename,
    required this.outputFilename,
    required this.targetLanguage,
    this.sourceLanguage = 'auto',
    this.preserveLayout = true,
    this.status = TaskStatus.pending,
    this.currentPage = 0,
    this.totalPages = 1,
    this.percentage = 0.0,
    this.estimatedSecondsRemaining,
    this.errorMessage,
    this.fileSizeBytes = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory DocumentTask.fromJson(Map<String, dynamic> json) {
    return DocumentTask(
      taskId: json['task_id'] ?? '',
      clientId: json['client_id'] ?? 'default',
      batchId: json['batch_id'],
      filename: json['filename'] ?? 'document',
      outputFilename: json['output_filename'] ?? json['filename'] ?? 'document',
      targetLanguage: json['target_language'] ?? 'PT-BR',
      sourceLanguage: json['source_language'] ?? 'auto',
      preserveLayout: json['preserve_layout'] ?? true,
      status: TaskStatus.fromString(json['status'] ?? 'pending'),
      currentPage: json['current_page'] ?? 0,
      totalPages: (json['total_pages'] ?? 1) == 0 ? 1 : json['total_pages'],
      percentage: (json['percentage'] is num) ? (json['percentage'] as num).toDouble() : 0.0,
      estimatedSecondsRemaining: json['estimated_seconds_remaining'],
      errorMessage: json['error_message'],
      fileSizeBytes: json['file_size_bytes'] ?? 0,
      createdAt: json['created_at'] != null 
          ? DateTime.fromMillisecondsSinceEpoch((json['created_at'] * 1000).toInt())
          : DateTime.now(),
    );
  }

  DocumentTask copyWith({
    String? taskId,
    String? clientId,
    String? batchId,
    String? filename,
    String? outputFilename,
    String? targetLanguage,
    String? sourceLanguage,
    bool? preserveLayout,
    TaskStatus? status,
    int? currentPage,
    int? totalPages,
    double? percentage,
    int? estimatedSecondsRemaining,
    String? errorMessage,
    int? fileSizeBytes,
    DateTime? createdAt,
  }) {
    return DocumentTask(
      taskId: taskId ?? this.taskId,
      clientId: clientId ?? this.clientId,
      batchId: batchId ?? this.batchId,
      filename: filename ?? this.filename,
      outputFilename: outputFilename ?? this.outputFilename,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      preserveLayout: preserveLayout ?? this.preserveLayout,
      status: status ?? this.status,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      percentage: percentage ?? this.percentage,
      estimatedSecondsRemaining: estimatedSecondsRemaining ?? this.estimatedSecondsRemaining,
      errorMessage: errorMessage ?? this.errorMessage,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get formattedFileSize {
    if (fileSizeBytes <= 0) return '';
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
