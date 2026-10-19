import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/share/share_link.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/share_link.dart';
import '../../domain/usecases/share_usecases.dart';

/// "Share match" / "Share bill": a link to send in Messenger, Facebook or
/// anywhere, whose preview card shows the match (cloudflare/share-preview).
///
/// Sharing also pushes the team (055), so teammates can open it in the
/// installed app.
///
/// The link is fetched as soon as this shows, so a tap can open the share
/// sheet at once — browsers only allow that during the tap itself.
class ShareLinkButton extends StatefulWidget {
  const ShareLinkButton({
    super.key,
    required this.matchId,
    required this.kind,
    required this.shareTitle,
    this.embedded = false,
  });

  final String matchId;
  final ShareKind kind;

  /// The share sheet's title, e.g. "vs Red Lions · Sat 25 Oct".
  final String shareTitle;

  /// Inside another card or sheet: a plain row, no card of its own.
  final bool embedded;

  @override
  State<ShareLinkButton> createState() => _ShareLinkButtonState();
}

class _ShareLinkButtonState extends State<ShareLinkButton> {
  String? _url;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ShareLinkButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.matchId != widget.matchId || oldWidget.kind != widget.kind) {
      _url = null;
      _load();
    }
  }

  Future<void> _load() async {
    final result = await sl<GetShareLink>()((matchId: widget.matchId, kind: widget.kind));
    if (!mounted) return;
    setState(() {
      _url = result.fold((_) => null, (url) => url);
      _error = result.fold((failure) => failure.message, (_) => null);
    });
  }

  Future<void> _share() async {
    final url = _url;
    final messenger = ScaffoldMessenger.of(context);
    void say(String message) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    if (url == null) {
      // The first fetch failed (offline?): try again, and say why if not.
      await _load();
      if (_url == null) say(_error ?? "Couldn't make a link. Try again.");
      return;
    }
    final outcome = await shareLink(url: url, title: widget.shareTitle);
    if (outcome == ShareOutcome.cancelled) return;
    // The team gets a push too: on iPhone, a link opens in the browser,
    // but a tapped push opens the installed web app. Best effort.
    unawaited(sl<RecordShare>()((matchId: widget.matchId, kind: widget.kind)));
    if (outcome == ShareOutcome.copied) say('Link copied — paste it in Messenger or Facebook');
  }

  @override
  Widget build(BuildContext context) {
    final isBill = widget.kind == ShareKind.bill;
    final muted = AppColors.textMuted;
    final row = Row(
      children: [
        Icon(Icons.ios_share_rounded, size: 20, color: AppColors.accent700),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isBill ? 'Share bill' : 'Share match',
                style: AppTextStyles.body(size: 13.5, weight: FontWeight.w800),
              ),
              Text(
                'Send a link to Messenger, Facebook…',
                style: AppTextStyles.body(size: 12, color: muted),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: muted),
      ],
    );
    final key = ValueKey('share-${widget.kind.dbName}');
    if (widget.embedded) {
      return InkWell(
        key: key,
        borderRadius: AppRadius.sm,
        onTap: _share,
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: row),
      );
    }
    return Material(
      color: AppColors.card,
      borderRadius: AppRadius.lg,
      child: InkWell(
        key: key,
        borderRadius: AppRadius.lg,
        onTap: _share,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.text.withValues(alpha: 0.1)),
            borderRadius: AppRadius.lg,
          ),
          child: row,
        ),
      ),
    );
  }
}
