import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/comment.dart';
import '../../domain/entities/match_topic.dart';
import '../../domain/entities/mention.dart';
import '../bloc/comments_bloc.dart';
import 'comments.dart';

/// A football match's thread at a glance — how many comments and the
/// latest one — on the Match tab (topic match) or a bill card (topic
/// bill). Tapping it opens the whole thread to read and reply.
class MatchCommentsButton extends StatelessWidget {
  const MatchCommentsButton({
    super.key,
    required this.thread,
    required this.teamId,
    required this.userId,
    required this.canModerate,
    required this.subtitle,
    this.embedded = false,
  });

  final MatchThread thread;
  final String teamId;
  final String userId;

  /// Whether the viewer can delete others' comments (a team admin).
  final bool canModerate;

  /// Under the thread page's title, e.g. "vs Red Lions · Sat 3 Oct".
  final String subtitle;

  /// Inside another card (the bill card): a plain row, no card of its own.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      key: ValueKey('comments-${thread.matchId}-${thread.topic.name}'),
      create: (_) =>
          sl<CommentsBloc>(instanceName: CommentsBloc.match, param1: thread, param2: teamId)
            ..add(const CommentsStarted()),
      // This thread lives as long as the Match tab, so a username you just
      // changed wouldn't show in its mentions until something reloaded it.
      child: BlocListener<AuthBloc, AuthState>(
        listenWhen: (previous, current) =>
            _usernameOf(current) != null && _usernameOf(current) != _usernameOf(previous),
        listener: (context, _) => context.read<CommentsBloc>().add(const CommentsRefreshRequested()),
        child: _Summary(
          thread: thread,
          userId: userId,
          canModerate: canModerate,
          subtitle: subtitle,
          embedded: embedded,
        ),
      ),
    );
  }
}

/// The signed-in user's username, through a save in flight or a failed one.
String? _usernameOf(AuthState state) => switch (state) {
  AuthAuthenticated(:final user) => user.username,
  AuthLoading(:final previous) || AuthFailure(:final previous) => _usernameOf(previous),
  _ => null,
};

class _Summary extends StatelessWidget {
  const _Summary({
    required this.thread,
    required this.userId,
    required this.canModerate,
    required this.subtitle,
    required this.embedded,
  });

  final MatchThread thread;
  final String userId;
  final bool canModerate;
  final String subtitle;
  final bool embedded;

  void _open(BuildContext context) {
    final bloc = context.read<CommentsBloc>();
    // Root: above the tabs, like every full-screen page.
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: MatchCommentsPage(
            topic: thread.topic,
            userId: userId,
            canModerate: canModerate,
            subtitle: subtitle,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.textMuted;
    return BlocBuilder<CommentsBloc, CommentsState>(
      builder: (context, state) {
        final count = state.comments.length;
        final latest = state.comments.isEmpty
            ? null
            : state.comments.reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);
        final title = count == 0
            ? (thread.topic == MatchTopic.bill ? 'Comment on this bill' : 'Match chat')
            : '$count ${count == 1 ? 'comment' : 'comments'}';
        final row = Row(
          children: [
            Icon(Icons.chat_bubble_outline_rounded, size: 20, color: AppColors.accent700),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.body(size: 13.5, weight: FontWeight.w800)),
                  if (latest != null)
                    Text(
                      '${profileAuthorOf(latest, me: userId).name}: '
                      '${plainMentions(latest.body, state.members)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body(size: 12, color: muted),
                    )
                  else if (state.loaded)
                    Text(
                      thread.topic == MatchTopic.bill
                          ? 'Questions about the bill go here'
                          : 'Talk about the match with the team',
                      style: AppTextStyles.body(size: 12, color: muted),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: muted),
          ],
        );
        if (embedded) {
          return InkWell(
            key: ValueKey('open-comments-${thread.topic.name}'),
            borderRadius: AppRadius.sm,
            onTap: () => _open(context),
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: row),
          );
        }
        return Material(
          color: AppColors.card,
          borderRadius: AppRadius.lg,
          child: InkWell(
            key: ValueKey('open-comments-${thread.topic.name}'),
            borderRadius: AppRadius.lg,
            onTap: () => _open(context),
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
      },
    );
  }
}

/// A match's or a bill's whole thread, with the comment box pinned at the
/// bottom. Reads the [CommentsBloc] its [MatchCommentsButton] provides.
class MatchCommentsPage extends StatefulWidget {
  const MatchCommentsPage({
    super.key,
    required this.topic,
    required this.userId,
    required this.canModerate,
    required this.subtitle,
  });

  final MatchTopic topic;
  final String userId;
  final bool canModerate;
  final String subtitle;

  @override
  State<MatchCommentsPage> createState() => _MatchCommentsPageState();
}

class _MatchCommentsPageState extends State<MatchCommentsPage> {
  /// The comment being replied to, or null for a new comment.
  final _replyTo = ValueNotifier<Comment?>(null);
  final _composerFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Teammates' renames don't stream live: catch up on opening, so their
    // mentions show their current usernames.
    context.read<CommentsBloc>().add(const CommentsRefreshRequested());
  }

  @override
  void dispose() {
    _replyTo.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  CommentAuthor _authorOf(Comment comment) => profileAuthorOf(comment, me: widget.userId);

  void _reply(Comment comment) {
    _replyTo.value = comment;
    _composerFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final isBill = widget.topic == MatchTopic.bill;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isBill ? 'Bill comments' : 'Match chat', style: AppTextStyles.title(size: 16)),
            Text(widget.subtitle, style: AppTextStyles.body(size: 12, color: AppColors.textMuted)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          CommentsList(
            authorOf: _authorOf,
            me: widget.userId,
            canModerate: widget.canModerate,
            onReply: _reply,
            emptyText: isBill
                ? 'No comments yet. Ask what the bill covers, or flag a mistake…'
                : 'No comments yet. Sort out lifts, bibs, the ball…',
          ),
        ],
      ),
      bottomNavigationBar: CommentComposer(
        me: widget.userId,
        authorOf: _authorOf,
        replyTo: _replyTo,
        focusNode: _composerFocus,
      ),
    );
  }
}
