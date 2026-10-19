import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/widgets/edge_fade.dart';
import '../../../../core/theme/widgets/money_input_formatter.dart';
import '../../../../core/theme/widgets/sticky_action_sheet.dart';
import '../../../wallet/domain/repositories/wallet_repository.dart' show WalletImageKind;
import '../../../wallet/domain/usecases/upload_wallet_qr.dart';
import '../../../wallet/presentation/widgets/wallet_image.dart';
import '../../../wallet/presentation/widgets/wallet_image_actions.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_split.dart';
import '../../domain/entities/recurring_expense.dart';
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
  String? tripId,
  RecurringExpense? editingMonthly,
  bool monthly = false,
}) async {
  // Adding one needs your payment QR first: it's how squad-mates pay you
  // back. Editing doesn't.
  if (editing == null && editingMonthly == null) {
    if (!await ensurePaymentQr(context, me: me) || !context.mounted) return;
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
    builder: (_) => _ExpenseSheet(
      teamId: teamId,
      me: me,
      editing: editing,
      tripId: tripId,
      editingMonthly: editingMonthly,
      monthly: monthly,
    ),
  );
}

/// Who just uploaded one here, so their next sheet doesn't ask again
/// before the squad has reloaded with it.
String? _qrJustUploadedBy;

/// True if [me] has a payment QR; if not, "Add your payment QR first" —
/// upload it there and carry on (true), or not now (false). Asked before
/// adding any expense (trip and monthly too) or starting a trip.
Future<bool> ensurePaymentQr(BuildContext context, {required String me}) async {
  final ledger = context.read<SquadLedgerBloc>().state.ledger;
  if (_qrJustUploadedBy == me || (ledger?.member(me)?.hasQr ?? true)) return true;
  final uploaded =
      await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: AppColors.card,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
        builder: (_) => const _PaymentQrSheet(),
      ) ??
      false;
  if (uploaded) _qrJustUploadedBy = me;
  return uploaded;
}

class _PaymentQrSheet extends StatefulWidget {
  const _PaymentQrSheet();

  @override
  State<_PaymentQrSheet> createState() => _PaymentQrSheetState();
}

class _PaymentQrSheetState extends State<_PaymentQrSheet> {
  bool _uploading = false;

