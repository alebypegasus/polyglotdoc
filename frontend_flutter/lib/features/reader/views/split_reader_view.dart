import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/document_task.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/file_saver.dart';

enum ReaderMode { visualPdf, textBlocks }

class SplitReaderView extends ConsumerStatefulWidget {
  final DocumentTask task;
  final VoidCallback? onClose;

  const SplitReaderView({
    super.key,
    required this.task,
    this.onClose,
  });

  @override
  ConsumerState<SplitReaderView> createState() => _SplitReaderViewState();
}

class _SplitReaderViewState extends ConsumerState<SplitReaderView> {
  int _currentPage = 1;
  double _fontSize = 14.0;
  ReaderMode _readerMode = ReaderMode.visualPdf;
  bool _isLoadingPreview = false;
  Map<String, dynamic>? _previewData;

  @override
  void initState() {
    super.initState();
    _loadPreviewData();
  }

  Future<void> _loadPreviewData() async {
    setState(() => _isLoadingPreview = true);
    try {
      final data = await ref.read(apiServiceProvider).fetchTaskPreview(widget.task.taskId);
      setState(() {
        _previewData = data;
        _isLoadingPreview = false;
      });
    } catch (_) {
      setState(() => _isLoadingPreview = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = widget.task.totalPages > 0 ? widget.task.totalPages : 1;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Header Bar
          _buildHeader(totalPages),

          const Divider(height: 1, color: AppColors.border),

          // Main Content (Visual PDF Mode or Text Blocks Mode)
          Expanded(
            child: _readerMode == ReaderMode.visualPdf
                ? _buildVisualPdfSplitView()
                : _buildTextBlocksSplitView(),
          ),

          const Divider(height: 1, color: AppColors.border),

          // Bottom Navigation / Page Switcher Bar
          _buildBottomBar(totalPages),
        ],
      ),
    );
  }

  Widget _buildHeader(int totalPages) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.compare_rounded, color: AppColors.cyanAccent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.task.filename,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Traduzido para ${widget.task.targetLanguage} • Pág $_currentPage de $totalPages',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),

          // Reader Mode Switch (Visual PDF vs Text Blocks)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModeButton(
                  title: 'Visual PDF',
                  icon: Icons.picture_as_pdf_rounded,
                  mode: ReaderMode.visualPdf,
                ),
                _buildModeButton(
                  title: 'Texto',
                  icon: Icons.notes_rounded,
                  mode: ReaderMode.textBlocks,
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Save / Download Button
          ElevatedButton.icon(
            onPressed: widget.task.status == TaskStatus.completed
                ? () {
                    FileSaverHelper.saveDocument(
                      context: context,
                      apiService: ref.read(apiServiceProvider),
                      task: widget.task,
                    );
                  }
                : null,
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Salvar Como...', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),

          if (widget.onClose != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 20),
              onPressed: widget.onClose,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required String title,
    required IconData icon,
    required ReaderMode mode,
  }) {
    final isSelected = _readerMode == mode;
    return InkWell(
      onTap: () => setState(() => _readerMode = mode),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : AppColors.textMuted),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualPdfSplitView() {
    final origUrl = AppConstants.taskPageImageUrl(widget.task.taskId, _currentPage, 'original');
    final transUrl = AppConstants.taskPageImageUrl(widget.task.taskId, _currentPage, 'translated');
    final isCompleted = widget.task.status == TaskStatus.completed;

    return Row(
      children: [
        // Left Column: Original Document Page Image
        Expanded(
          child: Container(
            color: const Color(0xFF0D1117),
            child: Column(
              children: [
                _buildColumnHeader('Original (${widget.task.sourceLanguage})', AppColors.textSecondary),
                Expanded(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Center(
                      child: Image.network(
                        origUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (ctx, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(color: AppColors.cyanAccent),
                          );
                        },
                        errorBuilder: (ctx, err, stack) => _buildPlaceholderOrError(
                          'Página original indisponível para renderização visual.\nUse o modo Texto.',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const VerticalDivider(width: 1, color: AppColors.border),

        // Right Column: Translated Document Page Image (or In-Progress Live Status)
        Expanded(
          child: Container(
            color: const Color(0xFF0D1117),
            child: Column(
              children: [
                _buildColumnHeader('Traduzido (${widget.task.targetLanguage})', AppColors.cyanAccent),
                Expanded(
                  child: isCompleted
                      ? InteractiveViewer(
                          minScale: 0.5,
                          maxScale: 4.0,
                          child: Center(
                            child: Image.network(
                              transUrl,
                              fit: BoxFit.contain,
                              loadingBuilder: (ctx, child, progress) {
                                if (progress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(color: AppColors.cyanAccent),
                                );
                              },
                              errorBuilder: (ctx, err, stack) => _buildPlaceholderOrError(
                                'Aguardando renderização final da página traduzida...',
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(color: AppColors.cyanAccent),
                                const SizedBox(height: 16),
                                Text(
                                  widget.task.status.label,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.cyanAccent,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Página ${widget.task.currentPage} de ${widget.task.totalPages} (${widget.task.percentage.toStringAsFixed(1)}%)\nO visualizador traduzido será exibido após a conclusão.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                ),
                              ],
                            ),
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

  Widget _buildPlaceholderOrError(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_rounded, color: AppColors.textMuted, size: 40),
            const SizedBox(height: 12),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextBlocksSplitView() {
    if (_isLoadingPreview) {
      return const Center(child: CircularProgressIndicator(color: AppColors.cyanAccent));
    }

    final pages = (_previewData?['pages'] as List<dynamic>?) ?? [];
    Map<String, dynamic>? currentPageData;

    for (final p in pages) {
      if (p['page_number'] == _currentPage) {
        currentPageData = p as Map<String, dynamic>;
        break;
      }
    }

    final origBlocks = (currentPageData?['original_blocks'] as List<dynamic>?) ?? [];
    final transBlocks = (currentPageData?['translated_blocks'] as List<dynamic>?) ?? [];

    return Row(
      children: [
        // Left Column: Original Text Blocks
        Expanded(
          child: Column(
            children: [
              _buildColumnHeader('Texto Original (${widget.task.sourceLanguage})', AppColors.textSecondary),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: origBlocks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final block = origBlocks[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: SelectableText(
                        block['text'] ?? '',
                        style: TextStyle(
                          fontSize: _fontSize,
                          color: AppColors.textPrimary,
                          height: 1.5,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        const VerticalDivider(width: 1, color: AppColors.border),

        // Right Column: Translated Text Blocks
        Expanded(
          child: Column(
            children: [
              _buildColumnHeader('Texto Traduzido (${widget.task.targetLanguage})', AppColors.cyanAccent),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: transBlocks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final block = transBlocks[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: SelectableText(
                        block['translated_text'] ?? block['text'] ?? '',
                        style: TextStyle(
                          fontSize: _fontSize,
                          color: AppColors.textPrimary,
                          height: 1.5,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildColumnHeader(String title, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surfaceElevated,
      child: Text(
        title,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildBottomBar(int totalPages) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Font size adjustments for text mode
          if (_readerMode == ReaderMode.textBlocks)
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_rounded, size: 18),
                  onPressed: () => setState(() => _fontSize = (_fontSize - 1).clamp(10.0, 24.0)),
                  tooltip: 'Diminuir fonte',
                ),
                Text('${_fontSize.toInt()} px', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                IconButton(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  onPressed: () => setState(() => _fontSize = (_fontSize + 1).clamp(10.0, 24.0)),
                  tooltip: 'Aumentar fonte',
                ),
              ],
            )
          else
            const Text(
              'Use a roda do mouse ou pinça para Zoom no PDF',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),

          // Page Switcher Controls
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, color: AppColors.cyanAccent),
                onPressed: _currentPage > 1
                    ? () => setState(() => _currentPage--)
                    : null,
                tooltip: 'Página Anterior',
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'Página $_currentPage de $totalPages',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, color: AppColors.cyanAccent),
                onPressed: _currentPage < totalPages
                    ? () => setState(() => _currentPage++)
                    : null,
                tooltip: 'Próxima Página',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
