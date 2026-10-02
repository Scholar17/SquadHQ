import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_split.dart';
import '../../domain/entities/squad_ledger.dart';
import '../../domain/entities/squad_member.dart';
import '../../domain/repositories/squad_repository.dart';
import '../bloc/squad_ledger_bloc.dart';
import '../squad_formatting.dart';
import 'squad_widgets.dart';

/// Add an expense, or edit [editing]: amount first, then title, who paid,
/// category and how it's split, with each person's share previewed live.
Future<void> showExpenseSheet(
  BuildContext context, {
  required String teamId,
  required String me,
  Expense? editing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.neutral100,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _ExpenseSheet(teamId: teamId, me: me, editing: editing),
  );
}

class _ExpenseSheet extends StatefulWidget {
  const _ExpenseSheet({required this.teamId, required this.me, this.editing});

  final String teamId;
  final String me;
  final Expense? editing;

  @override
  State<_ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends State<_ExpenseSheet> {
  late final _amount = TextEditingController(
    text: widget.editing == null ? '' : moneyInput(widget.editing!.amountCents),
  );
  late final _title = TextEditingController(text: widget.editing?.title ?? '');
  late final _note = TextEditingController(text: widget.editing?.note ?? '');
  final _exact = <String, TextEditingController>{};

  late String _payerId = widget.editing?.payerId ?? widget.me;
  late ExpenseCategory _category = widget.editing?.category ?? ExpenseCategory.food;
  late ExpenseSplitMode _mode = widget.editing?.splitMode ?? ExpenseSplitMode.equal;

  /// Ticked people for a chosen split; null = everyone (not yet touched).
  Set<String>? _chosen;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    if (editing != null) {
      if (editing.splitMode == ExpenseSplitMode.chosen) _chosen = editing.shares.keys.toSet();
      if (editing.splitMode == ExpenseSplitMode.exact) {
        for (final MapEntry(:key, :value) in editing.shares.entries) {
          _exactFor(key).text = moneyInput(value);
        }
      }
    }
    _amount.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  TextEditingController _exactFor(String profileId) => _exact.putIfAbsent(profileId, () {
    final controller = TextEditingController();
    controller.addListener(_rebuild);
    return controller;
  });

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    _note.dispose();
    for (final controller in _exact.values) {
      controller.dispose();
    }
    super.dispose();
  }

  ExpenseSplit _split(List<SquadMember> members) {
    final everyone = [for (final member in members) member.profileId];
    final chosen = _chosen ?? everyone.toSet();
    return ExpenseSplit.compute(
      mode: _mode,
      totalCents: parseMoney(_amount.text) ?? 0,
      payerId: _payerId,
      participants: switch (_mode) {
        ExpenseSplitMode.chosen => [
          for (final id in everyone)
            if (chosen.contains(id)) id,
        ],
        _ => everyone,
      },
      exactCents: {for (final id in everyone) id: ?parseMoney(_exactFor(id).text)},
    );
  }

  void _save(SquadLedger ledger) {
    final amount = parseMoney(_amount.text) ?? 0;
    final split = _split(ledger.members);
    if (amount <= 0 || !split.isValid) {
      _snack(amount <= 0 ? 'Enter an amount' : split.error!);
      return;
    }
    final title = _title.text.trim();
    context.read<SquadLedgerBloc>().add(
      ExpenseSaveRequested(
        ExpenseDraft(
          id: widget.editing?.id,
          teamId: widget.teamId,
          title: title.isEmpty ? _category.label : title,
          category: _category,
          amountCents: amount,
          splitMode: _mode,
          payerId: _payerId,
          shares: split.shares,
          spentAt: widget.editing?.spentAt,
          note: _note.text.trim(),
          place: widget.editing?.place,
        ),
      ),
    );
  }

