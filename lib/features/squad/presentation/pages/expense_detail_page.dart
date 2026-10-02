import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../match/presentation/match_formatting.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_comment.dart';
import '../../domain/entities/squad_ledger.dart';
import '../active_group.dart';
import '../bloc/expense_comments_bloc.dart';
import '../bloc/squad_ledger_bloc.dart';
import '../squad_formatting.dart';
import '../widgets/expense_comments.dart';
import '../widgets/expense_sheet.dart';
import '../widgets/squad_widgets.dart';

/// One expense: its total and payer, each person's share, the note, and
/// a live comment thread with replies. Whoever added it, the payer and
/// admins can edit or delete it. Reached by `/expense/<id>`; reads the
/// expense live from [SquadLedgerBloc], and closes itself if it's deleted.
class ExpenseDetailPage extends StatefulWidget {
  const ExpenseDetailPage({super.key, required this.expenseId, required this.user});

  final String expenseId;
  final AppUser user;

  @override
  State<ExpenseDetailPage> createState() => _ExpenseDetailPageState();
}

class _ExpenseDetailPageState extends State<ExpenseDetailPage> {
  /// The comment being replied to, or null for a new comment.
  final _replyTo = ValueNotifier<ExpenseComment?>(null);
  final _composerFocus = FocusNode();

  String get expenseId => widget.expenseId;
  AppUser get user => widget.user;

