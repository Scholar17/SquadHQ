import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/widgets/money_input_formatter.dart';
import '../../../wallet/domain/repositories/wallet_repository.dart' show WalletImageKind;
import '../../../wallet/presentation/widgets/wallet_image.dart';
import '../../../wallet/presentation/widgets/wallet_image_actions.dart';
import '../../domain/entities/expense.dart' show ExpenseSplitMode;
import '../../domain/entities/settlement.dart' show SettlementMethod;
import '../../domain/entities/squad_member.dart';
import '../squad_formatting.dart' show moneyInput, parseMoney;
import 'squad_widgets.dart';

// The building blocks the expense and pay sheets share — squad, trip and
// buddy alike — so every money sheet looks and behaves the same.

/// The handle at the top of a bottom sheet.
class SheetGrabber extends StatelessWidget {
  const SheetGrabber({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: AppColors.neutral400,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// A sheet's title row: an optional [leading] (e.g. an avatar), the
/// [title], any [actions] and a close button.
class SheetHeader extends StatelessWidget {
  const SheetHeader({super.key, required this.title, this.leading, this.actions = const []});

  final String title;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final leading = this.leading;
    return Row(
      children: [
        if (leading != null) ...[leading, const SizedBox(width: 10)],
        Expanded(child: Text(title, style: AppTextStyles.heading(size: 20))),
        ...actions,
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
        ),
      ],
    );
  }
}

/// A small caps label over its field.
class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.label, required this.child});

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

