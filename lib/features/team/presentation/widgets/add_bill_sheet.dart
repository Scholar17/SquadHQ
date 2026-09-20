import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/team_snapshot.dart';
import '../bloc/team_bloc.dart';
import '../bloc/team_event.dart';

/// Opened from the wallet tab's "+ Add bill" button — manager-only.
/// Splits rent/water/other costs equally across the roster, letting the
/// manager exclude players, fix a custom amount per player, or have one
/// player cover someone else's share.
Future<void> showAddBillSheet(
  BuildContext context, {
  required List<SquadMember> roster,
}) {
  final teamBloc = context.read<TeamBloc>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => BlocProvider.value(
      value: teamBloc,
      child: _AddBillSheet(roster: roster),
    ),
  );
}

class _AddBillSheet extends StatefulWidget {
  const _AddBillSheet({required this.roster});

  final List<SquadMember> roster;

  @override
  State<_AddBillSheet> createState() => _AddBillSheetState();
}

class _AddBillSheetState extends State<_AddBillSheet> {
  final _rentController = TextEditingController();
  final _waterController = TextEditingController();
  final _extraController = TextEditingController();
  final _extraLabelController = TextEditingController(text: 'Other');

  final Set<String> _excludedIds = {};
  final Set<String> _customIds = {};
  final Map<String, TextEditingController> _customControllers = {};

  String? _payerId;
  final Set<String> _coveredIds = {};

