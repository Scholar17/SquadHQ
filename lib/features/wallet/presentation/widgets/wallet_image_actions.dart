import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/clipboard/clipboard_image.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/download/download_file.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../../domain/usecases/download_wallet_image.dart';
import '../../domain/usecases/get_wallet_image_url.dart' show WalletImageParams;

typedef PickedImage = ({Uint8List bytes, String fileExtension});

const _allowedExtensions = {'jpg', 'jpeg', 'png', 'webp', 'heic'};

/// Picks one image (a QR code or payment slip screenshot), or null if the
/// user backs out. Where there's more than one way, asks first: from
/// Photos, a camera photo (a [slip] — a printed receipt, say) or paste
/// (iOS, Android, the web). A [slip] fits within 1280×2560 at JPEG
/// quality 80: a phone screenshot keeps its full size and stays sharp, a
/// camera photo shrinks to a few hundred KB. A QR code keeps more detail
/// so banking apps can scan it.
Future<PickedImage?> pickWalletImage(BuildContext context, {bool slip = false}) async {
  // Phones only; iOS asks first (Info.plist's NSCameraUsageDescription).
  // On the web it opens the camera straight away, skipping the browser's
  // own Camera / Files menu.
  final canUseCamera = slip &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
  if (!canPasteImage && !canUseCamera) return _pickImage(slip: slip);
  final messenger = ScaffoldMessenger.of(context);
  // Each option starts its pick inside the tap itself: the web only opens
  // the file chooser or reads the clipboard during a user's gesture.
  final picking = await showModalBottomSheet<Future<PickedImage?>>(
    context: context,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(
                'Choose from Photos',
                style: AppTextStyles.body(size: 15, weight: FontWeight.w700),
              ),
              onTap: () => Navigator.of(sheetContext).pop(_pickImage(slip: slip)),
            ),
            if (canUseCamera)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(
                  'Take photo',
                  style: AppTextStyles.body(size: 15, weight: FontWeight.w700),
                ),
                onTap: () => Navigator.of(sheetContext).pop(
                  _pickImage(slip: slip, source: ImageSource.camera),
                ),
              ),
            if (canPasteImage)
              ListTile(
                leading: const Icon(Icons.content_paste_rounded),
                title: Text(
                  'Paste copied photo',
                  style: AppTextStyles.body(size: 15, weight: FontWeight.w700),
                ),
                subtitle: Text(
                  'Copied from Photos or a banking app',
                  style: AppTextStyles.body(size: 12, color: AppColors.textMuted),
                ),
                onTap: () => Navigator.of(sheetContext).pop(_paste(messenger, slip: slip)),
              ),
          ],
        ),
      ),
    ),
  );
  return picking == null ? null : await picking;
}

Future<PickedImage?> _paste(ScaffoldMessengerState messenger, {required bool slip}) async {
  final bytes = await pasteClipboardImage(
    maxWidth: slip ? 1280 : 2000,
    maxHeight: slip ? 2560 : null,
    quality: slip ? 80 : 90,
  );
  if (bytes == null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('No copied photo found. Long-press a photo, tap Copy, then try again.'),
        ),
      );
    return null;
  }
  return (bytes: bytes, fileExtension: 'jpg');
}

Future<PickedImage?> _pickImage({
  required bool slip,
  ImageSource source = ImageSource.gallery,
}) async {
  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: slip ? 1280 : 2000,
    maxHeight: slip ? 2560 : null,
    imageQuality: slip ? 80 : 90,
  );
  if (file == null) return null;
  final name = file.name.toLowerCase();
  final extension = name.contains('.') ? name.split('.').last : '';
  return (
    bytes: await file.readAsBytes(),
    fileExtension: _allowedExtensions.contains(extension) ? extension : 'jpg',
  );
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Saves a payer's wallet QR to the phone's photos, so a teammate can
/// open it from their banking app's "scan from gallery". On web, downloads
/// it as a file.
Future<void> saveWalletQr(BuildContext context, String path) async {
  final params = WalletImageParams(WalletImageKind.walletQr, path);
  final result = await sl<DownloadWalletImage>()(params);
  await result.fold(
    (failure) async {
      if (context.mounted) _snack(context, failure.message);
    },
    (bytes) async {
      if (kIsWeb) {
        final extension = path.contains('.') ? path.split('.').last.toLowerCase() : 'jpg';
        Future<DownloadOutcome> save() => downloadFile(
              bytes,
              fileName: 'squad-hq-wallet-qr.$extension',
              mimeType: 'image/${extension == 'jpg' ? 'jpeg' : extension}',
            );
        final outcome = await save();
        if (!context.mounted) return;
        switch (outcome) {
          case DownloadOutcome.downloaded:
            _snack(context, 'QR downloaded');
          case DownloadOutcome.needsTap:
            // Safari lost the tap while the image loaded; this tap opens
            // the share sheet with the QR already in hand.
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: const Text('QR ready to save'),
                  action: SnackBarAction(label: 'Save', onPressed: save),
                  duration: const Duration(seconds: 8),
                ),
              );
          case DownloadOutcome.shared:
          case DownloadOutcome.cancelled:
            break;
        }
        return;
      }
      try {
        if (!await Gal.hasAccess()) await Gal.requestAccess();
        await Gal.putImageBytes(bytes, name: 'squad-hq-wallet-qr');
        if (context.mounted) _snack(context, 'QR saved to your photos');
      } on GalException catch (e) {
        if (context.mounted) _snack(context, "Couldn't save the QR: ${e.type.message}");
      }
    },
  );
}
