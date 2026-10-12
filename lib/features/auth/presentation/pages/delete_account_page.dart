import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/legal_links.dart';
import '../../../../core/notifications/local_notifications.dart';
import '../../../../core/notifications/push_notifications.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

/// Profile → Delete account: what's deleted and what's kept, an
/// acknowledgement to tick, then Continue and a last "Delete your
/// account?". Once it's gone, signing out takes the app to the login page.
class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  bool _acknowledged = false;

  Future<void> _continue() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lg),
        title: Text('Delete your account?', style: AppTextStyles.heading(size: 20)),
        content: Text(
          'Your account and personal details will be deleted permanently. '
          'This can’t be undone.',
          style: AppTextStyles.body(size: 14, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent700),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final authBloc = context.read<AuthBloc>();
    // As on log out: stop this device getting this account's pushes and
    // reminders, while still signed in.
    await PushNotifications.disable();
    await LocalNotifications.cancelAll();
    authBloc.add(const AuthAccountDeletionRequested());
  }

  @override
  Widget build(BuildContext context) {
    final body = AppTextStyles.body(size: 14, height: 1.5);
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (previous, current) => current is AuthFailure,
      listener: (context, state) {
        if (state case AuthFailure(:final message)) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
        }
      },
      builder: (context, state) {
        final deleting = state is AuthLoading;
        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            backgroundColor: AppColors.bg,
            elevation: 0,
            foregroundColor: AppColors.text,
            title: Text('Delete account', style: AppTextStyles.title(size: 16)),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Icon(Icons.warning_amber_rounded, size: 44, color: AppColors.accent700),
                const SizedBox(height: 12),
                Text(
                  'Deleting your account is permanent',
                  style: AppTextStyles.heading(size: 20),
                ),
                const SizedBox(height: 16),
                _Point(
                  title: 'What’s deleted',
                  text:
                      'Your login, name, photo, phone number, username, payment QR, bank '
                      'details and notifications, and your place in every team and squad.',
                  style: body,
                ),
                _Point(
                  title: 'What’s kept',
                  text:
                      'Expenses, payments and slips you share with others stay, shown as '
                      '“Deleted user”, so their balances still add up. Settle up first if '
                      'anyone still owes you, or you owe them.',
                  style: body,
                ),
                _Point(
                  title: 'Your groups',
                  text:
                      'A team or squad you own passes to another member; one only you '
                      'are in is deleted.',
                  style: body,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => openPrivacyPolicy(context),
                    child: const Text('Read the privacy policy'),
                  ),
                ),
                const SizedBox(height: 8),
                // The conditions above, acknowledged.
                Material(
                  color: AppColors.card,
                  borderRadius: AppRadius.md,
                  child: CheckboxListTile(
                    key: const ValueKey('delete-acknowledge'),
                    value: _acknowledged,
                    onChanged: deleting
                        ? null
                        : (value) => setState(() => _acknowledged = value ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppColors.accentFill,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
                    title: Text(
                      'I acknowledge and agree that my data will be permanently deleted, '
                      'and I accept the account deletion conditions.',
                      style: AppTextStyles.body(size: 13.5, weight: FontWeight.w600, height: 1.4),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: _acknowledged && !deleting ? _continue : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accentFill,
                      shape: const StadiumBorder(),
                    ),
                    child: deleting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.onDark,
                            ),
                          )
                        : Text(
                            'Continue',
                            style: AppTextStyles.title(size: 14, color: AppColors.onDark),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.title, required this.text, required this.style});

  final String title;
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: style.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(text, style: style),
        ],
      ),
    );
  }
}
