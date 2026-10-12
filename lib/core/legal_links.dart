import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// The privacy policy and terms, served with the web app (web/privacy.html,
/// web/terms.html).
const privacyPolicyUrl = 'https://squad-hq.web.app/privacy.html';
const termsOfServiceUrl = 'https://squad-hq.web.app/terms.html';

/// Opens the privacy policy in an in-app browser view (a new tab on web).
Future<void> openPrivacyPolicy(BuildContext context) =>
    _open(context, privacyPolicyUrl, "Couldn't open the privacy policy.");

/// Opens the terms of service the same way.
Future<void> openTermsOfService(BuildContext context) =>
    _open(context, termsOfServiceUrl, "Couldn't open the terms of service.");

Future<void> _open(BuildContext context, String url, String failed) async {
  final messenger = ScaffoldMessenger.of(context);
  final opened = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.inAppBrowserView,
    webOnlyWindowName: '_blank',
  );
  if (!opened) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(failed)));
  }
}
