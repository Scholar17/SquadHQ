import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:pwa_installer/pwa_installer.dart';
import 'package:web/web.dart' as web;

import '../notifications/web_platform.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';

/// Chrome's latest install offer (`beforeinstallprompt`), kept by
/// index.html — it can arrive before Flutter loads, and again after a
/// Cancel. Each offer opens Chrome's dialog once.
@JS('__pwaInstallPrompt')
external JSObject? _offer;

extension type _InstallOffer(JSObject _) implements JSObject {
  external JSPromise<JSAny?> prompt();
  external JSPromise<_InstallChoice> get userChoice;
}

extension type _InstallChoice(JSObject _) implements JSObject {
  external String get outcome;
}

final _offerReady = ValueNotifier(false);
final _installed = ValueNotifier(false);

/// Chrome's install dialog is open — taps wait for Cancel/Install, so a
/// second dialog never stacks on the first.
bool _prompting = false;

/// Call once in main(), before runApp: picks up Chrome's install offer for
/// Profile's "Install app" row.
void initPwaInstall() {
  _offerReady.value = _offer != null;
  web.window.addEventListener(
    'beforeinstallprompt',
    // index.html has already kept it (and stopped Chrome's own banner).
    ((web.Event _) => _offerReady.value = true).toJS,
  );
  web.window.addEventListener(
    'appinstalled',
    ((web.Event _) {
      _offer = null;
      _offerReady.value = false;
      _installed.value = true;
    }).toJS,
  );
}

/// Fires when Chrome's install offer arrives or the app gets installed.
final Listenable pwaInstallChanges = Listenable.merge([_offerReady, _installed]);

/// A browser tab Squad HQ could be installed from: Chrome is offering its
/// install dialog, or it's a phone (where Add to Home Screen always works,
/// even if we have to explain it). False once installed or opened as the
/// installed app.
bool get canInstallPwa {
  if (isStandaloneWebApp || _installed.value) return false;
  return _offerReady.value || PwaInstaller.isMobile() || isIosWeb;
}

/// Installs straight away when Chrome allows it (its own Install dialog).
/// Otherwise — iPhone/iPad, which never let a site install itself, an
/// in-app browser, or Chrome with nothing on offer right now — shows the
/// menu steps.
Future<void> installPwa(BuildContext context) async {
  if (_prompting) return;
  final offer = _offer;
  if (offer != null) {
    _prompting = true;
    // Used up either way — Chrome sends a fresh one if it'll ask again.
    _offer = null;
    _offerReady.value = false;
    try {
      final install = _InstallOffer(offer);
      await install.prompt().toDart;
      final choice = await install.userChoice.toDart;
      if (choice.outcome == 'accepted') _installed.value = true;
    } catch (_) {
      // Already used or withdrawn — the next offer brings the row back.
    } finally {
      _prompting = false;
    }
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
    builder: (_) => const _InstallStepsSheet(),
  );
}

class _InstallStepsSheet extends StatelessWidget {
  const _InstallStepsSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Install Squad HQ', style: AppTextStyles.title(size: 18)),
            const SizedBox(height: 4),
            Text(
              'A full-screen app on your Home Screen, with notifications.',
              style: AppTextStyles.body(size: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            const PwaInstallSteps(),
          ],
        ),
      ),
    );
  }
}

/// The Add to Home Screen steps for this browser — Profile's install sheet
/// and the notifications gate on an iPhone browser tab.
class PwaInstallSteps extends StatelessWidget {
  const PwaInstallSteps({super.key});

  @override
  Widget build(BuildContext context) {
    // LINE, Messenger, Instagram … can't add to the Home Screen — out to
    // the real browser first.
    final inApp = PwaInstaller.isInAppBrowser();
    final browser = isIosWeb ? 'Safari' : 'Chrome';
    final steps = [
      if (inApp)
        (Icons.open_in_browser_rounded, 'Open this page in $browser (⋯ menu → "Open in browser")'),
      if (isIosWeb) ...[
        (Icons.ios_share_rounded, 'Tap Share (on newer iPhones: tap ⋯, then Share)'),
        (Icons.add_box_outlined, 'Choose "Add to Home Screen", then Add'),
      ] else ...[
        (Icons.more_vert_rounded, 'Tap ⋮ in Chrome, then "Add to home screen"'),
        (Icons.install_mobile_rounded, 'Choose "Install" (not "Create shortcut"), then Install'),
      ],
      (Icons.touch_app_outlined, 'Open Squad HQ from your Home Screen'),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (icon, text) in steps)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.accent700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: AppTextStyles.body(size: 13.5, weight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