  @override
  void initState() {
    super.initState();
    for (final controller in [_rentController, _waterController, _extraController]) {
      controller.addListener(_refresh);
    }
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _rentController.dispose();
    _waterController.dispose();
    _extraController.dispose();
    _extraLabelController.dispose();
    for (final controller in _customControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _customControllerFor(String id) =>
      _customControllers.putIfAbsent(id, () => TextEditingController()..addListener(_refresh));

  double _num(TextEditingController controller) => double.tryParse(controller.text.trim()) ?? 0;

  double get _total => _num(_rentController) + _num(_waterController) + _num(_extraController);

  List<SquadMember> get _participants =>
      widget.roster.where((member) => !_excludedIds.contains(member.id)).toList();

  /// Equal split with per-player exceptions folded in, before any player
  /// covers someone else's share.
  Map<String, double> _computeShares() {
    final total = _total;
    final participants = _participants;
    if (total <= 0 || participants.isEmpty) return {};

    final shares = <String, double>{};
    var remaining = total;
    for (final member in participants) {
      if (_customIds.contains(member.id)) {
        final amount = _num(_customControllerFor(member.id));
        shares[member.id] = amount;
        remaining -= amount;
      }
    }

    final pool = participants.where((member) => !_customIds.contains(member.id)).toList();
    if (pool.isNotEmpty) {
      final base = (remaining / pool.length * 100).round() / 100;
      var distributed = 0.0;
      for (var i = 0; i < pool.length; i++) {
        final amount = i == pool.length - 1 ? remaining - distributed : base;
        shares[pool[i].id] = amount < 0 ? 0 : amount;
        distributed += amount;
      }
    }

    if (_payerId != null && participants.any((member) => member.id == _payerId)) {
      var absorbed = 0.0;
      for (final id in _coveredIds) {
        if (!participants.any((member) => member.id == id)) continue;
        absorbed += shares[id] ?? 0;
        shares[id] = 0;
      }
      if (absorbed > 0) {
        shares[_payerId!] = (shares[_payerId!] ?? 0) + absorbed;
      }
    }

    return shares;
  }

  void _toggleIncluded(String id) {
    setState(() {
      if (_excludedIds.contains(id)) {
        _excludedIds.remove(id);
      } else {
        _excludedIds.add(id);
        _customIds.remove(id);
        _coveredIds.remove(id);
        if (_payerId == id) _payerId = null;
      }
    });
  }

  void _toggleCustom(String id, double currentShare) {
    setState(() {
      if (_customIds.contains(id)) {
        _customIds.remove(id);
      } else {
        _customIds.add(id);
        _coveredIds.remove(id);
        final controller = _customControllerFor(id);
        if (controller.text.trim().isEmpty) {
          controller.text = currentShare.toStringAsFixed(0);
        }
      }
    });
  }

  void _toggleCovered(String id) {
    setState(() {
      if (_coveredIds.contains(id)) {
        _coveredIds.remove(id);
      } else {
        _coveredIds.add(id);
      }
    });
  }

  void _setPayer(String? id) {
    setState(() {
      _payerId = id;
      if (id != null) _coveredIds.remove(id);
    });
  }

  SquadMember? get _payer {
    final id = _payerId;
    if (id == null) return null;
    for (final member in widget.roster) {
      if (member.id == id) return member;
    }
    return null;
  }

  bool get _isValid => _total > 0 && _participants.isNotEmpty;

  void _save() {
    if (!_isValid) return;
    final shares = _computeShares();
    if (shares.isEmpty) return;
    context.read<TeamBloc>().add(
          TeamBillSplit(
            rentFee: _num(_rentController),
            waterFee: _num(_waterController),
            additionalCost: _num(_extraController),
            additionalLabel:
                _extraLabelController.text.trim().isEmpty ? 'Other' : _extraLabelController.text.trim(),
            shares: shares,
          ),
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final shares = _computeShares();
    final payer = _payer;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Split a bill', style: AppTextStyles.heading(size: 18)),
              const SizedBox(height: 4),
              Text(
                'Rent, water, and any extra costs — split equally, with exceptions.',
                style: AppTextStyles.body(size: 12, color: AppColors.text.withValues(alpha: 0.55)),
              ),
              const SizedBox(height: 16),
              _MoneyField(controller: _rentController, label: 'Rent fee'),
              const SizedBox(height: 10),
              _MoneyField(controller: _waterController, label: 'Water fee'),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _MoneyField(controller: _extraController, label: 'Additional cost'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 50,
                      child: TextField(
                        controller: _extraLabelController,
                        decoration: _fieldDecoration('Label'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text('TOTAL', style: AppTextStyles.label(color: AppColors.text.withValues(alpha: 0.45))),
                  const Spacer(),
                  Text('฿${_total.toStringAsFixed(0)}', style: AppTextStyles.heading(size: 20)),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'SPLIT BETWEEN',
                      style: AppTextStyles.label(color: AppColors.text.withValues(alpha: 0.45)),
                    ),
                  ),
                  Text(
                    '${_participants.length} of ${widget.roster.length}',
                    style: AppTextStyles.body(size: 11, weight: FontWeight.w600, color: AppColors.accent700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.neutral100,
                  border: Border.all(color: AppColors.text.withValues(alpha: 0.1)),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < widget.roster.length; i++)
                      _SplitRow(
                        member: widget.roster[i],
                        showTopBorder: i > 0,
                        included: !_excludedIds.contains(widget.roster[i].id),
                        isCustom: _customIds.contains(widget.roster[i].id),
                        isCovered: _coveredIds.contains(widget.roster[i].id),
                        isPayer: _payerId == widget.roster[i].id,
                        coveredByName: _coveredIds.contains(widget.roster[i].id) ? payer?.name : null,
                        amount: shares[widget.roster[i].id] ?? 0,
                        amountController:
                            _customIds.contains(widget.roster[i].id) ? _customControllerFor(widget.roster[i].id) : null,
                        onToggleIncluded: () => _toggleIncluded(widget.roster[i].id),
                        onToggleCustom: () =>
                            _toggleCustom(widget.roster[i].id, shares[widget.roster[i].id] ?? 0),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text('PAY FOR OTHERS', style: AppTextStyles.label(color: AppColors.text.withValues(alpha: 0.45))),
              const SizedBox(height: 4),
              Text(
                "Have one player cover someone else's share — it moves onto their tab instead.",
                style: AppTextStyles.body(size: 11.5, color: AppColors.text.withValues(alpha: 0.55)),
              ),
              const SizedBox(height: 8),
              _PayerPicker(roster: _participants, payerId: _payerId, onChanged: _setPayer),
              if (_payerId != null) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final member in _participants)
                      if (member.id != _payerId)
                        _CoverChip(
                          label: member.name,
                          selected: _coveredIds.contains(member.id),
                          onTap: () => _toggleCovered(member.id),
                        ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isValid ? _save : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.bg,
                    disabledBackgroundColor: AppColors.text.withValues(alpha: 0.15),
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  child: Text(
                    'Split ฿${_total.toStringAsFixed(0)}',
                    style: AppTextStyles.heading(size: 14, color: AppColors.bg),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration _fieldDecoration(String hintText) => InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: AppColors.neutral100,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide(color: AppColors.text.withValues(alpha: 0.16)),
      ),
    );

class _MoneyField extends StatelessWidget {
  const _MoneyField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: _fieldDecoration(label).copyWith(prefixText: '฿ '),
      ),
    );
  }
}

class _SplitRow extends StatelessWidget {
  const _SplitRow({
    required this.member,
    required this.showTopBorder,
    required this.included,
    required this.isCustom,
    required this.isCovered,
    required this.isPayer,
    required this.coveredByName,
    required this.amount,
    required this.amountController,
    required this.onToggleIncluded,
    required this.onToggleCustom,
  });

  final SquadMember member;
  final bool showTopBorder;
  final bool included;
  final bool isCustom;
  final bool isCovered;
  final bool isPayer;
  final String? coveredByName;
  final double amount;
  final TextEditingController? amountController;
  final VoidCallback onToggleIncluded;
  final VoidCallback onToggleCustom;

  @override
  Widget build(BuildContext context) {
    final dimmed = !included;
    String? subtitle;
    if (dimmed) {
      subtitle = 'Not in this bill';
    } else if (isCovered) {
      subtitle = 'Covered by ${coveredByName ?? 'payer'}';
    } else if (isPayer) {
      subtitle = 'Paying for others too';
    } else if (isCustom) {
      subtitle = 'Custom amount';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: showTopBorder ? Border(top: BorderSide(color: AppColors.text.withValues(alpha: 0.07))) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: Checkbox(
              value: included,
              onChanged: (_) => onToggleIncluded(),
              activeColor: AppColors.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: AppTextStyles.body(
                    size: 13,
                    weight: FontWeight.w700,
                    color: dimmed ? AppColors.text.withValues(alpha: 0.35) : AppColors.text,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.body(
                      size: 11,
                      weight: FontWeight.w500,
                      color: AppColors.text.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (included && isCustom)
            SizedBox(
              width: 84,
              height: 36,
              child: TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.end,
                style: AppTextStyles.body(size: 13, weight: FontWeight.w700),
                decoration: InputDecoration(
                  prefixText: '฿',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  filled: true,
                  fillColor: AppColors.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.text.withValues(alpha: 0.16)),
                  ),
                ),
              ),
            )
          else
            Text(
              '฿${amount.toStringAsFixed(0)}',
              style: AppTextStyles.body(
                size: 13,
                weight: FontWeight.w700,
                color: dimmed || isCovered ? AppColors.text.withValues(alpha: 0.35) : AppColors.accent700,
              ),
            ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: included && !isCovered ? onToggleCustom : null,
            icon: Icon(
              isCustom ? Icons.link_rounded : Icons.edit_rounded,
              size: 16,
              color: AppColors.text.withValues(alpha: included && !isCovered ? 0.5 : 0.2),
            ),
            tooltip: isCustom ? 'Use equal split' : 'Set a custom amount',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _PayerPicker extends StatelessWidget {
  const _PayerPicker({required this.roster, required this.payerId, required this.onChanged});

  final List<SquadMember> roster;
  final String? payerId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: DropdownButtonFormField<String?>(
        initialValue: payerId,
        isExpanded: true,
        decoration: _fieldDecoration('No one — everyone pays their own share').copyWith(
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        ),
        style: AppTextStyles.body(size: 13, weight: FontWeight.w600),
        items: [
          const DropdownMenuItem(value: null, child: Text('No one — everyone pays their own share')),
          for (final member in roster) DropdownMenuItem(value: member.id, child: Text('${member.name} pays for others')),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _CoverChip extends StatelessWidget {
  const _CoverChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.neutral100,
          border: Border.all(color: selected ? AppColors.accent : AppColors.text.withValues(alpha: 0.16)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: AppTextStyles.body(
            size: 12,
            weight: FontWeight.w600,
            color: selected ? AppColors.bg : AppColors.text,
          ),
        ),
      ),
    );
  }
}
