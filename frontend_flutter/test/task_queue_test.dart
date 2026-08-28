import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/core/models/document_task.dart';

void main() {
  group('DocumentTask and TaskStatus Tests', () {
    test('TaskStatus parsing from string', () {
      expect(TaskStatus.fromString('pending'), TaskStatus.pending);
      expect(TaskStatus.fromString('extracting'), TaskStatus.extracting);
      expect(TaskStatus.fromString('translating'), TaskStatus.translating);
      expect(TaskStatus.fromString('reconstructing'), TaskStatus.reconstructing);
      expect(TaskStatus.fromString('completed'), TaskStatus.completed);
      expect(TaskStatus.fromString('failed'), TaskStatus.failed);
      expect(TaskStatus.fromString('unknown_status'), TaskStatus.pending);
    });

    test('DocumentTask deserialization and formatting', () {
      final json = {
        'task_id': 'test-123',
        'client_id': 'c1',
        'filename': 'Quantum_Physics.pdf',
        'output_filename': 'Quantum_Physics - Traduzido PTBR.pdf',
        'target_language': 'PT-BR',
        'source_language': 'en',
        'preserve_layout': true,
        'status': 'translating',
        'current_page': 10,
        'total_pages': 50,
        'percentage': 20.0,
        'estimated_seconds_remaining': 45,
        'file_size_bytes': 2048000,
      };

      final task = DocumentTask.fromJson(json);

      expect(task.taskId, 'test-123');
      expect(task.filename, 'Quantum_Physics.pdf');
      expect(task.outputFilename, 'Quantum_Physics - Traduzido PTBR.pdf');
      expect(task.status, TaskStatus.translating);
      expect(task.currentPage, 10);
      expect(task.totalPages, 50);
      expect(task.percentage, 20.0);
      expect(task.estimatedSecondsRemaining, 45);
      expect(task.formattedFileSize, '2.0 MB');
    });

    test('DocumentTask copyWith updates properties', () {
      final task = DocumentTask(
        taskId: 't1',
        filename: 'Book.epub',
        outputFilename: 'Book - Translated EN.epub',
        targetLanguage: 'EN',
        totalPages: 10,
      );

      final updated = task.copyWith(
        status: TaskStatus.completed,
        percentage: 100.0,
        currentPage: 10,
      );

      expect(updated.taskId, 't1');
      expect(updated.status, TaskStatus.completed);
      expect(updated.percentage, 100.0);
      expect(updated.currentPage, 10);
    });
  });
}
