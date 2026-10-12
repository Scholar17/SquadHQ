import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../notifications/presentation/pages/notifications_page.dart'
    show formatNotificationTime;
import '../../../squad/presentation/widgets/squad_widgets.dart';
import '../../domain/entities/comment.dart';
import '../../domain/entities/mention.dart';
import '../bloc/comments_bloc.dart';

/// How a comment's author shows: their name ("You" for yourself), the
/// initial on their avatar, and their photo if they have one.
typedef CommentAuthor = ({String name, String initial, String? photoUrl});

/// Looks up [comment]'s author.
typedef CommentAuthorOf = CommentAuthor Function(Comment comment);

/// From the author's profile joined onto [comment] — for screens without a
/// member list to look them up in.
CommentAuthor profileAuthorOf(Comment comment, {required String me}) {
  final name = comment.authorName?.trim();
  final shown = name == null || name.isEmpty ? 'Member' : name;
  return (
    name: comment.authorId == me ? 'You' : shown,
    initial: shown.characters.first.toUpperCase(),
    photoUrl: comment.authorPhotoUrl,
  );
}

/// "COMMENTS · 2" and each thread — a comment with its replies indented
/// under it. Reply puts the composer into reply mode; the author or an
/// admin ([canModerate]) can delete.
class CommentsList extends StatelessWidget {
  const CommentsList({
    super.key,
    required this.authorOf,
    required this.me,
    required this.canModerate,
    required this.onReply,
    required this.emptyText,
  });

  final CommentAuthorOf authorOf;
  final String me;
  final bool canModerate;
  final ValueChanged<Comment> onReply;

  /// Shown until the first comment, e.g. "Ask about the tip…".
  final String emptyText;