  Future<void> _upload() async {
    final picked = await pickWalletImage(context);
    if (picked == null || !mounted) return;
    setState(() => _uploading = true);
    final result = await sl<UploadWalletQr>()(
      UploadWalletQrParams(bytes: picked.bytes, fileExtension: picked.fileExtension),
    );
    if (!mounted) return;
    setState(() => _uploading = false);
    result.fold(
      (failure) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failure.message))),
      (_) {
        // So the squad (and Pay sheets) see it straight away.
        context.read<SquadLedgerBloc>().add(const SquadRefreshRequested());
        Navigator.of(context).pop(true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.qr_code_2_rounded, size: 44, color: AppColors.accent700),
            const SizedBox(height: 12),
            Text(
              'Add your payment QR first',
              textAlign: TextAlign.center,
              style: AppTextStyles.heading(size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              'Squad-mates scan it to pay you back for what you add. '
              'You only need to do this once — change it any time in your profile.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body(size: 13.5, color: squadMuted),
            ),
            const SizedBox(height: 20),
            SquadPrimaryButton(label: 'Upload QR', isLoading: _uploading, onPressed: _upload),
            TextButton(
              onPressed: _uploading ? null : () => Navigator.of(context).pop(false),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseSheet extends StatefulWidget {
  const _ExpenseSheet({
    required this.teamId,
    required this.me,
    this.editing,
    this.tripId,
    this.editingMonthly,
    this.monthly = false,
  });

  final String teamId;
  final String me;
  final Expense? editing;

  /// A new trip expense's trip ("Add trip expense").
  final String? tripId;

  /// A monthly expense being changed (from next month's charge).
  final RecurringExpense? editingMonthly;

  /// Opened as a monthly expense ("Add monthly expense").
  final bool monthly;

  @override
  State<_ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends State<_ExpenseSheet> {
  late final _amount = TextEditingController(
    text: switch ((widget.editing, widget.editingMonthly)) {
      (final e?, _) => moneyInput(e.amountCents),
      (_, final m?) => moneyInput(m.amountCents),
      _ => '',
    },
  );
  late final _title = TextEditingController(
    text: widget.editing?.title ?? widget.editingMonthly?.title ?? '',
  );
  late final _note = TextEditingController(
    text: widget.editing?.note ?? widget.editingMonthly?.note ?? '',
  );

  /// A monthly expense — only when opened as one ("Add monthly expense",
  /// or editing one): charged on [_chargeDay] each month, starting this
  /// month or next.
  late final bool _monthly = widget.editingMonthly != null || widget.monthly;
  late int _chargeDay = widget.editingMonthly?.chargeDay ?? _defaultChargeDay();
  bool _startNextMonth = false;

  static int _defaultChargeDay() {
    final day = DateTime.now().day;
    return day > 28 ? RecurringExpense.lastDay : day;
  }

  final _exact = <String, TextEditingController>{};

  /// Exact or custom with no total typed: the total is the shares' sum,
  /// kept in step as they're typed — until the total's typed over.
  bool _totalFromShares = false;
  String? _autoTotal;

  /// Who paid, biggest first; several (up to Expense.maxPayers) means each
  /// types what they paid.
  late List<String> _payerIds = switch ((widget.editing, widget.editingMonthly)) {
    (final e?, _) =>
      (e.payers.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
          .map((entry) => entry.key)
          .toList(),
    (_, final m?) => [m.payerId],
    _ => [widget.me],
  };
  final _paid = <String, TextEditingController>{};

  /// A monthly expense (or one month's charge) picks its service —
  /// YouTube, Netflix, … — not an everyday category.
  late final List<ExpenseCategory> _categories = _monthly || widget.editing?.recurringId != null
      ? ExpenseCategory.subscriptions
      : ExpenseCategory.everyday;

  late ExpenseCategory _category = switch (widget.editing?.category ??
      widget.editingMonthly?.category) {
    // An older monthly expense saved with an everyday category: "Other".
    final c? when _categories.contains(c) => c,
    _ =>
      _categories.contains(ExpenseCategory.food)
          ? ExpenseCategory.food
          : ExpenseCategory.subscription,
  };

  /// What "Other" is ("Gym", "Amazon Prime") — asked when Other's picked.
  late final _categoryLabel = TextEditingController(
    text: widget.editing?.categoryLabel ?? widget.editingMonthly?.categoryLabel ?? '',
  );

  bool get _isOther =>
      _category == ExpenseCategory.other || _category == ExpenseCategory.subscription;

  /// The name to save for Other (null clears it); saved when it's Other or
  /// it had one before.
  ({String? label, bool set}) get _labelToSave {
    final had = (widget.editing?.categoryLabel ?? widget.editingMonthly?.categoryLabel) != null;
    final label = _isOther && _categoryLabel.text.trim().isNotEmpty
        ? _categoryLabel.text.trim()
        : null;
    return (label: label, set: label != null || had);
  }

  /// Picking a service fills in an empty title ("Netflix"), or one it
  /// filled in before.
  void _pickCategory(ExpenseCategory category) => setState(() {
    final title = _title.text.trim();
    final autoFilled = title.isEmpty || title == _category.label;
    _category = category;
    if (category.isSubscription && category != ExpenseCategory.subscription && autoFilled) {
      _title.text = category.label;
    }
  });
  late ExpenseSplitMode _mode =
      widget.editing?.splitMode ?? widget.editingMonthly?.splitMode ?? ExpenseSplitMode.equal;

  /// Ticked people for a chosen or custom split; null = everyone (not yet
  /// touched). Guests are in it by their [_Guest.key].
  Set<String>? _chosen;

  /// Guests from outside the squad in this split (not in monthly ones).
  final _guests = <_Guest>[];
  var _nextGuest = 0;

  String _guestKey() => 'guest-${_nextGuest++}';

  /// A new proof-of-payment photo, or [_removeReceipt] to take the saved
  /// one off.
  PickedImage? _receipt;
  bool _removeReceipt = false;

  Future<void> _pickReceipt() async {
    final picked = await pickWalletImage(context, slip: true);
    if (picked != null && mounted) {
      setState(() {
        _receipt = picked;
        _removeReceipt = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    var (splitMode, shares) = switch ((editing, widget.editingMonthly)) {
      (final e?, _) => (e.splitMode, e.shares),
      (_, final m?) => (m.splitMode, m.shares),
      _ => (null, const <String, int>{}),
    };
    // Guests come back out of whoever covered them.
    if (editing != null && editing.guests.isNotEmpty) {
      final unfolded = {...shares};
      for (final guest in editing.guests) {
        final key = _guestKey();
        _guests.add(_Guest(key: key, name: guest.name, hostId: guest.hostId));
        final cover = editing.coverOf(guest);
        unfolded[cover] = (unfolded[cover] ?? 0) - guest.amountCents;
        unfolded[key] = guest.amountCents;
      }
      shares = {
        for (final MapEntry(:key, :value) in unfolded.entries)
          if (value > 0) key: value,
      };
    }
    if (splitMode case ExpenseSplitMode.chosen || ExpenseSplitMode.custom) {
      _chosen = shares.keys.toSet();
    }
    if (splitMode case ExpenseSplitMode.exact || ExpenseSplitMode.custom) {
      for (final MapEntry(:key, :value) in shares.entries) {
        _exactFor(key).text = moneyInput(value);
      }
    }
    if (editing != null && editing.hasSeveralPayers) {
      for (final MapEntry(:key, :value) in editing.payers.entries) {
        _paidFor(key).text = moneyInput(value);
      }
    }
    _amount.addListener(_onAmountChanged);
  }

  /// Typing over a total filled in from the shares makes it yours.
  void _onAmountChanged() {
    if (_totalFromShares && _amount.text != _autoTotal) _totalFromShares = false;
    _rebuild();
  }

  /// Fills the total in from the typed shares (exact, or custom's ticked
  /// people) while it's empty or was filled in this way.
  void _syncFromShares() {
    if (_several || (_mode != ExpenseSplitMode.exact && _mode != ExpenseSplitMode.custom)) return;
    if (!_totalFromShares && _amount.text.isNotEmpty) return;
    final sum = [
      for (final MapEntry(:key, :value) in _exact.entries)
        if (_mode == ExpenseSplitMode.exact || (_chosen?.contains(key) ?? true))
          parseMoney(value.text) ?? 0,
    ].fold(0, (a, b) => a + b);
    final text = sum > 0 ? moneyInput(sum) : '';
    _totalFromShares = sum > 0;
    _autoTotal = text;
    if (_amount.text != text) _amount.text = text;
  }

  TextEditingController _paidFor(String profileId) => _paid.putIfAbsent(profileId, () {
    final controller = TextEditingController();
    controller.addListener(_syncTotal);
    return controller;
  });

  bool get _several => _payerIds.length > 1;

  /// The total: typed in, or with several payers what they paid together.
  int get _amountCents =>
      _several ? _payers().values.fold(0, (a, b) => a + b) : parseMoney(_amount.text) ?? 0;

  /// What each payer paid. One payer: the whole amount. Several: what each
  /// typed (0 while empty).
  Map<String, int> _payers() {
    if (!_several) return {_payerIds.single: parseMoney(_amount.text) ?? 0};
    return {for (final id in _payerIds) id: parseMoney(_paidFor(id).text) ?? 0};
  }

  /// With several payers the amount box shows their total.
  void _syncTotal() {
    if (_several) {
      final total = _amountCents;
      final text = total > 0 ? moneyInput(total) : '';
      if (_amount.text != text) _amount.text = text;
    }
    _rebuild();
  }

  /// Whoever paid the most (covers any rounding in an equal split).
  String _mainPayer(Map<String, int> payers) =>
      payers.entries.reduce((a, b) => b.value > a.value ? b : a).key;

  /// Why the payers can't be saved yet, or null.
  String? _payersError(Map<String, int> payers) =>
      payers.length > 1 && payers.values.any((cents) => cents <= 0)
      ? 'Type what each payer paid'
      : null;

  void _rebuild() => setState(() {});

  /// The trip this expense is in, if any (an edit keeps its own).
  String? get _tripId => widget.editing?.tripId ?? widget.tripId;

  /// Who can pay or share: the people on the trip, or the whole squad.
  List<SquadMember> _members(SquadLedger ledger) {
    final trip = switch (_tripId) {
      final id? => ledger.trip(id),
      null => null,
    };
    return trip == null
        ? ledger.members
        : [
            for (final member in ledger.members)
              if (trip.includes(member.profileId)) member,
          ];
  }

  TextEditingController _exactFor(String profileId) => _exact.putIfAbsent(profileId, () {
    final controller = TextEditingController();
    controller.addListener(() {
      _syncFromShares();
      _rebuild();
    });
    return controller;
  });

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    _note.dispose();
    _categoryLabel.dispose();
    for (final controller in [..._exact.values, ..._paid.values]) {
      controller.dispose();
    }
    super.dispose();
  }

  ExpenseSplit _split(List<SquadMember> members) {
    final everyone = [
      for (final member in members) member.profileId,
      if (!_monthly)
        for (final guest in _guests) guest.key,
    ];
    final chosen = _chosen ?? everyone.toSet();
    final amount = _amountCents;
    final payers = _payers();
    return ExpenseSplit.compute(
      mode: _mode,
      totalCents: amount,
      payerId: _mainPayer(payers),
      payers: payers.length > 1 ? payers : null,
      participants: switch (_mode) {
        ExpenseSplitMode.chosen || ExpenseSplitMode.custom => [
          for (final id in everyone)
            if (chosen.contains(id)) id,
        ],
        _ => everyone,
      },
      exactCents: {for (final id in everyone) id: ?parseMoney(_exactFor(id).text)},
    );
  }

  void _save(SquadLedger ledger) {
    final amount = _amountCents;
    final split = _split(_members(ledger));
    final payers = _payers();
    final payersError = _payersError(payers);
    final title = _title.text.trim();
    final monthlyError = !_monthly
        ? null
        : _guests.isNotEmpty
        ? "Guests can't be in a monthly expense"
        : payers.length > 1
        ? 'A monthly expense has one payer'
        : _mode == ExpenseSplitMode.treat
        ? "A treat can't repeat monthly"
        : null;
    if (amount <= 0 ||
        title.isEmpty ||
        payersError != null ||
        monthlyError != null ||
        !split.isValid) {
      _snack(switch (amount) {
        <= 0 => 'Enter an amount',
        _ when title.isEmpty => 'Add a title',
        _ => payersError ?? monthlyError ?? split.error!,
      });
      return;
    }
    if (_monthly) {
      final now = DateTime.now();
      context.read<SquadLedgerBloc>().add(
        RecurringSaveRequested(
          RecurringDraft(
            id: widget.editingMonthly?.id,
            teamId: widget.teamId,
            title: title,
            category: _category,
            amountCents: amount,
            payerId: payers.keys.single,
            splitMode: _mode,
            shares: split.shares,
            chargeDay: _chargeDay,
            startsOn: DateTime(now.year, now.month + (_startNextMonth ? 1 : 0)),
            note: _note.text.trim(),
            categoryLabel: _labelToSave.label,
            setCategoryLabel: _labelToSave.set,
          ),
        ),
      );
      return;
    }
    // Each guest's share goes into whoever covers them (or the payer); the
    // guests themselves are saved alongside, for information.
    final shares = {...split.shares};
    final guests = <ExpenseGuest>[];
    if (_mode != ExpenseSplitMode.treat) {
      for (final guest in _guests) {
        final cents = shares.remove(guest.key);
        if (cents == null || cents <= 0) continue;
        final cover = guest.hostId ?? _mainPayer(payers);
        shares[cover] = (shares[cover] ?? 0) + cents;
        guests.add(ExpenseGuest(name: guest.name, amountCents: cents, hostId: guest.hostId));
      }
    }
    final hadGuests = widget.editing?.guests.isNotEmpty ?? false;
    context.read<SquadLedgerBloc>().add(
      ExpenseSaveRequested(
        ExpenseDraft(
          id: widget.editing?.id,
          teamId: widget.teamId,
          title: title,
          category: _category,
          amountCents: amount,
          splitMode: _mode,
          payerId: _mainPayer(payers),
          payers: payers.length > 1 ? payers : null,
          shares: shares,
          guests: guests.isNotEmpty || hadGuests ? guests : null,
          spentAt: widget.editing?.spentAt,
          note: _note.text.trim(),
          place: widget.editing?.place,
          tripId: _tripId,
          receiptBytes: _receipt?.bytes,
          receiptExtension: _receipt?.fileExtension,
          removeReceipt: _removeReceipt,
          categoryLabel: _labelToSave.label,
          setCategoryLabel: _labelToSave.set,
        ),
      ),
    );
  }

  void _snack(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  /// "Who paid?": tap one person, or switch to "Several people paid" and
  /// tick up to Expense.maxPayers.
  Future<void> _pickPayers(SquadLedger ledger) async {
    var several = _payerIds.length > 1;
    final ticked = [..._payerIds];
    final picked = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(
                  several ? 'Who paid? · up to ${Expense.maxPayers}' : 'Who paid?',
                  style: AppTextStyles.title(size: 18),
                ),
              ),
              for (final member in _members(ledger))
                if (several)
                  CheckboxListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    secondary: SquadAvatar(
                      initial: member.initial,
                      photoUrl: member.avatarUrl,
                      size: 36,
                    ),
                    title: Text(
                      ledger.nameOf(member.profileId, me: widget.me),
                      style: AppTextStyles.body(size: 15, weight: FontWeight.w600),
                    ),
                    activeColor: AppColors.accentFill,
                    value: ticked.contains(member.profileId),
                    // Full: only untick until someone's taken off.
                    onChanged:
                        ticked.contains(member.profileId) || ticked.length < Expense.maxPayers
                        ? (_) => setSheetState(() {
                            if (!ticked.remove(member.profileId)) ticked.add(member.profileId);
                          })
                        : null,
                  )
                else
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: SquadAvatar(
                      initial: member.initial,
                      photoUrl: member.avatarUrl,
                      size: 36,
                    ),
                    title: Text(
                      ledger.nameOf(member.profileId, me: widget.me),
                      style: AppTextStyles.body(size: 15, weight: FontWeight.w600),
                    ),
                    trailing: _payerIds.length == 1 && member.profileId == _payerIds.single
                        ? Icon(Icons.check_rounded, color: AppColors.accent700)
                        : null,
                    onTap: () => Navigator.of(context).pop([member.profileId]),
                  ),
              const SizedBox(height: 8),
              if (several)
                SquadPrimaryButton(
                  label: ticked.isEmpty ? 'Pick who paid' : 'Done · ${ticked.length} paid',
                  onPressed: ticked.isEmpty ? null : () => Navigator.of(context).pop(ticked),
                )
              else
                TextButton.icon(
                  onPressed: () => setSheetState(() => several = true),
                  icon: const Icon(Icons.group_add_outlined, size: 18),
                  label: Text(
                    'Several people paid',
                    style: AppTextStyles.body(size: 14, weight: FontWeight.w700),
                  ),
                  style: TextButton.styleFrom(foregroundColor: AppColors.accent700),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || picked.isEmpty) return;
    final previous = _payerIds;
    setState(() => _payerIds = picked);
    // Going from one payer to several: what's typed so far becomes that
    // payer's part, so nothing's lost.
    final typed = parseMoney(_amount.text);
    if (previous.length == 1 &&
        picked.length > 1 &&
        typed != null &&
        picked.every((id) => _paidFor(id).text.isEmpty)) {
      _paidFor(picked.contains(previous.single) ? previous.single : picked.first).text = moneyInput(
        typed,
      );
    }
    _syncTotal();
  }

  /// "Add guest": a name, and who covers them — a member, or no one (the
  /// payer collects it from them outside the app).
  Future<void> _addGuest(SquadLedger ledger) async {
    final added = await showDialog<_Guest>(
      context: context,
      builder: (context) =>
          _GuestDialog(members: _members(ledger), me: widget.me, ledger: ledger, newKey: _guestKey),
    );
    if (added == null || !mounted) return;
    setState(() {
      _guests.add(added);
      _chosen?.add(added.key);
    });
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
        final split = _split(_members(ledger));
        final amount = _amountCents;
        final payers = _payers();
        final mainPayer = _mainPayer(payers);
        final payersError = _payersError(payers);
        return StickyActionSheet(
          background: AppColors.card,
          // useSafeArea already keeps it below the status bar.
          maxHeightFactor: 1,
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
                    widget.editingMonthly != null
                        ? 'Edit monthly expense'
                        : _monthly
                        ? 'Add monthly expense'
                        : switch ((widget.editing == null, _tripId == null)) {
                            (true, true) => 'Add expense',
                            (true, false) => 'Add trip expense',
                            (false, true) => 'Edit expense',
                            (false, false) => 'Edit trip expense',
                          },
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
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.text, width: 2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(currency.symbol, style: AppTextStyles.heading(size: 28, color: squadMuted)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Semantics(
                      label: 'Amount',
                      child: TextField(
                        key: const ValueKey('expense-amount'),
                        controller: _amount,
                        // Several payers: their total, filled in below.
                        readOnly: _several,
                        autofocus: widget.editing == null,
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
            ),
            if (_several)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Total of who paid what',
                  style: AppTextStyles.body(size: 12, color: squadMuted),
                ),
              ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Labeled(
                    label: 'TITLE',
                    // Required, and never the category's name.
                    child: _Field(
                      key: const ValueKey('expense-title'),
                      controller: _title,
                      hint: 'e.g. Friday dinner',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Labeled(
                    label: 'PAID BY',
                    child: _PayerButton(
                      name: _payerIds.length == 1
                          ? ledger.nameOf(_payerIds.single, me: widget.me)
                          : '${ledger.nameOf(_payerIds.first, me: widget.me)} '
                                '+ ${_payerIds.length - 1}',
                      initial: ledger.member(_payerIds.first)?.initial ?? '?',
                      photoUrl: ledger.member(_payerIds.first)?.avatarUrl,
                      onTap: () => _pickPayers(ledger),
                    ),
                  ),
                ),
              ],
            ),
            // Several payers: what each one paid.
            if (_payerIds.length > 1) ...[
              const SizedBox(height: 14),
              Text('WHO PAID WHAT', style: AppTextStyles.label(color: squadMuted)),
              for (final id in _payerIds)
                _ShareRow(
                  name: ledger.nameOf(id, me: widget.me),
                  initial: ledger.member(id)?.initial ?? '?',
                  photoUrl: ledger.member(id)?.avatarUrl,
                  mode: ExpenseSplitMode.exact,
                  included: true,
                  onToggle: null,
                  exactController: _paidFor(id),
                  fieldKey: ValueKey('paid-$id'),
                  amount: '',
                  sub: '',
                ),
              Text(
                amount == 0
                    ? 'Type what each person paid.'
                    : payersError ??
                          'Total ${formatMoney(amount, currency)} from ${payers.length} payers.',
                style: AppTextStyles.body(
                  size: 12,
                  color: payersError == null || amount == 0 ? squadMuted : AppColors.accent700,
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              height: 36,
              child: EdgeFade(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    return SquadChoiceChip(
                      label: category.label,
                      icon: categoryIcon(category),
                      selected: category == _category,
                      onTap: () => _pickCategory(category),
                    );
                  },
                ),
              ),
            ),
            // Other: say what it is.
            if (_isOther) ...[
              const SizedBox(height: 10),
              _Field(
                key: const ValueKey('category-label'),
                controller: _categoryLabel,
                hint: _monthly ? 'Which service? e.g. Amazon Prime' : 'What for? e.g. Gym',
              ),
            ],
            if (_monthly) ...[
              const SizedBox(height: 10),
              _MonthlyPicker(
                // Editing one: its first month is already set.
                firstMonthSet: widget.editingMonthly != null,
                chargeDay: _chargeDay,
                startNextMonth: _startNextMonth,
                onChargeDay: (day) => setState(() => _chargeDay = day),
                onStartNextMonth: (next) => setState(() => _startNextMonth = next),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('SPLIT', style: AppTextStyles.label(color: squadMuted)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tap a type to choose how it’s shared',
                    style: AppTextStyles.body(size: 12, color: squadMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _ModeTabs(
              mode: _mode,
              onChanged: (mode) {
                setState(() => _mode = mode);
                _syncFromShares();
              },
            ),
            // What the picked type does (a treat explains itself below).
            if (_modeHint(_mode) case final hint?) ...[
              const SizedBox(height: 6),
              Text(hint, style: AppTextStyles.body(size: 12.5, color: squadMuted)),
            ],
            const SizedBox(height: 8),
            if (_mode == ExpenseSplitMode.treat)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.accent2_100, borderRadius: AppRadius.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _payerIds.length == 1
                          ? "${ledger.nameOf(_payerIds.single, me: widget.me)}'s treat"
                          : "${_payerIds.map((id) => ledger.nameOf(id, me: widget.me)).join(' & ')}'s treat",
                      style: AppTextStyles.title(size: 16, color: AppColors.accent2_900),
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
              for (final member in _members(ledger))
                _ShareRow(
                  name:
                      ledger.nameOf(member.profileId, me: widget.me) +
                      (payers.containsKey(member.profileId) ? ' (paid)' : ''),
                  initial: member.initial,
                  photoUrl: member.avatarUrl,
                  mode: _mode,
                  included: switch (_mode) {
                    ExpenseSplitMode.chosen || ExpenseSplitMode.custom =>
                      (_chosen ?? {for (final m in _members(ledger)) m.profileId}).contains(
                        member.profileId,
                      ),
                    ExpenseSplitMode.exact => split.shares.containsKey(member.profileId),
                    _ => true,
                  },
                  onToggle: _mode == ExpenseSplitMode.chosen || _mode == ExpenseSplitMode.custom
                      ? () => setState(() {
                          final chosen = _chosen ??= {
                            for (final m in _members(ledger)) m.profileId,
                            for (final g in _guests) g.key,
                          };
                          if (!chosen.remove(member.profileId)) chosen.add(member.profileId);
                          _syncFromShares();
                        })
                      : null,
                  // Custom: a box only for the ticked people.
                  exactController:
                      _mode == ExpenseSplitMode.exact ||
                          (_mode == ExpenseSplitMode.custom &&
                              (_chosen ?? {member.profileId}).contains(member.profileId))
                      ? _exactFor(member.profileId)
                      : null,
                  fieldKey: ValueKey('share-${member.profileId}'),
                  amount: split.shares[member.profileId] == null
                      ? '—'
                      : formatMoney(split.shares[member.profileId]!, currency),
                  sub: switch (split.shares[member.profileId]) {
                    null => 'not in it',
                    _ when member.profileId == mainPayer && split.roundedCents != null =>
                      'covers the rest',
                    _
                        when split.exactCents != null &&
                            split.exactCents != split.shares[member.profileId] =>
                      'exact ${formatMoneyExact(split.exactCents!, currency)}',
                    _ => '',
                  },
                ),
            // Guests from outside the squad: same split, shown as guests.
            if (_mode != ExpenseSplitMode.treat && !_monthly) ...[
              for (final guest in _guests)
                _ShareRow(
                  name: '${guest.name} (guest)',
                  initial: guest.name.isEmpty ? '?' : guest.name[0].toUpperCase(),
                  mode: _mode,
                  included: switch (_mode) {
                    ExpenseSplitMode.chosen ||
                    ExpenseSplitMode.custom => (_chosen ?? {guest.key}).contains(guest.key),
                    ExpenseSplitMode.exact => split.shares.containsKey(guest.key),
                    _ => true,
                  },
                  onToggle: _mode == ExpenseSplitMode.chosen || _mode == ExpenseSplitMode.custom
                      ? () => setState(() {
                          final chosen = _chosen ??= {
                            for (final m in _members(ledger)) m.profileId,
                            for (final g in _guests) g.key,
                          };
                          if (!chosen.remove(guest.key)) chosen.add(guest.key);
                          _syncFromShares();
                        })
                      : null,
                  exactController:
                      _mode == ExpenseSplitMode.exact ||
                          (_mode == ExpenseSplitMode.custom &&
                              (_chosen ?? {guest.key}).contains(guest.key))
                      ? _exactFor(guest.key)
                      : null,
                  fieldKey: ValueKey('share-${guest.key}'),
                  amount: split.shares[guest.key] == null
                      ? '—'
                      : formatMoney(split.shares[guest.key]!, currency),
                  sub: guest.hostId == null
                      ? 'pays the payer directly'
                      : 'covered by ${ledger.nameOf(guest.hostId!, me: widget.me)}',
                  onRemove: () => setState(() {
                    _guests.remove(guest);
                    _chosen?.remove(guest.key);
                    // Out of the sum now; disposed once its row is gone.
                    if (_exact.remove(guest.key) case final controller?) {
                      WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
                    }
                    _syncFromShares();
                  }),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _addGuest(ledger),
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                  label: Text(
                    'Add guest',
                    style: AppTextStyles.body(size: 13.5, weight: FontWeight.w700),
                  ),
                  style: TextButton.styleFrom(foregroundColor: AppColors.accent700),
                ),
              ),
            ],
            // Monthly: each month's charge gets its own proof, not the plan.
            if (!_monthly) ...[
              const SizedBox(height: 14),
              Text('PROOF OF PAYMENT', style: AppTextStyles.label(color: squadMuted)),
              const SizedBox(height: 6),
              _ReceiptPicker(
                picked: _receipt,
                savedPath: _removeReceipt ? null : widget.editing?.receiptPath,
                onPick: _pickReceipt,
                onRemove: () => setState(() {
                  _receipt = null;
                  _removeReceipt = widget.editing?.receiptPath != null;
                }),
              ),
            ],
            const SizedBox(height: 10),
            _Field(controller: _note, hint: 'Note (optional)'),
          ],
          // The split, live: who pays what as the amount, people and
          // mode change — in view wherever the form is scrolled.
          summary: _SplitSummary(
            text: _footnote(split, amount, ledger, mainPayer),
            ok: split.isValid || amount == 0,
          ),
          action: SquadPrimaryButton(
            label: widget.editing != null || widget.editingMonthly != null
                ? 'Save changes'
                : _monthly
                ? 'Save monthly expense'
                : 'Save expense',
            isLoading: state is SquadLedgerSubmitting,
            onPressed: () => _save(ledger),
          ),
        );
      },
    );
  }

  static String? _modeHint(ExpenseSplitMode mode) => switch (mode) {
    ExpenseSplitMode.equal => 'Equal: everyone pays the same.',
    ExpenseSplitMode.chosen => 'Chosen: tick who’s in — they pay the same.',
    ExpenseSplitMode.exact => 'Exact: type what each person pays.',
    ExpenseSplitMode.custom => 'Custom: tick who’s in, then type what each pays.',
    ExpenseSplitMode.treat => null,
  };

  String _footnote(ExpenseSplit split, int amount, SquadLedger ledger, String mainPayer) {
    if (amount == 0) {
      return _several
          ? 'Type what each person paid first.'
          : switch (_mode) {
              ExpenseSplitMode.exact ||
              ExpenseSplitMode.custom => 'Enter the amount, or type each share to add it up.',
              _ => 'Enter the amount first.',
            };
    }
    final total = formatMoney(amount, ledger.currency);
    final entered = split.shares.values.fold(0, (a, b) => a + b);
    return switch (_mode) {
      ExpenseSplitMode.treat => 'Treats still show in the squad’s spending.',
      ExpenseSplitMode.custom when split.shares.isEmpty && !split.isValid => split.error!,
      ExpenseSplitMode.exact || ExpenseSplitMode.custom =>
        split.isValid
            ? _totalFromShares
                  ? 'Total added up from the shares: $total. Type a total to check against it.'
                  : 'Shares add up to $total.'
            : 'Shares must add up to $total · '
                  '${formatMoney(entered, ledger.currency)} entered, '
                  '${formatMoney((amount - entered).abs(), ledger.currency)} '
                  '${entered > amount ? 'over' : 'left'}.',
      _ when !split.isValid => split.error!,
      _ when split.roundedCents != null =>
        '$total ÷ ${split.shares.length} = ${formatMoneyExact(split.exactCents!, ledger.currency)}. '
            'Everyone pays the whole amount; '
            '${ledger.nameOf(mainPayer, me: widget.me)} covers the rest.',
      _ =>
        '$total ÷ ${split.shares.length}, to the last ${ledger.currency.symbol == '฿' ? 'satang' : 'pya'}.',
    };
  }
}

/// The live split line pinned above Save: muted while it adds up, in the
/// owe colour (with a warning icon) when it doesn't.
class _SplitSummary extends StatelessWidget {
  const _SplitSummary({required this.text, required this.ok});

  final String text;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok ? squadMuted : AppColors.accent700;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: ok ? AppColors.surface : AppColors.accent100,
        borderRadius: AppRadius.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ok ? Icons.calculate_outlined : Icons.error_outline_rounded, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: AppTextStyles.body(size: 12, color: color, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

/// When a monthly expense is charged: the day (1–28, or the last day) and,
/// for a new one, whether it starts this month or next.
class _MonthlyPicker extends StatelessWidget {
  const _MonthlyPicker({
    required this.firstMonthSet,
    required this.chargeDay,
    required this.startNextMonth,
    required this.onChargeDay,
    required this.onStartNextMonth,
  });

  /// Editing one: no "from this month / next month".
  final bool firstMonthSet;
  final int chargeDay;
  final bool startNextMonth;
  final ValueChanged<int> onChargeDay;
  final ValueChanged<bool> onStartNextMonth;

  static String dayLabel(int day) => day == RecurringExpense.lastDay
      ? 'Last day'
      : '$day${switch (day) {
          1 || 21 => 'st',
          2 || 22 => 'nd',
          3 || 23 => 'rd',
          _ => 'th',
        }}';

  @override
  Widget build(BuildContext context) {
    final box = BoxDecoration(
      color: AppColors.bg,
      borderRadius: AppRadius.sm,
      border: Border.all(color: AppColors.text.withValues(alpha: 0.18)),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
      decoration: box,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.autorenew_rounded, size: 20, color: oweColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Charged every month',
                      style: AppTextStyles.body(size: 14, weight: FontWeight.w700),
                    ),
                    Text(
                      'A subscription, like a family plan: charged to the squad each month.',
                      style: AppTextStyles.body(size: 11.5, color: squadMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('Charged on the', style: AppTextStyles.body(size: 13, color: AppColors.text)),
              const SizedBox(width: 8),
              DropdownButton<int>(
                key: const ValueKey('charge-day'),
                value: chargeDay,
                underline: const SizedBox.shrink(),
                // Dark on the light box (the theme's would be white).
                style: AppTextStyles.body(
                  size: 13.5,
                  weight: FontWeight.w700,
                  color: AppColors.text,
                ),
                dropdownColor: AppColors.card,
                iconEnabledColor: AppColors.text,
                items: [
                  for (final day in [...List.generate(28, (i) => i + 1), RecurringExpense.lastDay])
                    DropdownMenuItem(value: day, child: Text(dayLabel(day))),
                ],
                onChanged: (day) => day == null ? null : onChargeDay(day),
              ),
              if (!firstMonthSet) ...[
                const Spacer(),
                DropdownButton<bool>(
                  value: startNextMonth,
                  underline: const SizedBox.shrink(),
                  style: AppTextStyles.body(
                    size: 13.5,
                    weight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                  dropdownColor: AppColors.card,
                  iconEnabledColor: AppColors.text,
                  items: const [
                    DropdownMenuItem(value: false, child: Text('from this month')),
                    DropdownMenuItem(value: true, child: Text('from next month')),
                  ],
                  onChanged: (next) => next == null ? null : onStartNextMonth(next),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// A receipt or slip photo: add one, or see the one attached with Change
/// and Remove. Optional; everyone in the squad can open it.
class _ReceiptPicker extends StatelessWidget {
  const _ReceiptPicker({
    required this.picked,
    required this.savedPath,
    required this.onPick,
    required this.onRemove,
  });

  /// Chosen now, not saved yet.
  final PickedImage? picked;

  /// Already on the expense.
  final String? savedPath;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final picked = this.picked;
    final savedPath = this.savedPath;
    if (picked == null && savedPath == null) {
      return OutlinedButton.icon(
        onPressed: onPick,
        icon: const Icon(Icons.receipt_long_outlined, size: 18),
        label: Text(
          'Add receipt or slip (optional)',
          style: AppTextStyles.body(size: 13.5, weight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          alignment: Alignment.centerLeft,
          minimumSize: const Size.fromHeight(46),
          side: BorderSide(color: AppColors.text.withValues(alpha: 0.18)),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.sm),
        ),
      );
    }
    return Row(
      children: [
        ClipRRect(
          borderRadius: AppRadius.sm,
          child: SizedBox(
            width: 52,
            height: 52,
            child: picked != null
                ? Image.memory(picked.bytes, fit: BoxFit.cover)
                : WalletImage(kind: WalletImageKind.paymentSlip, path: savedPath!),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            picked != null ? 'New photo — saved with the expense' : 'Attached',
            style: AppTextStyles.body(size: 13, weight: FontWeight.w600),
          ),
        ),
        TextButton(onPressed: onPick, child: const Text('Change')),
        TextButton(onPressed: onRemove, child: const Text('Remove')),
      ],
    );
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
  const _Field({super.key, required this.controller, required this.hint});

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
}

class _PayerButton extends StatelessWidget {
  const _PayerButton({
    required this.name,
    required this.initial,
    required this.onTap,
    this.photoUrl,
  });

  final String name;
  final String initial;
  final String? photoUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bg,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.sm,
        side: BorderSide(color: AppColors.text.withValues(alpha: 0.18)),
      ),
      child: InkWell(
        borderRadius: AppRadius.sm,
        onTap: onTap,
        child: SizedBox(
          height: 46,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                SquadAvatar(
                  initial: initial,
                  size: 26,
                  color: AppColors.teamGold,
                  photoUrl: photoUrl,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(size: 14, weight: FontWeight.w600),
                  ),
                ),
                Icon(Icons.expand_more_rounded, size: 18, color: squadMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Equal · Chosen · Exact · Custom · Treat, as a segmented control.
class _ModeTabs extends StatelessWidget {
  const _ModeTabs({required this.mode, required this.onChanged});

  final ExpenseSplitMode mode;
  final ValueChanged<ExpenseSplitMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.lg),
      child: Row(
        children: [
          for (final option in ExpenseSplitMode.values)
            Expanded(
              child: Semantics(
                selected: option == mode,
                button: true,
                child: Material(
                  color: option == mode ? AppColors.card : Colors.transparent,
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
    this.photoUrl,
    required this.mode,
    required this.included,
    required this.onToggle,
    required this.exactController,
    required this.amount,
    required this.sub,
    this.fieldKey,
    this.onRemove,
  });

  final Key? fieldKey;

  /// Shown as an ✕ (a guest can be taken out).
  final VoidCallback? onRemove;

  final String name;
  final String initial;
  final String? photoUrl;
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
          if (mode == ExpenseSplitMode.chosen || mode == ExpenseSplitMode.custom)
            Checkbox(
              value: included,
              onChanged: (_) => onToggle?.call(),
              activeColor: AppColors.accentFill,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.xs),
              semanticLabel: 'Include $name',
            ),
          SquadAvatar(initial: initial, size: 30, photoUrl: photoUrl),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.body(size: 14, weight: FontWeight.w600, color: nameColor),
                ),
                // A guest's note (who covers them) sits under the name.
                if (onRemove != null && sub.isNotEmpty)
                  Text(sub, style: AppTextStyles.body(size: 11, color: squadMuted, height: 1.3)),
              ],
            ),
          ),
          if (exactController != null)
            SizedBox(
              width: 96,
              child: Semantics(
                label: '$name share',
                child: TextField(
                  key: fieldKey,
                  controller: exactController,
                  textAlign: TextAlign.right,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: const [MoneyInputFormatter()],
                  style: AppTextStyles.body(size: 14, weight: FontWeight.w800),
                  decoration: InputDecoration(
                    hintText: '0',
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.bg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.sm,
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
                Text(amount, style: AppTextStyles.title(size: 17, color: nameColor, height: 1.2)),
                if (sub.isNotEmpty && onRemove == null)
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
          if (onRemove case final onRemove?)
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded, size: 18),
              tooltip: 'Remove $name',
              visualDensity: VisualDensity.compact,
              color: squadMuted,
            ),
        ],
      ),
    );
  }
}

/// Someone outside the squad in this split, by a key that stands in for a
/// profile id while splitting.
class _Guest {
  const _Guest({required this.key, required this.name, this.hostId});

  final String key;
  final String name;

  /// The member covering them; null = no one (the payer collects it).
  final String? hostId;
}

/// "Add guest": their name, and who covers their share.
class _GuestDialog extends StatefulWidget {
  const _GuestDialog({
    required this.members,
    required this.me,
    required this.ledger,
    required this.newKey,
  });

  final List<SquadMember> members;
  final String me;
  final SquadLedger ledger;
  final String Function() newKey;

  @override
  State<_GuestDialog> createState() => _GuestDialogState();
}

class _GuestDialogState extends State<_GuestDialog> {
  final _name = TextEditingController();

  /// Null = no one covers them.
  String? _hostId;

  @override
  void initState() {
    super.initState();
    _hostId = widget.me;
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = _name.text.trim();
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: const Text('Add guest'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Someone outside the squad. They're in the split, but have no account.",
            style: AppTextStyles.body(size: 12.5, color: squadMuted),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('guest-name'),
            controller: _name,
            autofocus: true,
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name', counterText: ''),
          ),
          const SizedBox(height: 12),
          Text('WHO COVERS THEIR SHARE', style: AppTextStyles.label(color: squadMuted)),
          DropdownButton<String?>(
            key: const ValueKey('guest-host'),
            isExpanded: true,
            style: AppTextStyles.body(size: 14, weight: FontWeight.w600, color: AppColors.text),
            dropdownColor: AppColors.card,
            iconEnabledColor: AppColors.text,
            value: _hostId,
            items: [
              for (final member in widget.members)
                DropdownMenuItem(
                  value: member.profileId,
                  child: Text(widget.ledger.nameOf(member.profileId, me: widget.me)),
                ),
              const DropdownMenuItem(value: null, child: Text('No one — they pay the payer')),
            ],
            onChanged: (id) => setState(() => _hostId = id),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(
          onPressed: name.isEmpty
              ? null
              : () =>
                    Navigator.of(context)
                        .pop(_Guest(key: widget.newKey(), name: name, hostId: _hostId)),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
