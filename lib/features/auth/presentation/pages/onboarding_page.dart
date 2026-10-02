import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/validators/onboarding_validators.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

/// "One last thing" — collected right after social sign-in. The phone
/// number is never a login method; it's how the squad and payment
/// requests reach the player.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.user});

  final AppUser user;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _phoneController = TextEditingController();
  final _usernameController = TextEditingController();

  String? _phoneError;
  String? _usernameError;
  bool _touchedPhone = false;
  bool _touchedUsername = false;

  bool get _isValid =>
      OnboardingValidators.phoneError(_phoneController.text) == null &&
      OnboardingValidators.usernameError(_usernameController.text) == null;

  @override
  void dispose() {
    _phoneController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _onPhoneChanged(String value) {
    setState(() {
      _touchedPhone = true;
      _phoneError = OnboardingValidators.phoneError(value);
    });
  }

  void _onUsernameChanged(String value) {
    setState(() {
      _touchedUsername = true;
      _usernameError = OnboardingValidators.usernameError(value);
    });
  }

  void _submit(BuildContext context) {
    setState(() {
      _touchedPhone = true;
      _touchedUsername = true;
      _phoneError = OnboardingValidators.phoneError(_phoneController.text);
      _usernameError =
          OnboardingValidators.usernameError(_usernameController.text);
    });
    if (!_isValid) return;
    context.read<AuthBloc>().add(
          AuthOnboardingSubmitted(
            phone: '+66${_phoneController.text.replaceAll(RegExp(r'\D'), '')}',
            username: _usernameController.text,
          ),
        );
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
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.teamGold,
                      // Foreground, so an expired photo link (Facebook's are signed and
                      // expire) falls back to the initials underneath.
                      foregroundImage: widget.user.avatarUrl != null
                          ? NetworkImage(widget.user.avatarUrl!)
                          : null,
                      onForegroundImageError: widget.user.avatarUrl != null ? (_, _) {} : null,
                      child: Text(
                              widget.user.name.isNotEmpty
                                  ? widget.user.name[0].toUpperCase()
                                  : '?',
                              style: AppTextStyles.heading(
                                size: 16,
                                color: AppColors.neutral800,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.user.provider == AuthProvider.facebook
                                ? 'FACEBOOK'
                                : 'GOOGLE',
                            style: AppTextStyles.label(
                              color: AppColors.text.withValues(alpha: 0.45),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            widget.user.name,
                            style: AppTextStyles.body(
                              size: 14,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text('One last thing', style: AppTextStyles.heading(size: 28)),
                const SizedBox(height: 8),
                Text(
                  "Your phone isn't how you log in — it's how the squad "
                  'reaches you on matchday and how payment requests find you.',
                  style: AppTextStyles.body(
                    size: 13.5,
                    color: AppColors.text.withValues(alpha: 0.62),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.neutral100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.text.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MOBILE NUMBER',
                        style: AppTextStyles.label(
                          color: AppColors.text.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Container(
                            height: 50,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.bg,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppColors.text.withValues(alpha: 0.16),
                              ),
                            ),
                            child: Text(
                              '+66',
                              style: AppTextStyles.body(
                                size: 14,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: TextField(
                                controller: _phoneController,
                                onChanged: _onPhoneChanged,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  hintText: '81 234 5678',
                                  filled: true,
                                  fillColor: AppColors.bg,
                                  contentPadding:
                                      const EdgeInsets.symmetric(horizontal: 18),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(999),
                                    borderSide: BorderSide(
                                      color:
                                          AppColors.text.withValues(alpha: 0.16),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_touchedPhone && _phoneError != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _phoneError!,
                          style: AppTextStyles.body(
                            size: 11.5,
                            color: AppColors.accent700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'USERNAME',
                        style: AppTextStyles.label(
                          color: AppColors.text.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 7),
                      SizedBox(
                        height: 50,
                        child: TextField(
                          controller: _usernameController,
                          onChanged: _onUsernameChanged,
                          decoration: InputDecoration(
                            hintText: '@yourname',
                            filled: true,
                            fillColor: AppColors.bg,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 18),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(999),
                              borderSide: BorderSide(
                                color: AppColors.text.withValues(alpha: 0.16),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_touchedUsername && _usernameError != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _usernameError!,
                          style: AppTextStyles.body(
                            size: 11.5,
                            color: AppColors.accent700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    final isLoading = state is AuthLoading;
                    return SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : () => _submit(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.bg,
                          disabledBackgroundColor:
                              AppColors.accent.withValues(alpha: 0.5),
                          shape: const StadiumBorder(),
                          elevation: 0,
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.bg,
                                ),
                              )
                            : Text(
                                'Finish setup',
                                style: AppTextStyles.heading(
                                  size: 15,
                                  color: AppColors.bg,
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
      ),
    );
  }
}
