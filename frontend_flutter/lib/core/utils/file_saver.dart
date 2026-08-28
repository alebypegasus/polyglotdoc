import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/document_task.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class FileSaverHelper {
  static Future<void> saveDocument({
    required BuildContext context,
    required ApiService apiService,
    required DocumentTask task,
  }) async {
    // 1. Validate status
    if (task.status != TaskStatus.completed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'O documento ainda está em processamento (${task.percentage.toStringAsFixed(1)}%).\nAguarde a conclusão para salvar o arquivo final.',
          ),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Obtendo ${task.outputFilename}...'),
          backgroundColor: AppColors.surfaceElevated,
          duration: const Duration(seconds: 2),
        ),
      );

      final bytes = await apiService.downloadFileBytes(task.taskId);

      if (bytes.isEmpty) {
        throw Exception('Arquivo vazio recebido do servidor.');
      }

      // Determine extension
      String ext = 'pdf';
      if (task.filename.contains('.')) {
        ext = task.filename.split('.').last.toLowerCase();
      }

      String defaultName = task.outputFilename.isNotEmpty
          ? task.outputFilename
          : '${task.filename.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')} - Traduzido ${task.targetLanguage.toUpperCase()}.$ext';

      String? chosenPath;

      try {
        chosenPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Salvar documento traduzido em:',
          fileName: defaultName,
          type: FileType.custom,
          allowedExtensions: [ext],
        );
      } catch (pickerErr) {
        debugPrint('FilePicker saveFile error, falling back to directory picker: $pickerErr');
      }

      // Fallback if saveFile dialog is not supported on current platform
      if (chosenPath == null && !kIsWeb) {
        try {
          final dirPath = await FilePicker.platform.getDirectoryPath(
            dialogTitle: 'Selecione a pasta para salvar o documento:',
          );
          if (dirPath != null) {
            chosenPath = '$dirPath/$defaultName';
          }
        } catch (_) {}
      }

      // If user cancelled, return quietly
      if (chosenPath == null) {
        return;
      }

      // Ensure extension is present
      if (!chosenPath.toLowerCase().endsWith('.$ext')) {
        chosenPath = '$chosenPath.$ext';
      }

      // Save bytes to disk
      if (!kIsWeb) {
        final file = File(chosenPath);
        await file.writeAsBytes(bytes, flush: true);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Documento salvo com sucesso!',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        chosenPath,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.surface,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: AppColors.cyanAccent,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falha ao salvar documento: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}