/// A one-of-a-few choice as a segmented control: the picked one raised
/// on a soft track. [expand] shares the width evenly; otherwise the
/// options wrap onto a second line on a narrow phone.
class SegmentedTabs<T> extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.options,
    required this.selected,
    required this.label,
    required this.onChanged,
    this.icon,
    this.keyOf,
    this.expand = false,
  });

  final List<T> options;
  final T selected;
  final String Function(T option) label;
  final IconData Function(T option)? icon;

  /// A key for an option's tab, for tests.
  final Key? Function(T option)? keyOf;
  final ValueChanged<T> onChanged;
  final bool expand;

  Widget _tab(T option) {
    final picked = option == selected;
    final color = picked ? AppColors.text : squadMuted;
    final icon = this.icon?.call(option);
    return Semantics(
      key: keyOf?.call(option),
      selected: picked,
      button: true,
      child: Material(
        color: picked ? AppColors.card : Colors.transparent,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => onChanged(option),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: SizedBox(
              height: 38,
              child: Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[Icon(icon, size: 16, color: color), const SizedBox(width: 6)],
                  Flexible(
                    child: Text(
                      label(option),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body(size: 13, weight: FontWeight.w700, color: color),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.lg),
      child: expand
          ? Row(children: [for (final option in options) Expanded(child: _tab(option))])
          : Wrap(spacing: 2, runSpacing: 2, children: [for (final option in options) _tab(option)]),
    );
  }
}

/// QR · Bank · Cash.
class PaymentMethodTabs extends StatelessWidget {
  const PaymentMethodTabs({super.key, required this.method, required this.onChanged});

  final SettlementMethod method;
  final ValueChanged<SettlementMethod> onChanged;

  static IconData iconOf(SettlementMethod method) => switch (method) {
    SettlementMethod.qr => Icons.qr_code_2_rounded,
    SettlementMethod.bank => Icons.account_balance_outlined,
    SettlementMethod.cash => Icons.payments_outlined,
  };

  @override
  Widget build(BuildContext context) => SegmentedTabs<SettlementMethod>(
    options: SettlementMethod.values,
    selected: method,
    label: (option) => option.label,
    icon: iconOf,
    onChanged: onChanged,
    expand: true,
  );
}

/// Live "Ko owes you ฿150" under a split, red when the split doesn't add up.
class SplitSummaryBox extends StatelessWidget {
  const SplitSummaryBox({super.key, required this.text, required this.ok});

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

/// The receipt on an expense: a button to add one, or its thumbnail with
/// Change and Remove.
class ReceiptPicker extends StatelessWidget {
  const ReceiptPicker({
    super.key,
    required this.picked,
    required this.savedPath,
    required this.onPick,
    required this.onRemove,
    this.label = 'Add receipt or slip (optional)',
  });

  /// Chosen now, not saved yet.
  final PickedImage? picked;

  /// Already on the expense.
  final String? savedPath;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  final String label;

  @override
  Widget build(BuildContext context) {
    final picked = this.picked;
    final savedPath = this.savedPath;
    if (picked == null && savedPath == null) {
      return OutlinedButton.icon(
        onPressed: onPick,
        icon: const Icon(Icons.receipt_long_outlined, size: 18),
        label: Text(label, style: AppTextStyles.body(size: 13.5, weight: FontWeight.w700)),
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

/// Their wallet QR, tap to enlarge, with a caption and Save QR.
class WalletQrPanel extends StatelessWidget {
  const WalletQrPanel({super.key, required this.path, required this.caption});

  final String path;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Their wallet QR code',
          button: true,
          child: GestureDetector(
            onTap: () => showWalletImageViewer(
              context,
              kind: WalletImageKind.walletQr,
              path: path,
              title: 'Wallet QR',
            ),
            child: Container(
              width: 132,
              height: 132,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppRadius.md,
                border: Border.all(color: AppColors.text.withValues(alpha: 0.1)),
              ),
              child: WalletImage(kind: WalletImageKind.walletQr, path: path),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(caption, style: AppTextStyles.body(size: 13, color: squadMuted)),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => saveWalletQr(context, path),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Save QR'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.text,
                  minimumSize: const Size(0, 44),
                  side: BorderSide(color: AppColors.text.withValues(alpha: 0.2)),
                  shape: const StadiumBorder(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// [member]'s bank, account name and number, each with a copy button.
class BankDetailsPanel extends StatelessWidget {
  const BankDetailsPanel({super.key, required this.member});

  final SquadMember member;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Bank', member.bankName),
      ('Name', member.bankAccountName),
      ('Account', member.bankAccountNo),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: AppRadius.md),
      child: Column(
        children: [
          for (final (label, value) in rows)
            if ((value ?? '').isNotEmpty)
              Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(label, style: AppTextStyles.body(size: 12.5, color: squadMuted)),
                  ),
                  Expanded(
                    child: Text(
                      value!,
                      style: AppTextStyles.body(size: 14, weight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy ${label.toLowerCase()}',
                    icon: Icon(Icons.copy_rounded, size: 18, color: AppColors.accent700),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(SnackBar(content: Text('$label copied')));
                    },
                  ),
                ],
              ),
        ],
      ),
    );
  }
}

/// A quiet note in a sheet — what's missing, or what to do next.
class SheetNotice extends StatelessWidget {
  const SheetNotice(this.text, {super.key, this.icon = Icons.info_outline_rounded});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: AppRadius.md),
      child: Row(
        children: [
          Icon(icon, color: squadMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: AppTextStyles.body(size: 13, color: squadMuted)),
          ),
        ],
      ),
    );
  }
}

/// "Add payment slip" — or its thumbnail and Change once picked.
class SlipPickerButton extends StatelessWidget {
  const SlipPickerButton({
    super.key,
    required this.slip,
    required this.onPick,
    this.label = 'Add payment slip',
  });

  final PickedImage? slip;
  final VoidCallback onPick;
  final String label;

  @override
  Widget build(BuildContext context) {
    final picked = slip;
    return Material(
      color: AppColors.bg,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.md,
        side: BorderSide(color: AppColors.neutral500),
      ),
      child: InkWell(
        borderRadius: AppRadius.md,
        onTap: onPick,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              if (picked != null)
                ClipRRect(
                  borderRadius: AppRadius.xs,
                  child: Image.memory(picked.bytes, width: 44, height: 44, fit: BoxFit.cover),
                )
              else
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(Icons.receipt_long_outlined, color: squadMuted),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  picked == null ? label : 'Slip added',
                  style: AppTextStyles.body(size: 14, weight: FontWeight.w700),
                ),
              ),
              Text(
                picked == null ? 'Choose' : 'Change',
                style: AppTextStyles.body(
                  size: 13,
                  weight: FontWeight.w700,
                  color: AppColors.accent700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A percent or shares box with − and + either side: 10% a tap for
/// [percent] (up to 100%), 1 share a tap otherwise — never below 0. The
/// box still takes a typed value (e.g. 33.33).
class WeightStepper extends StatelessWidget {
  const WeightStepper({
    super.key,
    required this.controller,
    required this.percent,
    required this.name,
    this.fieldKey,
    this.fill,
  });

  final TextEditingController controller;
  final bool percent;

  /// Whose it is, for screen readers: "Ko percent", "Increase Ko".
  final String name;
  final Key? fieldKey;
  final Color? fill;

  /// A tap's worth, in hundredths: 10% or 1 share.
  int get _step => percent ? 1000 : 100;

  void _nudge(int direction) {
    final now = parseMoney(controller.text) ?? 0;
    var next = now + direction * _step;
    if (next < 0) next = 0;
    if (percent && next > 10000) next = 10000;
    if (next == now) return;
    controller.text = next == 0 ? '0' : moneyInput(next);
  }

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: AppRadius.sm,
      borderSide: BorderSide(color: AppColors.text.withValues(alpha: 0.18)),
    );
    final unit = percent ? '10%' : '1 share';
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final now = parseMoney(value.text) ?? 0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StepButton(
              icon: Icons.remove_rounded,
              tooltip: 'Decrease $name by $unit',
              onPressed: now > 0 ? () => _nudge(-1) : null,
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 64,
              child: Semantics(
                label: percent ? '$name percent' : '$name shares',
                child: TextField(
                  key: fieldKey,
                  controller: controller,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: const [MoneyInputFormatter()],
                  style: AppTextStyles.body(size: 14, weight: FontWeight.w800),
                  decoration: InputDecoration(
                    hintText: '0',
                    suffixText: percent ? '%' : '×',
                    isDense: true,
                    filled: true,
                    fillColor: fill ?? AppColors.bg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
                    border: border,
                    enabledBorder: border,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            _StepButton(
              icon: Icons.add_rounded,
              tooltip: 'Increase $name by $unit',
              onPressed: percent && now >= 10000 ? null : () => _nudge(1),
            ),
          ],
        );
      },
    );
  }
}

/// A small round − or + by a [WeightStepper]; greyed out at its limit.
class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    tooltip: tooltip,
    icon: Icon(icon, size: 18),
    style: IconButton.styleFrom(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.text,
      disabledBackgroundColor: AppColors.surface.withValues(alpha: 0.5),
      disabledForegroundColor: squadMuted.withValues(alpha: 0.5),
      minimumSize: const Size(32, 32),
      fixedSize: const Size(32, 32),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  );
}

/// A split type's icon in [SplitTypeGrid]. Exact is "123": you type each
/// amount (no currency sign, so it fits any squad's currency).
IconData splitModeIcon(ExpenseSplitMode mode) => switch (mode) {
  ExpenseSplitMode.equal => Icons.balance_rounded,
  ExpenseSplitMode.chosen => Icons.group_outlined,
  ExpenseSplitMode.exact => Icons.onetwothree_rounded,
  ExpenseSplitMode.custom => Icons.tune_rounded,
  ExpenseSplitMode.percent => Icons.percent_rounded,
  ExpenseSplitMode.shares => Icons.pie_chart_outline_rounded,
  ExpenseSplitMode.treat => Icons.card_giftcard_rounded,
  ExpenseSplitMode.borrow => Icons.handshake_outlined,
};

/// How an expense is split, as icon tiles like [CategoryGrid] — all in
/// one calm tone, the picked one ringed.
class SplitTypeGrid extends StatelessWidget {
  const SplitTypeGrid({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<ExpenseSplitMode> options;
  final ExpenseSplitMode selected;
  final ValueChanged<ExpenseSplitMode> onSelected;

  @override
  Widget build(BuildContext context) => CategoryGrid<ExpenseSplitMode>(
    options: [
      for (final mode in options)
        (
          value: mode,
          label: mode.label,
          icon: splitModeIcon(mode),
          background: AppColors.surface,
          foreground: AppColors.accent700,
        ),
    ],
    selected: selected,
    onSelected: onSelected,
  );
}

/// One choice in a [CategoryGrid]: its colour tile and name.
typedef CategoryOption<T> = ({T value, String label, IconData icon, Color background, Color foreground});

/// Categories as a grid of small colour tiles with the name under each —
/// the picked one ringed in its colour. [onAdd] adds a dashed "+" tile at
/// the end (e.g. "New category").
class CategoryGrid<T> extends StatelessWidget {
  const CategoryGrid({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.onAdd,
    this.addLabel = 'New category',
    this.icons = true,
  });

  final List<CategoryOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final VoidCallback? onAdd;
  final String addLabel;

  /// False: text-only colour pills (categories) in place of icon tiles.
  final bool icons;

  static const _spacing = 6.0;

  @override
  Widget build(BuildContext context) {
    final onAdd = this.onAdd;
    if (!icons) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in options)
            _CategoryPill(
              label: option.label,
              picked: option.value == selected,
              onTap: () => onSelected(option.value),
              background: option.background,
              foreground: option.foreground,
            ),
          if (onAdd != null)
            _CategoryPill(
              label: addLabel,
              picked: false,
              onTap: onAdd,
              background: Colors.transparent,
              foreground: AppColors.accent700,
              outlined: true,
            ),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // Five across on a phone, more on a wider sheet; never cramped.
        final perRow = ((constraints.maxWidth + _spacing) / (64 + _spacing)).floor().clamp(4, 7);
        final width = (constraints.maxWidth - _spacing * (perRow - 1)) / perRow;
        return Wrap(
          spacing: _spacing,
          runSpacing: 10,
          children: [
            for (final option in options)
              _CategoryCell(
                width: width,
                label: option.label,
                picked: option.value == selected,
                onTap: () => onSelected(option.value),
                tile: Icon(option.icon, size: 22, color: option.foreground),
                background: option.background,
                ring: option.foreground,
              ),
            if (onAdd != null)
              _CategoryCell(
                width: width,
                label: addLabel,
                picked: false,
                onTap: onAdd,
                tile: Icon(Icons.add_rounded, size: 22, color: AppColors.accent700),
                background: Colors.transparent,
                ring: AppColors.accent700,
                outlined: true,
              ),
          ],
        );
      },
    );
  }
}

