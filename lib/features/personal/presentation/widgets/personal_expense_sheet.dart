import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/widgets/money_input_formatter.dart';
import '../../../../core/theme/widgets/sticky_action_sheet.dart';
import '../../../squad/presentation/squad_formatting.dart';
import '../../../squad/presentation/widgets/sheet_parts.dart';
import '../../../squad/presentation/widgets/squad_widgets.dart';
import '../../../wallet/presentation/widgets/wallet_image_actions.dart';
import '../../domain/entities/personal_expense.dart';
import '../../domain/repositories/personal_repository.dart';
import '../cubit/personal_spending_cubit.dart';
import '../personal_formatting.dart';

/// "Add personal expense" (or edit [editing]): something you spent, only
/// for you. Never part of any squad's balance.
Future<void> showPersonalExpenseSheet(BuildContext context, {PersonalExpense? editing}) {
  // Fresh categories and currency each time (it's shared app-wide).
  final cubit = sl<PersonalSpendingCubit>()..load();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _PersonalExpenseSheet(editing: editing),
    ),
  );
}

class _PersonalExpenseSheet extends StatefulWidget {
  const _PersonalExpenseSheet({this.editing});

  final PersonalExpense? editing;

  @override
  State<_PersonalExpenseSheet> createState() => _PersonalExpenseSheetState();
}

class _PersonalExpenseSheetState extends State<_PersonalExpenseSheet> {
  late final _amount = TextEditingController(
    text: widget.editing == null ? '' : moneyInput(widget.editing!.amountCents),
  );
  late final _title = TextEditingController(text: widget.editing?.title ?? '');
  late final _note = TextEditingController(text: widget.editing?.note ?? '');

  /// A [PersonalExpense.categoryKey]: a built-in's name or `custom:<id>`.
  late String _categoryKey = widget.editing?.categoryKey ?? PersonalCategory.food.name;

  late DateTime _spentAt = widget.editing?.spentAt.toLocal() ?? DateTime.now();

