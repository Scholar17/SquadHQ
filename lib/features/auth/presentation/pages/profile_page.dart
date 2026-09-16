import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/app_user.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

/// "Your profile" — reached from Squad and the dashboard avatar. Account
/// details plus sign out; editing contact info, nationality and preferred
/// positions is a later pass (read-only for now).
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
      context.read<AuthBloc>().add(const AuthSignedOutRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          current is AuthInitial || current is AuthFailure,
      listener: (context, state) {
        if (state is AuthInitial) {
          Navigator.of(context).popUntil((route) => route.isFirst);
          return;
        }
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
                      backgroundImage: user.avatarUrl != null
                          ? NetworkImage(user.avatarUrl!)
                          : null,
                      child: user.avatarUrl == null
                          ? Text(
                              user.name.isNotEmpty
                                  ? user.name[0].toUpperCase()
                                  : '?',
                              style: AppTextStyles.heading(
                                size: 22,
                                color: AppColors.neutral800,
                              ),
                            )
                          : null,
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
