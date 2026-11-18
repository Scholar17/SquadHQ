import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/widgets/edge_fade.dart';
import '../../../../core/theme/widgets/money_input_formatter.dart';
import '../../../../core/theme/widgets/sticky_action_sheet.dart';
import '../../../personal/presentation/personal_formatting.dart' show formatDayLabel;
import '../../../squad/domain/entities/expense.dart';
import '../../../squad/domain/entities/expense_split.dart';
import '../../../squad/domain/entities/squad_ledger.dart';
import '../../../squad/domain/entities/squad_member.dart';
import '../../../squad/presentation/bloc/squad_ledger_bloc.dart';
import '../../../squad/presentation/squad_formatting.dart';
import '../../../squad/presentation/widgets/sheet_parts.dart';
import '../../../squad/presentation/widgets/squad_widgets.dart';
import '../../../wallet/presentation/widgets/wallet_image_actions.dart';
import '../../domain/entities/buddy.dart';
import '../../domain/repositories/buddy_repository.dart';
import '../cubit/buddy_cubit.dart';

/// The splits a buddy expense offers.
const buddySplitModes = [
  ExpenseSplitMode.equal,
  ExpenseSplitMode.custom,
  ExpenseSplitMode.percent,
  ExpenseSplitMode.shares,
];

/// "Add buddy expense" with one squad-mate ([buddyId] fixed when opened
/// from your page with them), or edit [editing].
Future<void> showBuddyExpenseSheet(
  BuildContext context, {
  required String teamId,
  required String me,
  String? buddyId,
  BuddyExpense? editing,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: AppColors.card,
  shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
  builder: (_) => BlocProvider.value(
    value: sl<BuddyCubit>(),
    child: BlocProvider.value(
      value: context.read<SquadLedgerBloc>(),
      child: _BuddyExpenseSheet(
        teamId: teamId,
        me: me,
        buddyId: editing?.buddyId ?? buddyId,
        editing: editing,
      ),
    ),
  ),
);

class _BuddyExpenseSheet extends StatefulWidget {
  const _BuddyExpenseSheet({
    required this.teamId,
    required this.me,
    required this.buddyId,
    required this.editing,
  });

  final String teamId;
  final String me;
  final String? buddyId;
  final BuddyExpense? editing;

  @override
  State<_BuddyExpenseSheet> createState() => _BuddyExpenseSheetState();
}

class _BuddyExpenseSheetState extends State<_BuddyExpenseSheet> {
  BuddyExpense? get _editing => widget.editing;

  late final _amount = TextEditingController(
    text: _editing == null ? '' : moneyInput(_editing!.amountCents),
  );
  late final _title = TextEditingController(text: _editing?.title ?? '');
  late final _note = TextEditingController(text: _editing?.note ?? '');
  late final _categoryLabel = TextEditingController(text: _editing?.categoryLabel ?? '');

  /// Custom amounts, then % or shares, per person: [_mine] for you.
  late final _myAmount = TextEditingController(
    text: _editing?.splitMode == ExpenseSplitMode.custom ? moneyInput(_editing!.myShareCents) : '',
  );
  late final _buddyAmount = TextEditingController(
    text: _editing?.splitMode == ExpenseSplitMode.custom ? moneyInput(_editing!.buddyShareCents) : '',
  );
  late final _myWeight = TextEditingController(
    text: _editing?.myWeight == null ? '' : moneyInput(_editing!.myWeight!),
  );
  late final _buddyWeight = TextEditingController(
    text: _editing?.buddyWeight == null ? '' : moneyInput(_editing!.buddyWeight!),
  );

  late String? _buddyId = widget.buddyId;
  late bool _iPaid = _editing == null || _editing!.payerId == widget.me;
  late ExpenseSplitMode _mode = _editing?.splitMode ?? ExpenseSplitMode.equal;
  late ExpenseCategory _category = _editing?.category ?? ExpenseCategory.food;
  late DateTime _spentAt = _editing?.spentAt.toLocal() ?? DateTime.now();

  PickedImage? _receipt;
  bool _removeReceipt = false;

  @override
  void initState() {
    super.initState();
    for (final controller in [_amount, _myAmount, _buddyAmount, _myWeight, _buddyWeight]) {
      controller.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _amount,
      _title,
      _note,
      _categoryLabel,
      _myAmount,
      _buddyAmount,
      _myWeight,
      _buddyWeight,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String get _payer => _iPaid ? widget.me : _buddyId!;

  ExpenseSplit? _split() {
    final buddy = _buddyId;
    if (buddy == null) return null;
    final total = parseMoney(_amount.text) ?? 0;
    return ExpenseSplit.compute(
      // Custom here is "type both amounts" — the squad's Exact.
      mode: _mode == ExpenseSplitMode.custom ? ExpenseSplitMode.exact : _mode,
      totalCents: total,
      payerId: _payer,
      participants: [widget.me, buddy],
      exactCents: {
        widget.me: ?parseMoney(_myAmount.text),
        buddy: ?parseMoney(_buddyAmount.text),
      },
      weights: {
        widget.me: ?parseMoney(_myWeight.text),
        buddy: ?parseMoney(_buddyWeight.text),
      },
    );
  }

  /// Switching to percent or shares with nothing typed starts at 50/50.
  void _pickMode(ExpenseSplitMode mode) => setState(() {
    _mode = mode;
    if (!mode.isWeighted) return;
    if ((parseMoney(_myWeight.text) ?? 0) > 0 || (parseMoney(_buddyWeight.text) ?? 0) > 0) return;
    final even = mode == ExpenseSplitMode.percent ? '50' : '1';
    _myWeight.text = even;
    _buddyWeight.text = even;
  });

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _spentAt,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(
      () => _spentAt = DateTime(picked.year, picked.month, picked.day, _spentAt.hour, _spentAt.minute),
    );
  }

  Future<void> _pickReceipt() async {
    final picked = await pickWalletImage(context, slip: true);
    if (picked != null && mounted) {
      setState(() {
        _receipt = picked;
        _removeReceipt = false;
      });
    }
  }

  void _snack(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _save() async {
    final buddy = _buddyId;
    final split = _split();
    final amount = parseMoney(_amount.text) ?? 0;
    final title = _title.text.trim();
    if (buddy == null || split == null) return _snack('Pick who you shared it with');
    if (amount <= 0) return _snack('Enter an amount');
    if (title.isEmpty) return _snack('Add a title');
    if (!split.isValid) return _snack(split.error!);
    final isOther = _category == ExpenseCategory.other;
    final saved = await context.read<BuddyCubit>().save(
      BuddyExpenseDraft(
        id: _editing?.id,
        teamId: widget.teamId,
        buddyId: buddy,
        payerId: _payer,
        title: title,
        category: _category,
        categoryLabel: isOther && _categoryLabel.text.trim().isNotEmpty ? _categoryLabel.text.trim() : null,
        amountCents: amount,
        splitMode: _mode,
        myShareCents: split.shares[widget.me] ?? 0,
        buddyShareCents: split.shares[buddy] ?? 0,
        myWeight: _mode.isWeighted ? parseMoney(_myWeight.text) : null,
        buddyWeight: _mode.isWeighted ? parseMoney(_buddyWeight.text) : null,
        spentAt: _spentAt,
        note: _note.text,
        receiptBytes: _receipt?.bytes,
        receiptExtension: _receipt?.fileExtension,
        removeReceipt: _removeReceipt,
      ),
    );
    if (saved && mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final editing = _editing!;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Delete this buddy expense?'),
        content: Text('“${editing.title}” is deleted for both of you, and your balance changes.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    final deleted = await context.read<BuddyCubit>().delete(editing.id);
    if (deleted && mounted) Navigator.of(context).pop();
  }

  /// "You owe Ko ฿150" / "Ko owes you ฿150" for the split so far.
  String _summary(SquadLedger ledger, ExpenseSplit? split) {
    final buddy = _buddyId;
    if (buddy == null) return 'Pick who you shared it with.';
    if (split == null || (parseMoney(_amount.text) ?? 0) == 0) return 'Enter the amount first.';
    if (!split.isValid) return split.error!;
    final name = ledger.nameOf(buddy);
    final owed = _iPaid ? split.shares[buddy] ?? 0 : split.shares[widget.me] ?? 0;
    final money = formatMoney(owed, ledger.currency);
    if (owed == 0) return 'Nobody owes anything for it.';
    return _iPaid ? '$name owes you $money · only you two see it' : 'You owe $name $money · only you two see it';
  }

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<SquadLedgerBloc>().state.ledger ?? SquadLedger.empty;
    final currency = ledger.currency;
    final squadMates = [
      for (final member in ledger.members)
        if (member.profileId != widget.me) member,
    ];
    final split = _split();
    final saving = context.watch<BuddyCubit>().state.saving;
    final buddy = _buddyId;
    final buddyName = buddy == null ? 'Buddy' : ledger.nameOf(buddy);
    return BlocListener<BuddyCubit, BuddyState>(
      listenWhen: (previous, current) => current.error != null && previous.error != current.error,
      listener: (context, state) => _snack(state.error!),
      child: StickyActionSheet(
        background: AppColors.card,
        maxHeightFactor: 1,
        // Who owes whom, live — in view wherever the form is scrolled.
        summary: SplitSummaryBox(
          text: _summary(ledger, split),
          ok: split == null || split.isValid || (parseMoney(_amount.text) ?? 0) == 0,
        ),
        action: SquadPrimaryButton(
          label: _editing == null ? 'Save buddy expense' : 'Save changes',
          isLoading: saving,
          onPressed: saving ? null : _save,
        ),
        children: [
          const SheetGrabber(),
          SheetHeader(
            title: _editing == null ? 'Add buddy expense' : 'Edit buddy expense',
            actions: [
              if (_editing != null)
                IconButton(
                  onPressed: saving ? null : _delete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: 'Delete',
                ),
            ],
          ),
          const SizedBox(height: 4),
          LabeledField(
            label: 'WITH',
            child: _BuddyPicker(
              fixed: widget.buddyId != null,
              selected: buddy,
              squadMates: squadMates,
              ledger: ledger,
              onPick: (id) => setState(() => _buddyId = id),
            ),
          ),
          const SizedBox(height: 16),
          _AmountField(controller: _amount, symbol: currency.symbol),
          const SizedBox(height: 16),
          LabeledField(
            label: 'WHAT FOR',
            child: _Field(
              key: const ValueKey('buddy-title'),
              controller: _title,
              hint: 'e.g. Taxi home',
              maxLength: 80,
            ),
          ),
          const SizedBox(height: 16),
          LabeledField(
            label: 'PAID BY',
            child: SegmentedTabs<bool>(
              options: const [true, false],
              selected: _iPaid,
              label: (mine) => mine ? 'You' : buddyName,
              keyOf: (mine) => mine ? null : const ValueKey('paid-by-buddy'),
              onChanged: (mine) {
                if (!mine && buddy == null) return;
                setState(() => _iPaid = mine);
              },
              expand: true,
            ),
          ),
          const SizedBox(height: 16),
          LabeledField(
            label: 'SPLIT',
            child: SegmentedTabs<ExpenseSplitMode>(
              options: buddySplitModes,
              selected: _mode,
              label: (mode) => mode.label,
              onChanged: _pickMode,
              expand: true,
            ),
          ),
          if (buddy != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(color: AppColors.bg, borderRadius: AppRadius.md),
              child: Column(
                children: [
                  for (final (id, name, amountBox, weightBox) in [
                    (widget.me, 'You', _myAmount, _myWeight),
                    (buddy, buddyName, _buddyAmount, _buddyWeight),
                  ])
                    _ShareRow(
                      name: name,
                      member: ledger.member(id),
                      paid: id == _payer,
                      amount: split?.shares[id] == null ? '—' : formatMoney(split!.shares[id]!, currency),
                      controller: switch (_mode) {
                        ExpenseSplitMode.custom => amountBox,
                        ExpenseSplitMode.percent || ExpenseSplitMode.shares => weightBox,
                        _ => null,
                      },
                      suffix: switch (_mode) {
                        ExpenseSplitMode.percent => '%',
                        ExpenseSplitMode.shares => '×',
                        _ => null,
                      },
                      fieldKey: ValueKey('buddy-share-${id == widget.me ? 'me' : 'buddy'}'),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          LabeledField(
            label: 'CATEGORY',
            child: CategoryGrid<ExpenseCategory>(
              options: [
                for (final category in ExpenseCategory.everyday)
                  (
                    value: category,
                    label: category.label,
                    icon: categoryIcon(category),
                    background: categoryTone(category).background,
                    foreground: categoryTone(category).foreground,
                  ),
              ],
              selected: _category,
              onSelected: (category) => setState(() => _category = category),
            ),
          ),
          if (_category == ExpenseCategory.other) ...[
            const SizedBox(height: 10),
            _Field(controller: _categoryLabel, hint: 'What for? e.g. Gym', maxLength: 30),
          ],
          const SizedBox(height: 16),
          LabeledField(
            label: 'DATE',
            child: OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(
                formatDayLabel(_spentAt),
                style: AppTextStyles.body(size: 14, weight: FontWeight.w700),
              ),
              style: _outlined,
            ),
          ),
          const SizedBox(height: 16),
          LabeledField(
            label: 'RECEIPT',
            child: ReceiptPicker(
              label: 'Add receipt photo (optional)',
              picked: _receipt,
              savedPath: _removeReceipt ? null : _editing?.receiptPath,
              onPick: _pickReceipt,
              onRemove: () => setState(() {
                _receipt = null;
                _removeReceipt = _editing?.receiptPath != null;
              }),
            ),
          ),
          const SizedBox(height: 16),
          LabeledField(
            label: 'NOTE',
            child: _Field(controller: _note, hint: 'Anything to remember (optional)', maxLength: 500, maxLines: 4),
          ),
        ],
      ),
    );
  }
}

final _outlined = OutlinedButton.styleFrom(
  foregroundColor: AppColors.text,
  alignment: Alignment.centerLeft,
  minimumSize: const Size.fromHeight(46),
  side: BorderSide(color: AppColors.text.withValues(alpha: 0.18)),
  shape: RoundedRectangleBorder(borderRadius: AppRadius.sm),
);

/// Who you shared it with: fixed (opened from your page with them), or a
/// row of your squad-mates to pick from.
class _BuddyPicker extends StatelessWidget {
  const _BuddyPicker({
    required this.fixed,
    required this.selected,
    required this.squadMates,
    required this.ledger,
    required this.onPick,
  });

  final bool fixed;
  final String? selected;
  final List<SquadMember> squadMates;
  final SquadLedger ledger;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final selected = this.selected;
    if (fixed && selected != null) {
      final member = ledger.member(selected);
      return Row(
        children: [
          SquadAvatar(
            initial: member?.initial ?? '?',
            photoUrl: member?.avatarUrl,
            size: 30,
            color: AppColors.teamGold,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(ledger.nameOf(selected), style: AppTextStyles.title(size: 16))),
        ],
      );
    }
    if (squadMates.isEmpty) {
      return const SheetNotice('Invite someone to the squad first.', icon: Icons.group_add_outlined);
    }
    return SizedBox(
      height: 36,
      child: EdgeFade(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: squadMates.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final member = squadMates[index];
            return SquadChoiceChip(
              label: ledger.nameOf(member.profileId),
              selected: member.profileId == selected,
              onTap: () => onPick(member.profileId),
            );
          },
        ),
      ),
    );
  }
}

/// The big amount, underlined, with the currency symbol.
class _AmountField extends StatelessWidget {
  const _AmountField({required this.controller, required this.symbol});

  final TextEditingController controller;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.text, width: 2)),
      ),
      child: Row(
        children: [
          Text(symbol, style: AppTextStyles.heading(size: 28, color: squadMuted)),
          const SizedBox(width: 6),
          Expanded(
            child: Semantics(
              label: 'Amount',
              child: TextField(
                key: const ValueKey('buddy-amount'),
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: const [MoneyInputFormatter()],
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
    );
  }
}

/// One of you in the split: avatar, name (and "paid" on the payer), and
/// either the share or — custom, percent, shares — a box to type it in.
class _ShareRow extends StatelessWidget {
  const _ShareRow({
    required this.name,
    required this.member,
    required this.paid,
    required this.amount,
    required this.controller,
    required this.suffix,
    required this.fieldKey,
  });

  final String name;
  final SquadMember? member;
  final bool paid;
  final String amount;

  /// Custom: the amount; percent / shares: the weight; equal: none.
  final TextEditingController? controller;
  final String? suffix;
  final Key fieldKey;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Row(
        children: [
          SquadAvatar(
            initial: member?.initial ?? '?',
            photoUrl: member?.avatarUrl,
            size: 28,
            color: paid ? AppColors.teamGold : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.body(size: 14, weight: FontWeight.w700)),
                if (paid) Text('paid', style: AppTextStyles.body(size: 11.5, color: squadMuted)),
              ],
            ),
          ),
          // Percent and shares show what the weight comes to; custom's box
          // is the amount itself.
          if (controller == null || suffix != null)
            Text(amount, style: AppTextStyles.body(size: 15, weight: FontWeight.w800)),
          if (controller != null) ...[
            const SizedBox(width: 10),
            SizedBox(
              width: 96,
              child: Semantics(
                label: '$name share',
                child: TextField(
                  key: fieldKey,
                  controller: controller,
                  textAlign: TextAlign.right,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: const [MoneyInputFormatter()],
                  style: AppTextStyles.body(size: 14, weight: FontWeight.w800),
                  decoration: InputDecoration(
                    hintText: '0',
                    suffixText: suffix,
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.card,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.sm,
                      borderSide: BorderSide(color: AppColors.text.withValues(alpha: 0.18)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadius.sm,
                      borderSide: BorderSide(color: AppColors.text.withValues(alpha: 0.18)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    super.key,
    required this.controller,
    required this.hint,
    required this.maxLength,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLength;
  final int maxLines;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    maxLength: maxLength,
    minLines: 1,
    maxLines: maxLines,
    textCapitalization: TextCapitalization.sentences,
    style: AppTextStyles.body(size: 14, weight: FontWeight.w600),
    decoration: InputDecoration(
      hintText: hint,
      counterText: '',
      isDense: true,
      filled: true,
      fillColor: AppColors.bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: AppRadius.sm,
        borderSide: BorderSide(color: AppColors.text.withValues(alpha: 0.18)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.sm,
        borderSide: BorderSide(color: AppColors.text.withValues(alpha: 0.18)),
      ),
    ),
  );
}