/// A category as a colour pill with just its name — the picked one ringed
/// in its colour.
class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.label,
    required this.picked,
    required this.onTap,
    required this.background,
    required this.foreground,
    this.outlined = false,
  });

  final String label;
  final bool picked;
  final VoidCallback onTap;
  final Color background;
  final Color foreground;

  /// The "+ New category" pill: a thin outline in place of a fill.
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final animate = !MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      selected: picked,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: AnimatedContainer(
          duration: animate ? const Duration(milliseconds: 160) : Duration.zero,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: ShapeDecoration(
            color: background,
            shape: StadiumBorder(
              side: BorderSide(
                color: picked
                    ? foreground
                    : outlined
                    ? foreground.withValues(alpha: 0.45)
                    : Colors.transparent,
                width: picked ? 2 : 1.5,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (outlined) ...[Icon(Icons.add_rounded, size: 16, color: foreground), const SizedBox(width: 4)],
              Text(
                label,
                style: AppTextStyles.body(
                  size: 13,
                  weight: picked ? FontWeight.w800 : FontWeight.w600,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCell extends StatelessWidget {
  const _CategoryCell({
    required this.width,
    required this.label,
    required this.picked,
    required this.onTap,
    required this.tile,
    required this.background,
    required this.ring,
    this.outlined = false,
  });

  final double width;
  final String label;
  final bool picked;
  final VoidCallback onTap;
  final Widget tile;
  final Color background;
  final Color ring;

  /// The "+" tile: a thin outline in place of a fill.
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final animate = !MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      selected: picked,
      child: SizedBox(
        width: width,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.md,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: animate ? const Duration(milliseconds: 160) : Duration.zero,
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: AppRadius.md,
                    border: Border.all(
                      color: picked
                          ? ring
                          : outlined
                          ? ring.withValues(alpha: 0.45)
                          : Colors.transparent,
                      width: picked ? 2.5 : 1.5,
                    ),
                  ),
                  child: Center(child: tile),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(
                    size: 11.5,
                    height: 1.2,
                    weight: picked ? FontWeight.w800 : FontWeight.w600,
                    color: picked ? AppColors.text : outlined ? AppColors.accent700 : squadMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