  PickedImage? _receipt;
  bool _removeReceipt = false;

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _spentAt,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    // Keep the time of day it was added.
    setState(
      () => _spentAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _spentAt.hour,
        _spentAt.minute,
      ),
    );
  }

  Future<void> _newCategory() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NewCategoryDialog(),
    );
    if (name == null || !mounted) return;
    final category = await context.read<PersonalSpendingCubit>().addCategory(name);
    if (category != null && mounted) setState(() => _categoryKey = 'custom:${category.id}');
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
    final amount = parseMoney(_amount.text) ?? 0;
    final title = _title.text.trim();
    if (amount <= 0) return _snack('Enter an amount');
    if (title.isEmpty) return _snack('Add a title');
    final customId = _categoryKey.startsWith('custom:')
        ? _categoryKey.substring('custom:'.length)
        : null;
    final saved = await context.read<PersonalSpendingCubit>().save(
      PersonalExpenseDraft(
        id: widget.editing?.id,
        title: title,
        amountCents: amount,
        spentAt: _spentAt,
        category: customId == null
            ? PersonalCategory.values.byName(_categoryKey)
            : PersonalCategory.custom,
        customCategoryId: customId,
        note: _note.text,
        receiptBytes: _receipt?.bytes,
        receiptExtension: _receipt?.fileExtension,
        previousReceiptPath: widget.editing?.receiptPath,
        removeReceipt: _removeReceipt,
      ),
    );
    if (saved && mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final editing = widget.editing!;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Delete this expense?'),
        content: Text('“${editing.title}” and its receipt photo are deleted for good.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    final deleted = await context.read<PersonalSpendingCubit>().delete(editing);
    if (deleted && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PersonalSpendingCubit, PersonalSpendingState>(
      listenWhen: (previous, current) => current.error != null && previous.error != current.error,
      listener: (context, state) => _snack(state.error!),
      builder: (context, state) {
        final spending = state.spending ?? PersonalSpending.empty;
        final currency = spending.currency;
        return StickyActionSheet(
          background: AppColors.card,
          maxHeightFactor: 1,
          summary: Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: 15, color: squadMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Only you can see this. It never changes a squad balance.',
                  style: AppTextStyles.body(size: 12, color: squadMuted),
                ),
              ),
            ],
          ),
          action: SquadPrimaryButton(
            label: widget.editing == null ? 'Save personal expense' : 'Save changes',
            isLoading: state.saving,
            onPressed: state.saving ? null : _save,
          ),
          children: [
            const SheetGrabber(),
            SheetHeader(
              title: widget.editing == null ? 'Add personal expense' : 'Edit personal expense',
              actions: [
                if (widget.editing != null)
                  IconButton(
                    onPressed: state.saving ? null : _delete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    tooltip: 'Delete',
                  ),
              ],
            ),
            const SizedBox(height: 4),
            _AmountField(
              controller: _amount,
              symbol: currency.symbol,
              autofocus: widget.editing == null,
            ),
            const SizedBox(height: 16),
            LabeledField(
              label: 'WHAT FOR',
              child: _Field(
                key: const ValueKey('personal-title'),
                controller: _title,
                hint: 'e.g. Lunch',
                maxLength: 80,
              ),
            ),
            const SizedBox(height: 16),
            LabeledField(
              label: 'CATEGORY',
              child: CategoryGrid<String>(
                options: [
                  for (final (key, label) in [
                    for (final category in PersonalCategory.builtIn) (category.name, category.label),
                    for (final category in spending.categories) ('custom:${category.id}', category.name),
                  ])
                    (
                      value: key,
                      label: label,
                      icon: personalCategoryIcon(key),
                      background: personalCategoryTone(key).background,
                      foreground: personalCategoryTone(key).foreground,
                    ),
                ],
                selected: _categoryKey,
                onSelected: (key) => setState(() => _categoryKey = key),
                onAdd: _newCategory,
              ),
            ),
            const SizedBox(height: 16),
            LabeledField(
              label: 'DATE',
              child: OutlinedButton.icon(
                key: const ValueKey('personal-date'),
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(
                  formatDayLabel(_spentAt),
                  style: AppTextStyles.body(size: 14, weight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.text,
                  alignment: Alignment.centerLeft,
                  minimumSize: const Size.fromHeight(46),
                  side: BorderSide(color: AppColors.text.withValues(alpha: 0.18)),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.sm),
                ),
              ),
            ),
            const SizedBox(height: 16),
            LabeledField(
              label: 'RECEIPT',
              child: ReceiptPicker(
                label: 'Add receipt photo (optional)',
                picked: _receipt,
                savedPath: _removeReceipt ? null : widget.editing?.receiptPath,
                onPick: _pickReceipt,
                onRemove: () => setState(() {
                  _receipt = null;
                  _removeReceipt = widget.editing?.receiptPath != null;
                }),
              ),
            ),
            const SizedBox(height: 16),
            LabeledField(
              label: 'NOTES',
              child: _Field(
                key: const ValueKey('personal-note'),
                controller: _note,
                hint: 'Anything to remember (optional)',
                maxLength: 500,
                maxLines: 4,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The big amount, underlined, with the currency symbol.
class _AmountField extends StatelessWidget {
  const _AmountField({required this.controller, required this.symbol, required this.autofocus});

  final TextEditingController controller;
  final String symbol;
  final bool autofocus;

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
                key: const ValueKey('personal-amount'),
                controller: controller,
                autofocus: autofocus,
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

/// "New category": a name of up to 30 characters.
class _NewCategoryDialog extends StatefulWidget {
  const _NewCategoryDialog();

  @override
  State<_NewCategoryDialog> createState() => _NewCategoryDialogState();
}

class _NewCategoryDialogState extends State<_NewCategoryDialog> {
  final _name = TextEditingController();

  @override
  void initState() {
    super.initState();
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
      title: const Text('New category'),
      content: TextField(
        key: const ValueKey('category-name'),
        controller: _name,
        autofocus: true,
        maxLength: 30,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Name, e.g. Coffee', counterText: ''),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(
          onPressed: name.isEmpty ? null : () => Navigator.of(context).pop(name),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
