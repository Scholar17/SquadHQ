import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../notifications/presentation/pages/notifications_page.dart'
    show formatNotificationTime;
import '../../domain/entities/expense_comment.dart';
import '../../domain/entities/squad_ledger.dart';
import '../bloc/expense_comments_bloc.dart';
import 'squad_widgets.dart';

/// "COMMENTS · 2" and each thread — a comment with its replies indented
/// under it. Reply puts the composer into reply mode; the author or an
/// admin can delete.
class ExpenseCommentsList extends StatelessWidget {
  const ExpenseCommentsList({
    super.key,
    required this.ledger,
    required this.me,
    required this.onReply,
  });

  final SquadLedger ledger;
  final String me;
  final ValueChanged<ExpenseComment> onReply;

  Future<void> _confirmDelete(BuildContext context, ExpenseComment comment, int replies) async {
    final bloc = context.read<ExpenseCommentsBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.neutral100,
        title: Text('Delete this comment?', style: AppTextStyles.heading(size: 18)),
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
    if (confirmed == true) bloc.add(ExpenseCommentDeleted(comment.id));
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ledger.member(me)?.isAdmin ?? false;
    return BlocBuilder<ExpenseCommentsBloc, ExpenseCommentsState>(
      builder: (context, state) {
        final threads = state.threads;
        Widget tile(ExpenseComment comment, {required int replies, required bool nested}) =>
            _CommentTile(
              comment: comment,
              author: ledger.nameOf(comment.authorId, me: me),
              initial: ledger.member(comment.authorId)?.initial ?? '?',
              nested: nested,
              onReply: () => onReply(comment),
              onDelete: comment.authorId == me || isAdmin
                  ? () => _confirmDelete(context, comment, replies)
                  : null,
            );
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
              Text(
                'No comments yet. Ask about the tip, who had what…',
                style: AppTextStyles.body(size: 13, color: squadMuted),
              ),
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
    required this.author,
    required this.initial,
    required this.nested,
    required this.onReply,
    required this.onDelete,
  });

  final ExpenseComment comment;
  final String author;
  final String initial;
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
          SquadAvatar(initial: initial, size: nested ? 26 : 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
                  decoration: BoxDecoration(
                    color: AppColors.neutral100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.text.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        author,
                        style: AppTextStyles.body(size: 13, weight: FontWeight.w800, height: 1.3),
                      ),
                      Text(comment.body, style: AppTextStyles.body(size: 14, height: 1.4)),
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

/// The comment box pinned under the expense. In reply mode it says who
/// you're answering, with ✕ to go back to a new comment.
class CommentComposer extends StatefulWidget {
  const CommentComposer({
    super.key,
    required this.ledger,
    required this.me,
    required this.replyTo,
    required this.focusNode,
  });

  final SquadLedger ledger;
  final String me;
  final ValueNotifier<ExpenseComment?> replyTo;
  final FocusNode focusNode;

  @override
  State<CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends State<CommentComposer> {
  final _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _send() {
    final replyTo = widget.replyTo.value;
    context.read<ExpenseCommentsBloc>().add(
      ExpenseCommentPosted(_text.text, parentId: replyTo?.parentId ?? replyTo?.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ExpenseCommentsBloc, ExpenseCommentsState>(
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
          color: AppColors.neutral100,
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
                ValueListenableBuilder<ExpenseComment?>(
                  valueListenable: widget.replyTo,
                  builder: (context, replyTo, _) {
                    if (replyTo == null) return const SizedBox.shrink();
                    return Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Replying to ${widget.ledger.nameOf(replyTo.authorId, me: widget.me)}',
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
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide(color: AppColors.text.withValues(alpha: 0.14)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide(color: AppColors.text.withValues(alpha: 0.14)),
                          ),
                        ),
                      ),
                    ),
                    BlocBuilder<ExpenseCommentsBloc, ExpenseCommentsState>(
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
