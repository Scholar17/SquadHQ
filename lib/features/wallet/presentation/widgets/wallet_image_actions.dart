import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/injection_container.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../../domain/usecases/download_wallet_image.dart';
import '../../domain/usecases/get_wallet_image_url.dart';

typedef PickedImage = ({Uint8List bytes, String fileExtension});

const _allowedExtensions = {'jpg', 'jpeg', 'png', 'webp', 'heic'};

/// Picks one image from the gallery (a QR code or payment slip
/// screenshot), or null if the user backs out.
Future<PickedImage?> pickWalletImage() async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 2000,
    imageQuality: 90,
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
/// open it from their banking app's "scan from gallery". On web, opens the
/// image in a new tab to download instead.
Future<void> saveWalletQr(BuildContext context, String path) async {
  final params = WalletImageParams(WalletImageKind.walletQr, path);
  if (kIsWeb) {
    final result = await sl<GetWalletImageUrl>()(params);
    await result.fold(
      (failure) async {
        if (context.mounted) _snack(context, failure.message);
      },
      (url) => launchUrl(Uri.parse(url), webOnlyWindowName: '_blank'),
    );
    return;
  }
  final result = await sl<DownloadWalletImage>()(params);
  await result.fold(
    (failure) async {
      if (context.mounted) _snack(context, failure.message);
    },
    (bytes) async {
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
