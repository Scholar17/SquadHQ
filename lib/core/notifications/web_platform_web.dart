import 'package:web/web.dart' as web;

/// An iPhone or iPad browser — every browser there is Safari underneath,
/// and web push only works for web apps opened from the Home Screen.
bool get isIosWeb {
  final navigator = web.window.navigator;
  final agent = navigator.userAgent.toLowerCase();
  // iPadOS reports itself as a Mac; touch support gives it away.
  final iPadOs = navigator.platform == 'MacIntel' && navigator.maxTouchPoints > 1;
  return agent.contains('iphone') || agent.contains('ipad') || agent.contains('ipod') || iPadOs;
}

/// Opened as an installed app (Home Screen / "Install app"), not a tab.
bool get isStandaloneWebApp =>
    web.window.matchMedia('(display-mode: standalone)').matches ||
    web.window.matchMedia('(display-mode: fullscreen)').matches;
