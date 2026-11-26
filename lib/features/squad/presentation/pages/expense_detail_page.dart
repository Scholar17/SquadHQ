import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../comments/domain/entities/comment.dart';
import '../../../comments/presentation/bloc/comments_bloc.dart';
import '../../../comments/presentation/widgets/comments.dart';
import '../../../match/presentation/match_formatting.dart';
import '../../../wallet/domain/repositories/wallet_repository.dart' show WalletImageKind;
import '../../../wallet/presentation/widgets/wallet_image.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/squad_ledger.dart';
import '../active_group.dart';
import '../bloc/squad_ledger_bloc.dart';
import '../squad_formatting.dart';
import '../widgets/expense_sheet.dart';
import '../widgets/pay_sheet.dart';
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
  final _replyTo = ValueNotifier<Comment?>(null);
  final _composerFocus = FocusNode();

  String get expenseId => widget.expenseId;
  AppUser get user => widget.user;

  @override
  void dispose() {
    _replyTo.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  void _reply(Comment comment) {
    _replyTo.value = comment;
    _composerFocus.requestFocus();
  }

  Future<void> _confirmDelete(BuildContext context, Expense expense) async {
    final bloc = context.read<SquadLedgerBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Delete "${expense.title}"?', style: AppTextStyles.title(size: 18)),
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
        // A closed trip's expenses are locked until an admin reopens it.
        final tripClosed = switch (expense?.tripId) {
          final id? => ledger?.trip(id)?.isClosed ?? false,
          null => false,
        };
        final canEdit =
            expense != null &&
            squad != null &&
            !tripClosed &&
            expense.canEdit(me, isAdmin: isAdmin);
        CommentAuthor authorOf(Comment comment) => (
          name: ledger?.nameOf(comment.authorId, me: me) ?? '',
          initial: ledger?.member(comment.authorId)?.initial ?? '?',
          photoUrl: ledger?.member(comment.authorId)?.avatarUrl,
        );
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
                  // A trip expense counts in its trip's numbers only.
                  ledger: ledger.scopeOf(expense),
                  me: me,
                  teamId: squad?.id,
                  comments: CommentsList(
                    authorOf: authorOf,
                    me: me,
                    canModerate: isAdmin,
                    onReply: _reply,
                    emptyText: 'No comments yet. Ask about the tip, who had what…',
                  ),
                ),
          bottomNavigationBar: ledger == null || expense == null
              ? null
              : CommentComposer(
                  me: me,
                  authorOf: authorOf,
                  replyTo: _replyTo,
                  focusNode: _composerFocus,
                ),
        );
        if (squad == null) return scaffold;
        return BlocProvider(
          key: ValueKey(squad.id),
          create: (_) =>
              sl<CommentsBloc>(
                instanceName: CommentsBloc.expense,
                param1: expenseId,
                param2: squad.id,
              )..add(const CommentsStarted()),
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
    required this.teamId,
    required this.comments,
  });

  final Expense expense;
  final SquadLedger ledger;
  final String me;
  final String? teamId;
  final Widget comments;

  /// Paying back, on your own row: "Pay" while you owe a payer for it —
  /// with several payers, the next one still to pay — "Pending" once
  /// what's sent covers it, "Paid" once confirmed payments do. Payments
  /// clear the oldest expenses first ([SquadLedger.expenseLeft]), so
  /// paying everything from Settle marks each one paid. The pay sheet
  /// offers this expense's part or all you owe them. Null when it's not
  /// yours to pay.
  ({PayStatus status, VoidCallback? onPay})? _payBack(BuildContext context) {
    final teamId = this.teamId;
    final mine = [
      for (final debt in expense.owed)
        if (debt.fromId == me) debt,
    ]..sort((a, b) => b.cents.compareTo(a.cents));
    // A trip is settled once an admin closes it.
    final trip = switch (expense.tripId) {
      final id? => ledger.trip(id),
      null => null,
    };
    if (teamId == null ||
        expense.splitMode == ExpenseSplitMode.treat ||
        mine.isEmpty ||
        (trip != null && !trip.isClosed)) {
      return null;
    }
    var allPaid = true;
    for (final debt in mine) {
      // Paid once confirmed payments cover it; pending once what you've
      // sent (still waiting) covers it.
      if (ledger.expenseLeft(expense, me, debt.toId) <= 0) continue;
      allPaid = false;
      final toPay = ledger.expenseLeft(expense, me, debt.toId, includePending: true);
      if (toPay > 0) {
        return (
          status: PayStatus.pay,
          onPay: () => showPaySheet(
            context,
            teamId: teamId,
            me: me,
            toId: debt.toId,
            suggestedCents: ledger.owedBetween(me, debt.toId, includePending: true),
            expenseCents: toPay,
            tripId: expense.tripId,
          ),
        );
      }
    }
    return (status: allPaid ? PayStatus.paid : PayStatus.pending, onPay: null);
  }

  @override
  Widget build(BuildContext context) {
    final currency = ledger.currency;
    final payBack = _payBack(context);
    // Members' own shares; guests they cover are listed on their own.
    final shares =
        [
          for (final id in expense.shares.keys)
            if (expense.ownShareOf(id) > 0 || expense.payers.containsKey(id))
              MapEntry(id, expense.ownShareOf(id)),
        ]..sort((a, b) {
          // Payers first (biggest first), then the biggest shares.
          final paid = expense.paidBy(b.key).compareTo(expense.paidBy(a.key));
          return paid != 0 ? paid : b.value.compareTo(a.value);
        });
    final equalCount = shares.where((e) => e.value > 0).length + expense.guests.length;
    final exact = equalCount == 0 ? 0 : (expense.amountCents / equalCount).round();
    final heading = switch (expense.splitMode) {
      ExpenseSplitMode.equal || ExpenseSplitMode.chosen =>
        'SPLIT EQUALLY · $equalCount ${equalCount == 1 ? 'PERSON' : 'PEOPLE'}',
      ExpenseSplitMode.exact => 'SPLIT BY AMOUNT',
      ExpenseSplitMode.custom =>
        'SPLIT BY AMOUNT · $equalCount ${equalCount == 1 ? 'PERSON' : 'PEOPLE'}',
      ExpenseSplitMode.percent =>
        'SPLIT BY PERCENT · $equalCount ${equalCount == 1 ? 'PERSON' : 'PEOPLE'}',
      ExpenseSplitMode.shares =>
        'SPLIT BY SHARES · $equalCount ${equalCount == 1 ? 'PERSON' : 'PEOPLE'}',
      ExpenseSplitMode.treat => 'TREAT',
      ExpenseSplitMode.borrow => 'BORROWED',
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
                color: categoryTone(expense.category).background,
                borderRadius: AppRadius.md,
              ),
              child: Icon(
                categoryIcon(expense.category),
                color: categoryTone(expense.category).foreground,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(expense.title, style: AppTextStyles.heading(size: 22, height: 1.2)),
                  Text(
                    [
                      expense.categoryName,
                      '${formatShortDate(expense.spentAt)}, ${formatMatchTime(expense.spentAt)}',
                      ?expense.place,
                      if (expense.tripId case final tripId?)
                        if (ledger.trip(tripId) case final trip?) '${trip.name} trip',
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
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formatMoney(expense.amountCents, currency),
                        style: AppTextStyles.heading(size: 34, color: AppColors.teamGold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Long names or several payers wrap rather than overflow.
              Flexible(
                child: Text(
                  'Paid by ${ledger.paidByLabel(expense, me: me)}',
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(
                    size: 13,
                    weight: FontWeight.w600,
                    color: AppColors.onDark.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Several payers: who put in what.
        if (expense.hasSeveralPayers) ...[
          const SizedBox(height: 20),
          SquadSectionLabel('PAID BY · ${expense.payers.length} PEOPLE'),
          const SizedBox(height: 8),
          for (final MapEntry(key: profileId, value: cents)
              in expense.payers.entries.toList()..sort((a, b) => b.value.compareTo(a.value))) ...[
            SquadCard(
              child: Row(
                children: [
                  SquadAvatar(
                    initial: ledger.member(profileId)?.initial ?? '?',
                    photoUrl: ledger.member(profileId)?.avatarUrl,
                    size: 34,
                    color: AppColors.teamGold,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      ledger.nameOf(profileId, me: me),
                      style: AppTextStyles.body(size: 14.5, weight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    formatMoney(cents, currency),
                    style: AppTextStyles.body(size: 15, weight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
        const SizedBox(height: 20),
        SquadSectionLabel(heading),
        const SizedBox(height: 8),
        if (expense.splitMode == ExpenseSplitMode.treat)
          Text(
            "${ledger.paidByLabel(expense, me: me)}'s treat — nobody owes anything for it.",
            style: AppTextStyles.body(size: 14, color: owedColor, weight: FontWeight.w600),
          )
        else
          for (final MapEntry(key: profileId, value: cents) in shares) ...[
            SquadCard(
              child: Row(
                children: [
                  SquadAvatar(
                    initial: ledger.member(profileId)?.initial ?? '?',
                    photoUrl: ledger.member(profileId)?.avatarUrl,
                    size: 34,
                    color: expense.payers.containsKey(profileId) ? AppColors.teamGold : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      ledger.nameOf(profileId, me: me),
                      style: AppTextStyles.body(size: 14.5, weight: FontWeight.w700),
                    ),
                  ),
                  // Settling is per person, not per expense: the payer
                  // gets a tag, and your own row a way to pay them back.
                  if (expense.payers.containsKey(profileId)) ...[
                    _Tag('Paid it', fg: AppColors.accent2_900, bg: AppColors.accent2_100),
                    const SizedBox(width: 10),
                  ] else if (profileId == me && payBack != null) ...[
                    PayStatusButton(status: payBack.status, onPay: payBack.onPay),
                    const SizedBox(width: 10),
                  ],
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatMoney(cents, currency),
                        style: AppTextStyles.body(size: 15, weight: FontWeight.w800, height: 1.3),
                      ),
                      if (expense.splitMode.isWeighted && expense.weights[profileId] != null)
                        Text(
                          weightLabel(expense.splitMode, expense.weights[profileId]!),
                          style: AppTextStyles.body(size: 10.5, color: squadMuted, height: 1.3),
                        ),
                      if (expense.splitMode case ExpenseSplitMode.equal || ExpenseSplitMode.chosen
                          when cents != exact)
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
        // Guests from outside the squad, for information.
        if (expense.splitMode != ExpenseSplitMode.treat)
          for (final guest in expense.guests) ...[
            SquadCard(
              child: Row(
                children: [
                  SquadAvatar(
                    initial: guest.name.isEmpty ? '?' : guest.name[0].toUpperCase(),
                    size: 34,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${guest.name} · guest',
                          style: AppTextStyles.body(size: 14.5, weight: FontWeight.w700),
                        ),
                        Text(
                          guest.hostId == null
                              ? 'Pays ${ledger.nameOf(expense.payerId, me: me)} directly'
                              : 'Covered by ${ledger.nameOf(guest.hostId!, me: me)}',
                          style: AppTextStyles.body(size: 12, color: squadMuted),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatMoney(guest.amountCents, currency),
                    style: AppTextStyles.body(size: 15, weight: FontWeight.w800, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        // Proof of payment: anyone in the squad can open it.
        if (expense.receiptPath case final receipt?) ...[
          const SizedBox(height: 12),
          SquadCard(
            onTap: () => showWalletImageViewer(
              context,
              kind: WalletImageKind.paymentSlip,
              path: receipt,
              title: 'Proof of payment · ${expense.title}',
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: AppRadius.sm,
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: WalletImage(kind: WalletImageKind.paymentSlip, path: receipt),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PROOF OF PAYMENT', style: AppTextStyles.label(color: squadMuted)),
                      const SizedBox(height: 2),
                      Text(
                        'Receipt or slip · tap to view',
                        style: AppTextStyles.body(size: 13.5, weight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 20, color: squadMuted),
              ],
            ),
          ),
        ],
        if (expense.note case final note?) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.md,
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
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.pill),
      child: Text(
        text,
        style: AppTextStyles.body(size: 11.5, weight: FontWeight.w800, color: fg, height: 1.3),
      ),
    );
  }
}