  void _snack(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _pickPayer(SquadLedger ledger) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.neutral100,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text('Who paid?', style: AppTextStyles.heading(size: 18)),
            ),
            for (final member in ledger.members)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: SquadAvatar(initial: member.initial, size: 36),
                title: Text(
                  ledger.nameOf(member.profileId, me: widget.me),
                  style: AppTextStyles.body(size: 15, weight: FontWeight.w600),
                ),
                trailing: member.profileId == _payerId
                    ? const Icon(Icons.check_rounded, color: AppColors.accent700)
                    : null,
                onTap: () => Navigator.of(context).pop(member.profileId),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _payerId = picked);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SquadLedgerBloc, SquadLedgerState>(
      listenWhen: (previous, current) =>
          current is SquadLedgerFailure ||
          (previous is SquadLedgerSubmitting && current is SquadLedgerLoaded),
      listener: (context, state) {
        if (state case SquadLedgerFailure(:final message)) {
          _snack(message);
        } else {
          Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        final ledger = state.ledger ?? SquadLedger.empty;
        final currency = ledger.currency;
        final split = _split(ledger.members);
        final amount = parseMoney(_amount.text) ?? 0;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.neutral400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.editing == null ? 'Add expense' : 'Edit expense',
                      style: AppTextStyles.heading(size: 20),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                  ),
                ],
              ),
              // The amount comes first, big.
              Container(
                padding: const EdgeInsets.only(bottom: 6),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.text, width: 2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      currency.symbol,
                      style: AppTextStyles.heading(size: 28, color: squadMuted),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Semantics(
                        label: 'Amount',
                        child: TextField(
                          key: const ValueKey('expense-amount'),
                          controller: _amount,
                          autofocus: widget.editing == null,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                          style: AppTextStyles.heading(size: 40),
                          decoration: const InputDecoration(
                            hintText: '0',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Labeled(
                      label: 'TITLE',
                      child: _Field(controller: _title, hint: _category.label),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Labeled(
                      label: 'PAID BY',
                      child: _PayerButton(
                        name: ledger.nameOf(_payerId, me: widget.me),
                        initial: ledger.member(_payerId)?.initial ?? '?',
                        onTap: () => _pickPayer(ledger),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: ExpenseCategory.values.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final category = ExpenseCategory.values[index];
                    return SquadChoiceChip(
                      label: category.label,
                      icon: categoryIcon(category),
                      selected: category == _category,
                      onTap: () => setState(() => _category = category),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Text('SPLIT', style: AppTextStyles.label(color: squadMuted)),
              const SizedBox(height: 6),
              _ModeTabs(mode: _mode, onChanged: (mode) => setState(() => _mode = mode)),
              const SizedBox(height: 8),
              if (_mode == ExpenseSplitMode.treat)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accent2_100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${ledger.nameOf(_payerId, me: widget.me)}'s treat",
                        style: AppTextStyles.heading(size: 16, color: AppColors.accent2_900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Saved to the history. Nobody owes anything for it.',
                        style: AppTextStyles.body(size: 13, color: owedColor),
                      ),
                    ],
                  ),
                )
              else
                for (final member in ledger.members)
                  _ShareRow(
                    name:
                        ledger.nameOf(member.profileId, me: widget.me) +
                        (member.profileId == _payerId ? ' (paid)' : ''),
                    initial: member.initial,
                    mode: _mode,
                    included: switch (_mode) {
                      ExpenseSplitMode.chosen =>
                        (_chosen ?? {for (final m in ledger.members) m.profileId}).contains(
                          member.profileId,
                        ),
                      ExpenseSplitMode.exact => split.shares.containsKey(member.profileId),
                      _ => true,
                    },
                    onToggle: _mode == ExpenseSplitMode.chosen
                        ? () => setState(() {
                            final chosen = _chosen ??= {
                              for (final m in ledger.members) m.profileId,
                            };
                            if (!chosen.remove(member.profileId)) chosen.add(member.profileId);
                          })
                        : null,
                    exactController: _mode == ExpenseSplitMode.exact
                        ? _exactFor(member.profileId)
                        : null,
                    amount: split.shares[member.profileId] == null
                        ? '—'
                        : formatMoney(split.shares[member.profileId]!, currency),
                    sub: switch (split.shares[member.profileId]) {
                      null => 'not in it',
                      _ when member.profileId == _payerId && split.roundedCents != null =>
                        'covers the rest',
                      _
                          when split.exactCents != null &&
                              split.exactCents != split.shares[member.profileId] =>
                        'exact ${formatMoneyExact(split.exactCents!, currency)}',
                      _ => '',
                    },
                  ),
              const SizedBox(height: 6),
              Text(
                _footnote(split, amount, ledger),
                style: AppTextStyles.body(
                  size: 12,
                  color: split.isValid || amount == 0 ? squadMuted : AppColors.accent700,
                ),
              ),
              const SizedBox(height: 10),
              _Field(controller: _note, hint: 'Note (optional)'),
              const SizedBox(height: 16),
              SquadPrimaryButton(
                label: widget.editing == null ? 'Save expense' : 'Save changes',
                isLoading: state is SquadLedgerSubmitting,
                onPressed: () => _save(ledger),
              ),
            ],
          ),
        );
      },
    );
  }

  String _footnote(ExpenseSplit split, int amount, SquadLedger ledger) {
    if (amount == 0) return 'Enter the amount first.';
    final total = formatMoney(amount, ledger.currency);
    return switch (_mode) {
      ExpenseSplitMode.treat => 'Treats still show in the squad’s spending.',
      ExpenseSplitMode.exact =>
        split.isValid
            ? 'Shares add up to $total.'
            : 'Shares must add up to $total · '
                  '${formatMoney(split.shares.values.fold(0, (a, b) => a + b), ledger.currency)} entered.',
      _ when !split.isValid => split.error!,
      _ when split.roundedCents != null =>
        '$total ÷ ${split.shares.length} = ${formatMoneyExact(split.exactCents!, ledger.currency)}. '
            'Everyone pays the whole amount; '
            '${ledger.nameOf(_payerId, me: widget.me)} covers the rest.',
      _ =>
        '$total ÷ ${split.shares.length}, to the last ${ledger.currency.symbol == '฿' ? 'satang' : 'pya'}.',
    };
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label(color: squadMuted)),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.sentences,
      style: AppTextStyles.body(size: 14, weight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: AppColors.bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.text.withValues(alpha: 0.18)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.text.withValues(alpha: 0.18)),
        ),
      ),
    );
  }
}