  @override
  void dispose() {
    _replyTo.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  void _reply(ExpenseComment comment) {
    _replyTo.value = comment;
    _composerFocus.requestFocus();
  }

  Future<void> _confirmDelete(BuildContext context, Expense expense) async {
    final bloc = context.read<SquadLedgerBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.neutral100,
        title: Text('Delete "${expense.title}"?', style: AppTextStyles.heading(size: 18)),
        content: Text(
          'Everyone’s balance changes back as if it never happened.',
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
    if (confirmed == true) bloc.add(ExpenseDeleteRequested(expense.id));
  }

  @override
  Widget build(BuildContext context) {
    final squad = watchActiveGroup(context);
    final me = user.id;
    return BlocConsumer<SquadLedgerBloc, SquadLedgerState>(
      listenWhen: (previous, current) =>
          current is SquadLedgerFailure ||
          (current is SquadLedgerLoaded && current.ledger.expense(expenseId) == null),
      listener: (context, state) {
        if (state case SquadLedgerFailure(:final message)) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
          return;
        }
        Navigator.of(context).maybePop();
      },
      builder: (context, state) {
        final ledger = state.ledger;
        final expense = ledger?.expense(expenseId);
        final isAdmin = ledger?.member(me)?.isAdmin ?? false;
        final canEdit = expense != null && squad != null && expense.canEdit(me, isAdmin: isAdmin);
        final scaffold = Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            backgroundColor: AppColors.bg,
            elevation: 0,
            foregroundColor: AppColors.text,
            actions: [
              if (canEdit) ...[
                IconButton(
                  tooltip: 'Edit expense',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () =>
                      showExpenseSheet(context, teamId: squad.id, me: me, editing: expense),
                ),
                IconButton(
                  tooltip: 'Delete expense',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: state is SquadLedgerSubmitting
                      ? null
                      : () => _confirmDelete(context, expense),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
          body: ledger == null || expense == null
              ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
              : _Body(
                  expense: expense,
                  ledger: ledger,
                  me: me,
                  comments: ExpenseCommentsList(ledger: ledger, me: me, onReply: _reply),
                ),
          bottomNavigationBar: ledger == null || expense == null
              ? null
              : CommentComposer(
                  ledger: ledger,
                  me: me,
                  replyTo: _replyTo,
                  focusNode: _composerFocus,
                ),
        );
        if (squad == null) return scaffold;
        return BlocProvider(
          key: ValueKey(squad.id),
          create: (_) =>
              sl<ExpenseCommentsBloc>(param1: expenseId, param2: squad.id)
                ..add(const ExpenseCommentsStarted()),
          child: scaffold,
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.expense,
    required this.ledger,
    required this.me,
    required this.comments,
  });

  final Expense expense;
  final SquadLedger ledger;
  final String me;
  final Widget comments;

  @override
  Widget build(BuildContext context) {
    final currency = ledger.currency;
    final shares = expense.shares.entries.toList()
      ..sort((a, b) {
        // The payer first, then the biggest shares.
        if (a.key == expense.payerId) return -1;
        if (b.key == expense.payerId) return 1;
        return b.value.compareTo(a.value);
      });
    final equalCount = expense.shares.length;
    final exact = equalCount == 0 ? 0 : (expense.amountCents / equalCount).round();
    final heading = switch (expense.splitMode) {
      ExpenseSplitMode.equal || ExpenseSplitMode.chosen =>
        'SPLIT EQUALLY · $equalCount ${equalCount == 1 ? 'PERSON' : 'PEOPLE'}',
      ExpenseSplitMode.exact => 'SPLIT BY AMOUNT',
      ExpenseSplitMode.treat => 'TREAT',
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(categoryIcon(expense.category), color: oweColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(expense.title, style: AppTextStyles.heading(size: 22, height: 1.2)),
                  Text(
                    [
                      expense.category.label,
                      '${formatShortDate(expense.spentAt)}, ${formatMatchTime(expense.spentAt)}',
                      if (expense.place case final place?) place,
                    ].join(' · '),
                    style: AppTextStyles.body(size: 12.5, color: squadMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        DarkHeroCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TOTAL', style: AppTextStyles.label(color: AppColors.teamGold)),
                    Text(
                      formatMoney(expense.amountCents, currency),
                      style: AppTextStyles.heading(size: 34, color: AppColors.teamGold),
                    ),
                  ],
                ),
              ),
              Text(
                'Paid by ${ledger.nameOf(expense.payerId, me: me)}',
                style: AppTextStyles.body(
                  size: 13,
                  weight: FontWeight.w600,
                  color: AppColors.neutral100.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SquadSectionLabel(heading),
        const SizedBox(height: 8),
        if (expense.splitMode == ExpenseSplitMode.treat)
          Text(
            "${ledger.nameOf(expense.payerId, me: me)}'s treat — nobody owes anything for it.",
            style: AppTextStyles.body(size: 14, color: owedColor, weight: FontWeight.w600),
          )
        else
          for (final MapEntry(key: profileId, value: cents) in shares) ...[
            SquadCard(
              child: Row(
                children: [
                  SquadAvatar(
                    initial: ledger.member(profileId)?.initial ?? '?',
                    size: 34,
                    color: profileId == expense.payerId ? AppColors.teamGold : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      ledger.nameOf(profileId, me: me),
                      style: AppTextStyles.body(size: 14.5, weight: FontWeight.w700),
                    ),
                  ),
                  // Settling is per person, not per expense, so only the
                  // payer gets a tag here.
                  if (profileId == expense.payerId) ...[
                    _Tag('Paid it', fg: AppColors.accent2_900, bg: AppColors.accent2_100),
                    const SizedBox(width: 10),
                  ],
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatMoney(cents, currency),
                        style: AppTextStyles.body(size: 15, weight: FontWeight.w800, height: 1.3),
                      ),
                      if (expense.splitMode != ExpenseSplitMode.exact && cents != exact)
                        Text(
                          profileId == expense.payerId
                              ? 'covers the rest'
                              : 'exact ${formatMoneyExact(exact, currency)}',
                          style: AppTextStyles.body(size: 10.5, color: squadMuted, height: 1.3),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        if (expense.note case final note?) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NOTE', style: AppTextStyles.label(color: squadMuted)),
                const SizedBox(height: 4),
                Text(note, style: AppTextStyles.body(size: 14)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),
        comments,
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {required this.fg, required this.bg});

  final String text;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        text,
        style: AppTextStyles.body(size: 11.5, weight: FontWeight.w800, color: fg, height: 1.3),
      ),
    );
  }
}
