import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../queue/providers/task_queue_provider.dart';

class UploadDropzone extends ConsumerStatefulWidget {
  final bool isCompact;

  const UploadDropzone({super.key, this.isCompact = false});

  @override
  ConsumerState<UploadDropzone> createState() => _UploadDropzoneState();
}

class _UploadDropzoneState extends ConsumerState<UploadDropzone> {
  bool _isDragging = false;

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'epub', 'mobi', 'docx', 'doc'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      ref.read(taskQueueProvider.notifier).uploadFiles(result.files);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(taskQueueProvider);

    return DropTarget(
      onDragEntered: (details) => setState(() => _isDragging = true),
      onDragExited: (details) => setState(() => _isDragging = false),
      onDragDone: (details) async {
        setState(() => _isDragging = false);
        final platformFiles = <PlatformFile>[];
        for (final xFile in details.files) {
          final ext = xFile.name.split('.').last.toLowerCase();
          if (['pdf', 'epub', 'mobi', 'docx', 'doc'].contains(ext)) {
            final bytes = await xFile.readAsBytes();
            platformFiles.add(
              PlatformFile(
                name: xFile.name,
                size: bytes.length,
                bytes: bytes,
                path: xFile.path,
              ),
            );
          }
        }
        if (platformFiles.isNotEmpty) {
          ref.read(taskQueueProvider.notifier).uploadFiles(platformFiles);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(widget.isCompact ? 14 : 24),
        decoration: BoxDecoration(
          color: _isDragging ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isDragging ? AppColors.cyanAccent : AppColors.border,
            width: _isDragging ? 2.0 : 1.0,
          ),
          boxShadow: _isDragging
              ? [
                  BoxShadow(
                    color: AppColors.cyanAccent.withValues(alpha: 0.2),
                    blurRadius: 16,
                    spreadRadius: 2,
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: const Icon(
                Icons.cloud_upload_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _isDragging ? 'Solte os arquivos aqui!' : 'Arraste e solte seus documentos ou livros',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Suporta PDFs, eBooks (.epub, .mobi) e documentos (.docx) em lote ou individual',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: state.isUploading ? null : _pickFiles,
              icon: state.isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.file_open_rounded, size: 16),
              label: Text(
                state.isUploading ? 'Enviando...' : 'Selecionar Arquivos',
                style: const TextStyle(fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Text(
                  state.errorMessage!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