  Future<void> _confirmDelete(BuildContext context, Comment comment, int replies) async {
    final bloc = context.read<CommentsBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Delete this comment?', style: AppTextStyles.title(size: 18)),
        content: replies == 0
            ? null
            : Text(
                'Its $replies ${replies == 1 ? 'reply goes' : 'replies go'} with it.',
                style: AppTextStyles.body(size: 14, color: squadMuted),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Delete',
              style: AppTextStyles.body(weight: FontWeight.w700, color: oweColor),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) bloc.add(CommentDeleted(comment.id));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CommentsBloc, CommentsState>(
      builder: (context, state) {
        final threads = state.threads;
        Widget tile(Comment comment, {required int replies, required bool nested}) {
          final author = authorOf(comment);
          return _CommentTile(
            comment: comment,
            members: state.members,
            me: me,
            author: author.name,
            initial: author.initial,
            photoUrl: author.photoUrl,
            nested: nested,
            onReply: () => onReply(comment),
            onDelete: comment.authorId == me || canModerate
                ? () => _confirmDelete(context, comment, replies)
                : null,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SquadSectionLabel(
              state.comments.isEmpty ? 'COMMENTS' : 'COMMENTS · ${state.comments.length}',
            ),
            const SizedBox(height: 8),
            if (!state.loaded)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.accent),
                  ),
                ),
              )
            else if (threads.isEmpty)
              Text(emptyText, style: AppTextStyles.body(size: 13, color: squadMuted)),
            for (final thread in threads) ...[
              tile(thread.comment, replies: thread.replies.length, nested: false),
              for (final reply in thread.replies) tile(reply, replies: 0, nested: true),
            ],
          ],
        );
      },
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.members,
    required this.me,
    required this.author,
    required this.initial,
    this.photoUrl,
    required this.nested,
    required this.onReply,
    required this.onDelete,
  });

  final Comment comment;
  final List<MentionMember> members;
  final String me;
  final String author;
  final String initial;
  final String? photoUrl;
  final bool nested;
  final VoidCallback onReply;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final action = AppTextStyles.body(size: 12, weight: FontWeight.w700, color: squadMuted);
    return Padding(
      padding: EdgeInsets.only(left: nested ? 42 : 0, top: 6, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SquadAvatar(initial: initial, size: nested ? 26 : 32, photoUrl: photoUrl),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: AppRadius.md,
                    border: Border.all(color: AppColors.text.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        author,
                        style: AppTextStyles.body(size: 13, weight: FontWeight.w800, height: 1.3),
                      ),
                      Text.rich(
                        TextSpan(
                          children: [
                            for (final part in mentionParts(comment.body, members))
                              TextSpan(
                                text: part.text,
                                style: part.memberId == null
                                    ? null
                                    : TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: oweColor,
                                        // You: tinted, so it stands out.
                                        backgroundColor: part.memberId == me
                                            ? oweColor.withValues(alpha: 0.12)
                                            : null,
                                      ),
                              ),
                          ],
                        ),
                        style: AppTextStyles.body(size: 14, height: 1.4),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const SizedBox(width: 12),
                    Text(
                      formatNotificationTime(comment.createdAt),
                      style: AppTextStyles.body(size: 11.5, color: squadMuted),
                    ),
                    TextButton(
                      onPressed: onReply,
                      style: TextButton.styleFrom(minimumSize: const Size(44, 36)),
                      child: Text('Reply', style: action),
                    ),
                    if (onDelete != null)
                      TextButton(
                        onPressed: onDelete,
                        style: TextButton.styleFrom(minimumSize: const Size(44, 36)),
                        child: Text('Delete', style: action),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The comment box pinned under the thread. In reply mode it says who
/// you're answering, with ✕ to go back to a new comment. Typing @ lists
/// teammates to mention.
class CommentComposer extends StatefulWidget {
  const CommentComposer({
    super.key,
    required this.me,
    required this.authorOf,
    required this.replyTo,
    required this.focusNode,
  });

  /// Your profile id — left out of the @ suggestions.
  final String me;
  final CommentAuthorOf authorOf;
  final ValueNotifier<Comment?> replyTo;
  final FocusNode focusNode;

  @override
  State<CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends State<CommentComposer> {
  final _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    _text.addListener(_refresh);
    // The @ suggestions show only while you're typing.
    widget.focusNode.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    widget.focusNode.removeListener(_refresh);
    _text.dispose();
    super.dispose();
  }

  /// Swaps the '@partial' before the cursor for [member]'s '@username '.
  void _mention(MentionMember member, int start) {
    final cursor = _text.selection.baseOffset;
    final inserted = '@${member.username} ';
    _text.value = TextEditingValue(
      text: _text.text.replaceRange(start, cursor, inserted),
      selection: TextSelection.collapsed(offset: start + inserted.length),
    );
    widget.focusNode.requestFocus();
  }

  Widget _suggestions(List<MentionMember> members) {
    final query = mentionQueryAt(_text.text, _text.selection.baseOffset);
    if (query == null || !widget.focusNode.hasFocus) return const SizedBox.shrink();
    final matches = mentionSuggestions(members, query.query, me: widget.me).toList();
    if (matches.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const ValueKey('mention-suggestions'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // The whole group, scrolling past about five rows — half a row
        // peeks out, so it's clear there are more.
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: [
              for (final member in matches)
                InkWell(
                  key: ValueKey('mention-${member.id}'),
                  borderRadius: AppRadius.sm,
                  onTap: () => _mention(member, query.start),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        SquadAvatar(
                          initial: member.name.isEmpty
                              ? '?'
                              : member.name.characters.first.toUpperCase(),
                          size: 28,
                          photoUrl: member.photoUrl,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            member.name,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.body(size: 14, weight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '@${member.username}',
                          style: AppTextStyles.body(size: 13, color: squadMuted),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Divider(height: 8, color: AppColors.text.withValues(alpha: 0.08)),
      ],
    );
  }

  void _send() {
    final replyTo = widget.replyTo.value;
    context.read<CommentsBloc>().add(
      CommentPosted(_text.text, parentId: replyTo?.parentId ?? replyTo?.id),
    );
    // Sent: put the keyboard away (the text stays if it fails to post).
    widget.focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CommentsBloc, CommentsState>(
      listenWhen: (previous, current) =>
          current.postedCount != previous.postedCount ||
          (current.error != null && current.error != previous.error),
      listener: (context, state) {
        if (state.error case final error?) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(error)));
          return;
        }
        _text.clear();
        widget.replyTo.value = null;
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border(top: BorderSide(color: AppColors.text.withValues(alpha: 0.08))),
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ValueListenableBuilder<Comment?>(
                  valueListenable: widget.replyTo,
                  builder: (context, replyTo, _) {
                    if (replyTo == null) return const SizedBox.shrink();
                    return Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Replying to ${widget.authorOf(replyTo).name}',
                            style: AppTextStyles.body(
                              size: 12,
                              weight: FontWeight.w700,
                              color: oweColor,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cancel reply',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => widget.replyTo.value = null,
                        ),
                      ],
                    );
                  },
                ),
                BlocBuilder<CommentsBloc, CommentsState>(
                  buildWhen: (previous, current) => previous.members != current.members,
                  builder: (context, state) => _suggestions(state.members),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('comment-field'),
                        controller: _text,
                        focusNode: widget.focusNode,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 1000,
                        textCapitalization: TextCapitalization.sentences,
                        style: AppTextStyles.body(size: 14),
                        decoration: InputDecoration(
                          hintText: 'Add a comment',
                          counterText: '',
                          isDense: true,
                          filled: true,
                          fillColor: AppColors.bg,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          border: OutlineInputBorder(
                            borderRadius: AppRadius.lg,
                            borderSide: BorderSide(color: AppColors.text.withValues(alpha: 0.14)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: AppRadius.lg,
                            borderSide: BorderSide(color: AppColors.text.withValues(alpha: 0.14)),
                          ),
                        ),
                      ),
                    ),
                    BlocBuilder<CommentsBloc, CommentsState>(
                      buildWhen: (previous, current) => previous.posting != current.posting,
                      builder: (context, state) => TextButton(
                        onPressed: state.posting || _text.text.trim().isEmpty ? null : _send,
                        style: TextButton.styleFrom(minimumSize: const Size(56, 44)),
                        child: Text(
                          'Send',
                          style: AppTextStyles.body(
                            size: 14,
                            weight: FontWeight.w800,
                            color: state.posting || _text.text.trim().isEmpty
                                ? AppColors.neutral500
                                : oweColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
