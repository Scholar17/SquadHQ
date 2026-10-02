import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/squad_member.dart';
import '../../domain/usecases/squad_usecases.dart';
import '../bloc/squad_ledger_bloc.dart';
import 'squad_widgets.dart';

/// Optional bank details on the profile, for squad-mates who pay by
/// transfer. Only people in your groups can see them.
class BankDetailsSection extends StatefulWidget {
  const BankDetailsSection({super.key});

  @override
  State<BankDetailsSection> createState() => _BankDetailsSectionState();
}

class _BankDetailsSectionState extends State<BankDetailsSection> {
  BankDetails? _details;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await sl<GetMyBankDetails>()(const NoParams());
    if (!mounted) return;
    setState(() {
      _loading = false;
      _details = result.fold((_) => const BankDetails(), (details) => details);
    });
  }

  Future<void> _edit() async {
    final saved = await showModalBottomSheet<BankDetails>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.neutral100,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _BankDetailsSheet(initial: _details ?? const BankDetails()),
    );
    if (saved == null || !mounted) return;
    setState(() => _details = saved);
    // Squad-mates' pay sheets read these through the ledger.
    context.read<SquadLedgerBloc>().add(const SquadRefreshRequested());
  }

  @override
  Widget build(BuildContext context) {
    final details = _details;
    final has = details != null && !details.isEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        border: Border.all(color: AppColors.text.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.account_balance_outlined, size: 20, color: oweColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _loading
                ? const LinearProgressIndicator(color: AppColors.accent)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        has ? (details.bankName ?? 'Bank account') : 'Bank details',
                        style: AppTextStyles.heading(size: 15, height: 1.3),
                      ),
                      Text(
                        has
                            ? [
                                if (details.accountName case final name?) name,
                                details.accountNo!,
                              ].join(' · ')
                            : 'Optional · for squad-mates who pay by transfer',
                        style: AppTextStyles.body(size: 12, color: squadMuted, height: 1.35),
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: _loading ? null : _edit,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.text,
              minimumSize: const Size(0, 40),
              side: BorderSide(color: AppColors.text.withValues(alpha: 0.2)),
              shape: const StadiumBorder(),
            ),
            child: Text(has ? 'Edit' : 'Add'),
          ),
        ],
      ),
    );
  }
}

class _BankDetailsSheet extends StatefulWidget {
  const _BankDetailsSheet({required this.initial});

  final BankDetails initial;

  @override
  State<_BankDetailsSheet> createState() => _BankDetailsSheetState();
}

class _BankDetailsSheetState extends State<_BankDetailsSheet> {
  late final _bank = TextEditingController(text: widget.initial.bankName);
  late final _name = TextEditingController(text: widget.initial.accountName);
  late final _number = TextEditingController(text: widget.initial.accountNo);
  bool _saving = false;

  @override
  void dispose() {
    _bank.dispose();
    _name.dispose();
    _number.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final details = BankDetails(
      bankName: _bank.text.trim(),
      accountName: _name.text.trim(),
      accountNo: _number.text.trim(),
    );
    setState(() => _saving = true);
    final result = await sl<SaveMyBankDetails>()(details);
    if (!mounted) return;
    setState(() => _saving = false);
    result.fold(
      (failure) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failure.message))),
      (_) => Navigator.of(context).pop(details),
    );
  }

  Widget _field(TextEditingController controller, String label, {TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        style: AppTextStyles.body(size: 15, weight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: AppColors.bg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.text.withValues(alpha: 0.18)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        children: [
          Text('Bank details', style: AppTextStyles.heading(size: 20)),
          const SizedBox(height: 4),
          Text(
            'Only people in your groups can see these. Leave the number empty to remove them.',
            style: AppTextStyles.body(size: 12.5, color: squadMuted),
          ),
          const SizedBox(height: 16),
          _field(_bank, 'Bank, e.g. KBank or KBZ'),
          _field(_name, 'Account name'),
          _field(_number, 'Account number', keyboard: TextInputType.number),
          const SizedBox(height: 4),
          SquadPrimaryButton(label: 'Save', isLoading: _saving, onPressed: _save),
        ],
      ),
    );
  }
}
