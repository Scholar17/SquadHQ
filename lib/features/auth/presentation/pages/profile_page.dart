import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/notifications/local_notifications.dart';
import '../../../../core/notifications/push_notifications.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../squad/presentation/widgets/bank_details_section.dart';
import '../../../wallet/domain/repositories/wallet_repository.dart';
import '../../../wallet/presentation/bloc/wallet_qr_bloc.dart';
import '../../../wallet/presentation/widgets/wallet_image.dart';
import '../../../wallet/presentation/widgets/wallet_image_actions.dart';
import '../../domain/entities/app_user.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

/// "Your profile" — reached from Squad and the dashboard avatar. Account
/// details, your wallet QR (shown to teammates on bills you pay), and sign
/// out; editing contact info, nationality and preferred positions is a
/// later pass (read-only for now).
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
        backgroundColor: AppColors.neutral100,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Log out?', style: AppTextStyles.heading(size: 20)),
        content: Text(
          "You'll need to sign back in with ${_providerLabel(user.provider)} "
          'to get back into your squad.',
          style: AppTextStyles.body(
            size: 13.5,
            color: AppColors.text.withValues(alpha: 0.7),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancel',
              style: AppTextStyles.body(size: 14, weight: FontWeight.w700),
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

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) => current is AuthFailure,
      listener: (context, state) {
        if (state case AuthFailure(:final message)) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          elevation: 0,
          foregroundColor: AppColors.text,
          title: Text('Profile', style: AppTextStyles.heading(size: 16)),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.neutral100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.text.withValues(alpha: 0.1)),
                ),
                child: Row(
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
                              user.name.isNotEmpty
                                  ? user.name[0].toUpperCase()
                                  : '?',
                              style: AppTextStyles.heading(
                                size: 22,
                                color: AppColors.neutral800,
                              ),
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name, style: AppTextStyles.heading(size: 18)),
                          if (user.username != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '@${user.username}',
                              style: AppTextStyles.body(
                                size: 13,
                                weight: FontWeight.w600,
                                color: AppColors.text.withValues(alpha: 0.55),
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
              Text(
                'ACCOUNT',
                style: AppTextStyles.label(color: AppColors.text.withValues(alpha: 0.45)),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.neutral100,
                  border: Border.all(color: AppColors.text.withValues(alpha: 0.1)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    _InfoRow(label: 'Phone', value: user.phone ?? 'Not set'),
                    _InfoRow(
                      label: 'Signed in with',
                      value: _providerLabel(user.provider),
                      showTopBorder: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'WALLET QR',
                style: AppTextStyles.label(color: AppColors.text.withValues(alpha: 0.45)),
              ),
              const SizedBox(height: 10),
              BlocProvider(
                create: (_) => sl<WalletQrBloc>()..add(const WalletQrStarted()),
                child: const _WalletQrSection(),
              ),
              const SizedBox(height: 20),
              Text(
                'BANK DETAILS',
                style: AppTextStyles.label(color: AppColors.text.withValues(alpha: 0.45)),
              ),
              const SizedBox(height: 10),
              const BankDetailsSection(),
              const SizedBox(height: 20),
              Text(
                'NOTIFICATIONS',
                style: AppTextStyles.label(color: AppColors.text.withValues(alpha: 0.45)),
              ),
              const SizedBox(height: 10),
              const _NotificationsSection(),
              const SizedBox(height: 20),
              Text(
                'SQUAD',
                style: AppTextStyles.label(color: AppColors.text.withValues(alpha: 0.45)),
              ),
              const SizedBox(height: 10),
              Material(
                color: AppColors.neutral100,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => context.push(AppRoutes.team),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.text.withValues(alpha: 0.1)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Team',
                          style: AppTextStyles.body(size: 13.5, weight: FontWeight.w700),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.text.withValues(alpha: 0.4),
                        ),
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
                        side: BorderSide(
                          color: AppColors.accent700.withValues(alpha: 0.4),
                        ),
                        shape: const StadiumBorder(),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.accent700,
                              ),
                            )
                          : Text(
                              'Log out',
                              style: AppTextStyles.heading(
                                size: 14,
                                color: AppColors.accent700,
                              ),
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
    this.showTopBorder = false,
  });

  final String label;
  final String value;
  final bool showTopBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: showTopBorder
            ? Border(top: BorderSide(color: AppColors.text.withValues(alpha: 0.07)))
            : null,
      ),
      child: Row(
        children: [
          Text(
            label,
            style: AppTextStyles.body(
              size: 13,
              weight: FontWeight.w600,
              color: AppColors.text.withValues(alpha: 0.55),
            ),
          ),
          const Spacer(),
          Text(value, style: AppTextStyles.body(size: 13.5, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Upload or replace the QR code teammates scan to pay you back when you
/// pay a match bill.
class _WalletQrSection extends StatelessWidget {
  const _WalletQrSection();

  Future<void> _upload(BuildContext context) async {
    final picked = await pickWalletImage();
    if (picked == null || !context.mounted) return;
    context.read<WalletQrBloc>().add(
          WalletQrUploadRequested(bytes: picked.bytes, fileExtension: picked.fileExtension),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WalletQrBloc, WalletQrState>(
      listenWhen: (previous, current) =>
          current is WalletQrFailure || (previous is WalletQrUploading && current is WalletQrLoaded),
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                state is WalletQrFailure ? state.message : 'Wallet QR saved',
              ),
            ),
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
            color: AppColors.neutral100,
            border: Border.all(color: AppColors.text.withValues(alpha: 0.1)),
            borderRadius: BorderRadius.circular(20),
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
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.text.withValues(alpha: 0.1)),
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
                      style: AppTextStyles.body(
                        size: 12,
                        color: AppColors.text.withValues(alpha: 0.6),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: isLoading || isUploading ? null : () => _upload(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.text,
                        side: BorderSide(color: AppColors.text.withValues(alpha: 0.16)),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        minimumSize: const Size(0, 32),
                      ),
                      child: isUploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.text,
                              ),
                            )
                          : Text(
                              path == null ? 'Upload QR' : 'Replace QR',
                              style: AppTextStyles.heading(size: 12),
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
        color: AppColors.neutral100,
        border: Border.all(color: AppColors.text.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(20),
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
                color: on ? AppColors.accent2_700 : AppColors.text.withValues(alpha: 0.45),
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
                        color: AppColors.text.withValues(alpha: 0.55),
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
