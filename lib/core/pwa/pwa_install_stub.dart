import 'package:flutter/widgets.dart';

/// Not running in a browser.
void initPwaInstall() {}

/// Not running in a browser — never changes.
final Listenable pwaInstallChanges = ValueNotifier(false);

/// Not running in a browser — nothing to install.
bool get canInstallPwa => false;

/// Not running in a browser.
Future<void> installPwa(BuildContext context) async {}

/// Not running in a browser — no steps.
class PwaInstallSteps extends StatelessWidget {
  const PwaInstallSteps({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
