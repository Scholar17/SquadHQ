import 'package:flutter/material.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../../domain/usecases/get_wallet_image_url.dart';

/// A wallet QR or payment slip from private storage, shown through a
/// signed URL (see WalletRepository.getImageUrl).
class WalletImage extends StatefulWidget {
  const WalletImage({
    super.key,
    required this.kind,
    required this.path,
    this.fit = BoxFit.contain,
  });

  final WalletImageKind kind;
  final String path;
  final BoxFit fit;

  @override
  State<WalletImage> createState() => _WalletImageState();
}

class _WalletImageState extends State<WalletImage> {
  late Future<String?> _url = _load();

  Future<String?> _load() async {
    final result = await sl<GetWalletImageUrl>()(WalletImageParams(widget.kind, widget.path));
    return result.fold((_) => null, (url) => url);
  }

  @override
  void didUpdateWidget(WalletImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path || oldWidget.kind != widget.kind) {
      _url = _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _url,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.accent),
          );
        }
        final url = snapshot.data;
        if (url == null) return const _ImageUnavailable();
        return Image.network(
          url,
          fit: widget.fit,
          errorBuilder: (context, error, stackTrace) => const _ImageUnavailable(),
        );
      },
    );
  }
}

class _ImageUnavailable extends StatelessWidget {
  const _ImageUnavailable();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        "Couldn't load image",
        style: AppTextStyles.body(size: 12, color: AppColors.text.withValues(alpha: 0.5)),
      ),
    );
  }
}

/// Full-screen, pinch-to-zoom view of a wallet image.
Future<void> showWalletImageViewer(
  BuildContext context, {
  required WalletImageKind kind,
  required String path,
  required String title,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog.fullscreen(
      backgroundColor: AppColors.neutral900,
      child: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.heading(size: 16, color: AppColors.neutral100),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close_rounded, color: AppColors.neutral100),
                  tooltip: 'Close',
                ),
              ],
            ),
            Expanded(
              child: InteractiveViewer(
                maxScale: 5,
                child: WalletImage(kind: kind, path: path),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
