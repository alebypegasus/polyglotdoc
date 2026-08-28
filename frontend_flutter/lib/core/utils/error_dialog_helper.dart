import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

class ErrorDialogHelper {
  static void showErrorModal({
    required BuildContext context,
    required String title,
    required String message,
    String? technicalDetails,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  if (technicalDetails != null && technicalDetails.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'Detalhes Técnicos do Servidor / API:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: SelectableText(
                        technicalDetails,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: AppColors.cyanAccent,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            if (technicalDetails != null && technicalDetails.isNotEmpty)
              TextButton.icon(
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: const Text('Copiar Erro', style: TextStyle(fontSize: 12)),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: '$message\n\n$technicalDetails'));
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Detalhes do erro copiados para a área de transferência.'),
                      backgroundColor: AppColors.surfaceElevated,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            if (actionLabel != null && onAction != null)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  onAction();
                },
                child: Text(actionLabel, style: const TextStyle(fontSize: 12)),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Fechar', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ),
          ],
        );
      },
    );
  }
}