class _PayerButton extends StatelessWidget {
  const _PayerButton({required this.name, required this.initial, required this.onTap});

  final String name;
  final String initial;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.text.withValues(alpha: 0.18)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          height: 46,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                SquadAvatar(initial: initial, size: 26, color: AppColors.teamGold),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(size: 14, weight: FontWeight.w600),
                  ),
                ),
                const Icon(Icons.expand_more_rounded, size: 18, color: squadMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Equal · Chosen · Exact · Treat, as a segmented control.
class _ModeTabs extends StatelessWidget {
  const _ModeTabs({required this.mode, required this.onChanged});

  final ExpenseSplitMode mode;
  final ValueChanged<ExpenseSplitMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22)),
      child: Row(
        children: [
          for (final option in ExpenseSplitMode.values)
            Expanded(
              child: Semantics(
                selected: option == mode,
                button: true,
                child: Material(
                  color: option == mode ? AppColors.neutral100 : Colors.transparent,
                  shape: const StadiumBorder(),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => onChanged(option),
                    child: SizedBox(
                      height: 36,
                      child: Center(
                        child: Text(
                          option.label,
                          style: AppTextStyles.body(
                            size: 13,
                            weight: FontWeight.w700,
                            color: option == mode ? AppColors.text : squadMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ShareRow extends StatelessWidget {
  const _ShareRow({
    required this.name,
    required this.initial,
    required this.mode,
    required this.included,
    required this.onToggle,
    required this.exactController,
    required this.amount,
    required this.sub,
  });

  final String name;
  final String initial;
  final ExpenseSplitMode mode;
  final bool included;
  final VoidCallback? onToggle;
  final TextEditingController? exactController;
  final String amount;
  final String sub;

  @override
  Widget build(BuildContext context) {
    final nameColor = included ? AppColors.text : AppColors.neutral600;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          if (mode == ExpenseSplitMode.chosen)
            Checkbox(
              value: included,
              onChanged: (_) => onToggle?.call(),
              activeColor: AppColors.accent700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              semanticLabel: 'Include $name',
            ),
          SquadAvatar(initial: initial, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: AppTextStyles.body(size: 14, weight: FontWeight.w600, color: nameColor),
            ),
          ),
          if (exactController != null)
            SizedBox(
              width: 96,
              child: Semantics(
                label: '$name share',
                child: TextField(
                  controller: exactController,
                  textAlign: TextAlign.right,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  style: AppTextStyles.body(size: 14, weight: FontWeight.w800),
                  decoration: InputDecoration(
                    hintText: '0',
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.bg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppColors.text.withValues(alpha: 0.18)),
                    ),
                  ),
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(amount, style: AppTextStyles.heading(size: 17, color: nameColor, height: 1.2)),
                if (sub.isNotEmpty)
                  Text(
                    sub,
                    style: AppTextStyles.body(
                      size: 10.5,
                      weight: FontWeight.w600,
                      color: squadMuted,
                      height: 1.3,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
