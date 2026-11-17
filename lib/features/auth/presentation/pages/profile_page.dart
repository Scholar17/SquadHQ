import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/legal_links.dart';
import '../../../../core/notifications/local_notifications.dart';
import '../../../../core/notifications/push_notifications.dart';
import '../../../../core/pwa/pwa_install.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../squad/presentation/widgets/bank_details_section.dart';
import '../../../wallet/domain/repositories/wallet_repository.dart';
import '../../../wallet/presentation/bloc/wallet_qr_bloc.dart';
import '../../../wallet/presentation/widgets/wallet_image.dart';
import '../../../wallet/presentation/widgets/wallet_image_actions.dart';
import '../../../weather/presentation/temperature_unit_controller.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/validators/onboarding_validators.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../widgets/username_input_formatter.dart';
import 'delete_account_page.dart';

/// "Your profile" — reached from Squad and the dashboard avatar. Your photo,
/// name and phone (tap to change), account details, your wallet QR (shown
/// to teammates on bills you pay), and sign out.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.user});

  final AppUser user;

  static String _providerLabel(AuthProvider provider) => switch (provider) {
    AuthProvider.facebook => 'Facebook',
    AuthProvider.google => 'Google',
  };

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lg),
        title: Text('Log out?', style: AppTextStyles.heading(size: 20)),
        content: Text(
          "You'll need to sign back in with ${_providerLabel(user.provider)} "
          'to get back into your squad.',
          style: AppTextStyles.body(size: 13.5, color: AppColors.textSubtle),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancel',
              style: AppTextStyles.body(size: 14, weight: FontWeight.w700, color: AppColors.text),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Log out',
              style: AppTextStyles.body(
                size: 14,
                weight: FontWeight.w700,
                color: AppColors.accent700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final authBloc = context.read<AuthBloc>();
      // While still signed in: stop this device getting this account's
      // pushes and reminders.
      await PushNotifications.disable();
      await LocalNotifications.cancelAll();
      authBloc.add(const AuthSignedOutRequested());
    }
  }

  /// A new photo: square-ish and small (it's shown at avatar size).
  Future<void> _changePhoto(BuildContext context) async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null || !context.mounted) return;
    final name = file.name.toLowerCase();
    final extension = name.endsWith('.png') ? 'png' : 'jpg';
    final bytes = await file.readAsBytes();
    if (!context.mounted) return;
    context.read<AuthBloc>().add(
      AuthProfileUpdateRequested(avatarBytes: bytes, avatarExtension: extension),
    );
  }

  Future<void> _editName(BuildContext context, AppUser user) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _EditFieldDialog(
        title: 'Your name',
        initial: user.name,
        hint: 'How your squad sees you',
        validate: OnboardingValidators.nameError,
      ),
    );
    if (name == null || name.trim() == user.name || !context.mounted) return;
    context.read<AuthBloc>().add(AuthProfileUpdateRequested(name: name.trim()));
  }

  Future<void> _editUsername(BuildContext context, AppUser user) async {
    final bloc = context.read<AuthBloc>();
    await showDialog<String>(
      context: context,
      builder: (_) => _EditFieldDialog(
        title: 'Mention name',
        initial: user.username ?? '',
        hint: 'yourname',
        prefix: '@',
        note: 'Teammates type @ and this to mention you in comments. Old mentions switch to the new one.',
        textCapitalization: TextCapitalization.none,
        inputFormatters: const [UsernameInputFormatter()],
        validate: (value) => OnboardingValidators.usernameError(value.trim()),
        save: (value) async {
          final username = value.trim();
          if (username == user.username) return null;
          // Saved with the dialog still open, so "taken" lands under the
          // field; anything else closes it and shows as a snackbar.
          final result = bloc.stream.firstWhere(
            (state) => state is AuthAuthenticated || state is AuthFailure,
          );
          bloc.add(AuthProfileUpdateRequested(username: username));
          return switch (await result) {
            AuthFailure(:final message) when message == OnboardingValidators.usernameTaken =>
              message,
            _ => null,
          };
        },
      ),
    );
  }

  Future<void> _editPhone(BuildContext context, AppUser user) async {
    final digits = await showDialog<String>(
      context: context,
      builder: (_) => _EditFieldDialog(
        title: 'Phone number',
        initial: (user.phone ?? '').replaceFirst('+66', ''),
        hint: '81 234 5678',
        prefix: '+66 ',
        keyboardType: TextInputType.phone,
        validate: OnboardingValidators.phoneError,
      ),
    );
    if (digits == null || !context.mounted) return;
    final phone = '+66${digits.replaceAll(RegExp(r'\D'), '')}';
    if (phone == user.phone) return;
    context.read<AuthBloc>().add(AuthProfileUpdateRequested(phone: phone));
  }

  @override
  Widget build(BuildContext context) {
    // Live: an edit shows as soon as it's saved.
    final authState = context.watch<AuthBloc>().state;
    final settled = switch (authState) {
      AuthLoading(:final previous) || AuthFailure(:final previous) => previous,
      final state => state,
    };
    final user = settled is AuthAuthenticated ? settled.user : this.user;
    final saving = authState is AuthLoading;
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          // A taken username shows in the edit dialog instead.
          (current is AuthFailure && current.message != OnboardingValidators.usernameTaken) ||
          (previous is AuthLoading && current is AuthAuthenticated),
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(switch (state) {
                AuthFailure(:final message) => message,
                _ => 'Profile saved',
              }),
            ),
          );
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          elevation: 0,
          foregroundColor: AppColors.text,
          title: Text('Profile', style: AppTextStyles.title(size: 16)),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: AppRadius.lg,
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    // Tap for a new photo.
                    Semantics(
                      button: true,
                      label: 'Change profile photo',
                      child: GestureDetector(
                        onTap: saving ? null : () => _changePhoto(context),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: AppColors.teamGold,
                              // Foreground, so an expired photo link (Facebook's are signed and
                              // expire) falls back to the initials underneath.
                              foregroundImage: user.avatarUrl != null
                                  ? NetworkImage(user.avatarUrl!)
                                  : null,
                              onForegroundImageError: user.avatarUrl != null ? (_, _) {} : null,
                              child: Text(
                                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                                style: AppTextStyles.heading(size: 22, color: AppColors.neutral800),
                              ),
                            ),
                            if (saving)
                              Positioned.fill(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.accent700,
                                ),
                              ),
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.neutral900,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.card, width: 2),
                                ),
                                child: const Icon(
                                  Icons.photo_camera_rounded,
                                  size: 12,
                                  color: AppColors.onDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  user.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.title(size: 18),
                                ),
                              ),
                              IconButton(
                                onPressed: saving ? null : () => _editName(context, user),
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                tooltip: 'Edit name',
                                visualDensity: VisualDensity.compact,
                                color: AppColors.textMuted,
                              ),
                            ],
                          ),
                          // Changed under Account, as the mention name.
                          if (user.username != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '@${user.username}',
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.body(
                                size: 13,
                                weight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('ACCOUNT', style: AppTextStyles.label(color: AppColors.textMuted)),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  border: Border.all(color: AppColors.divider),
                  borderRadius: AppRadius.lg,
                ),
                child: Column(
                  children: [
                    _InfoRow(
                      label: 'Name',
                      note: 'How your squad sees you',
                      value: user.name,
                      onTap: saving ? null : () => _editName(context, user),
                    ),
                    _InfoRow(
                      showTopBorder: true,
                      label: 'Mention name',
                      note: 'Teammates type it after @ to mention you in comments',
                      value: user.username == null ? 'Not set' : '@${user.username}',
                      onTap: saving ? null : () => _editUsername(context, user),
                    ),
                    _InfoRow(
                      label: 'Phone',
                      value: user.phone ?? 'Not set',
                      showTopBorder: true,
                      onTap: saving ? null : () => _editPhone(context, user),
                    ),
                    _InfoRow(
                      label: 'Signed in with',
                      // The account to pick next time — handy with more than one.
                      note: user.email,
                      value: _providerLabel(user.provider),
                      showTopBorder: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('WALLET QR', style: AppTextStyles.label(color: AppColors.textMuted)),
              const SizedBox(height: 10),
              BlocProvider(
                create: (_) => sl<WalletQrBloc>()..add(const WalletQrStarted()),
                child: const _WalletQrSection(),
              ),
              const SizedBox(height: 20),
              Text('BANK DETAILS', style: AppTextStyles.label(color: AppColors.textMuted)),
              const SizedBox(height: 10),
              const BankDetailsSection(),
              const SizedBox(height: 20),
              Text('APPEARANCE', style: AppTextStyles.label(color: AppColors.textMuted)),
              const SizedBox(height: 10),
              const _AppearanceSection(),
              const SizedBox(height: 20),
              Text('TEMPERATURE', style: AppTextStyles.label(color: AppColors.textMuted)),
              const SizedBox(height: 10),
              const _TemperatureUnitSection(),
              const SizedBox(height: 20),
              Text('NOTIFICATIONS', style: AppTextStyles.label(color: AppColors.textMuted)),
              const SizedBox(height: 10),
              const _NotificationsSection(),
              const SizedBox(height: 20),
              Text('SQUAD', style: AppTextStyles.label(color: AppColors.textMuted)),
              const SizedBox(height: 10),
              Material(
                color: AppColors.card,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.lg,
                  side: BorderSide(color: AppColors.divider),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => context.push(AppRoutes.team),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Text(
                          'Team',
                          style: AppTextStyles.body(size: 13.5, weight: FontWeight.w700),
                        ),
                        const Spacer(),
                        Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
              ),
              // The web app in a browser tab: install it (hidden once installed).
              ListenableBuilder(
                listenable: pwaInstallChanges,
                builder: (context, _) {
                  if (!canInstallPwa) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      Text('APP', style: AppTextStyles.label(color: AppColors.textMuted)),
                      const SizedBox(height: 10),
                      Material(
                        color: AppColors.card,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.lg,
                          side: BorderSide(color: AppColors.divider),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => installPwa(context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Text(
                                  'Install app',
                                  style: AppTextStyles.body(size: 13.5, weight: FontWeight.w700),
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.install_mobile_rounded,
                                  size: 18,
                                  color: AppColors.textMuted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              Text('LEGAL', style: AppTextStyles.label(color: AppColors.textMuted)),
              const SizedBox(height: 10),
              Material(
                color: AppColors.card,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.lg,
                  side: BorderSide(color: AppColors.divider),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => openTermsOfService(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Text(
                          'Terms of Service',
                          style: AppTextStyles.body(size: 13.5, weight: FontWeight.w700),
                        ),
                        const Spacer(),
                        Icon(Icons.open_in_new_rounded, size: 18, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Material(
                color: AppColors.card,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.lg,
                  side: BorderSide(color: AppColors.divider),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => openPrivacyPolicy(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Text(
                          'Privacy policy',
                          style: AppTextStyles.body(size: 13.5, weight: FontWeight.w700),
                        ),
                        const Spacer(),
                        Icon(Icons.open_in_new_rounded, size: 18, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Material(
                color: AppColors.card,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.lg,
                  side: BorderSide(color: AppColors.divider),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: saving
                      ? null
                      : () => Navigator.of(
                          context,
                        ).push(MaterialPageRoute<void>(builder: (_) => const DeleteAccountPage())),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Text(
                          'Delete account',
                          style: AppTextStyles.body(
                            size: 13.5,
                            weight: FontWeight.w700,
                            color: AppColors.accent700,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  final isLoading = state is AuthLoading;
                  return SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: isLoading ? null : () => _confirmSignOut(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.accent700.withValues(alpha: 0.4)),
                        shape: const StadiumBorder(),
                      ),
                      child: isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.accent700,
                              ),
                            )
                          : Text(
                              'Log out',
                              style: AppTextStyles.title(size: 14, color: AppColors.accent700),
                            ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.note,
    this.showTopBorder = false,
    this.onTap,
  });

  final String label;
  final String value;

  /// A line under [label] saying what it's for.
  final String? note;
  final bool showTopBorder;

  /// Editable: a pencil, and tapping the row edits it.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.lg,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: showTopBorder
              ? Border(top: BorderSide(color: AppColors.divider))
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.body(
                      size: 13,
                      weight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  if (note != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      note!,
                      style: AppTextStyles.body(size: 11.5, color: AppColors.textMuted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: AppTextStyles.body(size: 13.5, weight: FontWeight.w700),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.edit_outlined, size: 16, color: AppColors.textMuted),
            ],
          ],
        ),
      ),
    );
  }
}

/// A one-field edit: [initial] to start, [validate] before Save.
class _EditFieldDialog extends StatefulWidget {
  const _EditFieldDialog({
    required this.title,
    required this.initial,
    required this.hint,
    required this.validate,
    this.prefix,
    this.note,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.words,
    this.inputFormatters,
    this.save,
  });

  final String title;
  final String initial;
  final String hint;
  final String? Function(String) validate;
  final String? prefix;

  /// A line under the field, e.g. what changing it does.
  final String? note;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;

  /// Saves from inside the dialog: an error message keeps it open with
  /// that under the field, null closes it. Without it, the dialog just
  /// returns the text.
  final Future<String?> Function(String value)? save;

  @override
  State<_EditFieldDialog> createState() => _EditFieldDialogState();
}

class _EditFieldDialogState extends State<_EditFieldDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final error = widget.validate(_controller.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    if (widget.save case final save?) {
      setState(() {
        _saving = true;
        _error = null;
      });
      final saveError = await save(_controller.text);
      if (!mounted) return;
      if (saveError != null) {
        setState(() {
          _saving = false;
          _error = saveError;
        });
        return;
      }
    }
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: Text(widget.title),
      content: TextField(
        key: const ValueKey('edit-field'),
        controller: _controller,
        autofocus: true,
        enabled: !_saving,
        inputFormatters: widget.inputFormatters,
        keyboardType: widget.keyboardType,
        textCapitalization: widget.textCapitalization,
        autocorrect: widget.textCapitalization != TextCapitalization.none,
        onSubmitted: (_) => _save(),
        decoration: InputDecoration(
          hintText: widget.hint,
          prefixText: widget.prefix,
          helperText: widget.note,
          helperMaxLines: 2,
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save')),
      ],
    );
  }
}

/// Upload or replace the QR code teammates scan to pay you back when you
/// pay a match bill.
class _WalletQrSection extends StatelessWidget {
  const _WalletQrSection();

  Future<void> _upload(BuildContext context) async {
    final picked = await pickWalletImage(context);
    if (picked == null || !context.mounted) return;
    context.read<WalletQrBloc>().add(
      WalletQrUploadRequested(bytes: picked.bytes, fileExtension: picked.fileExtension),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WalletQrBloc, WalletQrState>(
      listenWhen: (previous, current) =>
          current is WalletQrFailure ||
          (previous is WalletQrUploading && current is WalletQrLoaded),
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(state is WalletQrFailure ? state.message : 'Wallet QR saved')),
          );
      },
      builder: (context, state) {
        final settled = switch (state) {
          WalletQrUploading(:final previous) => previous,
          WalletQrFailure(:final previous) => previous,
          _ => state,
        };
        final isLoading = settled is WalletQrLoading;
        final isUploading = state is WalletQrUploading;
        final path = settled is WalletQrLoaded ? settled.path : null;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border.all(color: AppColors.divider),
            borderRadius: AppRadius.lg,
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: path == null
                    ? null
                    : () => showWalletImageViewer(
                        context,
                        kind: WalletImageKind.walletQr,
                        path: path,
                        title: 'Your wallet QR',
                      ),
                child: Container(
                  width: 76,
                  height: 76,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppRadius.md,
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.accent,
                          ),
                        )
                      : path == null
                      ? Icon(
                          Icons.qr_code_2_rounded,
                          size: 40,
                          color: AppColors.text.withValues(alpha: 0.3),
                        )
                      : WalletImage(kind: WalletImageKind.walletQr, path: path),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      path == null
                          ? 'Add your PromptPay or bank QR so teammates can pay you back '
                                'when you pay a match bill.'
                          : 'Teammates see this QR on bills you pay.',
                      style: AppTextStyles.body(size: 12, color: AppColors.textMuted, height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: isLoading || isUploading ? null : () => _upload(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.text,
                        side: BorderSide(color: AppColors.divider),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        minimumSize: const Size(0, 32),
                      ),
                      child: isUploading
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.text,
                              ),
                            )
                          : Text(
                              path == null ? 'Upload QR' : 'Replace QR',
                              style: AppTextStyles.title(size: 12),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Push notification status, with "Turn on" — on web, browsers only let a
/// tap ask for permission.
class _NotificationsSection extends StatefulWidget {
  const _NotificationsSection();

  @override
  State<_NotificationsSection> createState() => _NotificationsSectionState();
}

class _NotificationsSectionState extends State<_NotificationsSection> {
  late Future<PushStatus> _status = PushNotifications.status();
  bool _busy = false;

  Future<void> _turnOn() async {
    setState(() => _busy = true);
    await PushNotifications.enable();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = PushNotifications.status();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.divider),
        borderRadius: AppRadius.lg,
      ),
      child: FutureBuilder<PushStatus>(
        future: _status,
        builder: (context, snapshot) {
          final status = snapshot.data ?? PushStatus.unsupported;
          final on = status == PushStatus.on;
          final (title, detail) = switch (status) {
            PushStatus.on => (
              'Notifications are on',
              'New matches, RSVP and match reminders, Man of the Match and match fees.',
            ),
            PushStatus.notAsked => (
              'Notifications are off',
              'New matches, RSVP and match reminders, Man of the Match and match fees.',
            ),
            PushStatus.blocked => (
              'Notifications are blocked',
              'Allow them for Squad HQ in your browser or phone settings.',
            ),
            PushStatus.needsHomeScreen => (
              'Add to Home Screen first',
              'On iPhone/iPad, tap Share → "Add to Home Screen", then open Squad HQ from '
                  'there to turn on notifications.',
            ),
            PushStatus.unsupported => (
              'Not available here',
              "This browser can't receive notifications.",
            ),
          };
          return Row(
            children: [
              Icon(
                on ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
                color: on ? AppColors.accent2_700 : AppColors.textMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.body(size: 13.5, weight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: AppTextStyles.body(
                        size: 11.5,
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (status == PushStatus.notAsked)
                TextButton(
                  onPressed: _busy ? null : _turnOn,
                  child: Text(
                    _busy ? '…' : 'Turn on',
                    style: AppTextStyles.body(
                      size: 13,
                      weight: FontWeight.w700,
                      color: AppColors.accent700,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// System / Light / Dark — saved on this device, applied at once.
class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context) {
    final controller = sl<ThemeController>();
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: controller,
      builder: (context, current, _) => _ChoiceBar<ThemeMode>(
        options: const [
          (value: ThemeMode.system, label: 'System', icon: Icons.brightness_auto_rounded),
          (value: ThemeMode.light, label: 'Light', icon: Icons.light_mode_rounded),
          (value: ThemeMode.dark, label: 'Dark', icon: Icons.dark_mode_rounded),
        ],
        current: current,
        onSelect: controller.select,
      ),
    );
  }
}

/// °C / °F for match forecasts — saved on this device.
class _TemperatureUnitSection extends StatelessWidget {
  const _TemperatureUnitSection();

  @override
  Widget build(BuildContext context) {
    final controller = sl<TemperatureUnitController>();
    return ValueListenableBuilder<TemperatureUnit>(
      valueListenable: controller,
      builder: (context, current, _) => _ChoiceBar<TemperatureUnit>(
        options: const [
          (value: TemperatureUnit.celsius, label: 'Celsius °C', icon: Icons.thermostat_rounded),
          (value: TemperatureUnit.fahrenheit, label: 'Fahrenheit °F', icon: Icons.thermostat_rounded),
        ],
        current: current,
        onSelect: controller.select,
      ),
    );
  }
}

/// A row of options, one picked — the Appearance and Temperature choices.
class _ChoiceBar<T> extends StatelessWidget {
  const _ChoiceBar({required this.options, required this.current, required this.onSelect});

  final List<({T value, String label, IconData icon})> options;
  final T current;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.divider),
        borderRadius: AppRadius.lg,
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: Semantics(
                button: true,
                selected: option.value == current,
                child: Material(
                  color: option.value == current ? AppColors.neutral900 : Colors.transparent,
                  borderRadius: AppRadius.md,
                  child: InkWell(
                    borderRadius: AppRadius.md,
                    onTap: () {
                      if (option.value == current) return;
                      HapticFeedback.selectionClick();
                      onSelect(option.value);
                    },
                    child: SizedBox(
                      height: 44,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            option.icon,
                            size: 17,
                            color: option.value == current ? AppColors.onDark : AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            option.label,
                            style: AppTextStyles.body(
                              size: 13,
                              weight: FontWeight.w700,
                              color: option.value == current ? AppColors.onDark : AppColors.text,
                            ),
                          ),
                        ],
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
