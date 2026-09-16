import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../widgets/social_login_button.dart';

/// The prototype's login screen: full-bleed pitch/squad photo, dark scrim,
/// "Every match, sorted." pitch, and the two social sign-in doors — social
/// sign-in only, phone number is collected later during onboarding.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

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
        backgroundColor: AppColors.neutral900,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const Image(
              image: AssetImage('assets/images/pitch_bg.png'),
              fit: BoxFit.cover,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.46, 0.64, 0.78, 1.0],
                  colors: [
                    Colors.black.withValues(alpha: 0.26),
                    Colors.black.withValues(alpha: 0.30),
                    Colors.black.withValues(alpha: 0.58),
                    Colors.black.withValues(alpha: 0.88),
                    Colors.black.withValues(alpha: 0.93),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: AppColors.teamGold,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'GG',
                        style: AppTextStyles.heading(
                          size: 21,
                          color: AppColors.neutral800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    Text(
                      'Every match,\nsorted.',
                      style: AppTextStyles.heading(
                        size: 38,
                        color: AppColors.neutral100,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: Text(
                        'Fixtures, availability, match fees and squad stats '
                        'for your amateur football team — one app instead '
                        'of four chat threads.',
                        style: AppTextStyles.body(
                          size: 14,
                          color: const Color(0xFFE4DBCD),
                        ),
                      ),
                    ),
                    const Spacer(),
                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) {
                        final isLoading = state is AuthLoading;
                        return Column(
                          children: [
                            SocialLoginButton.facebook(
                              onPressed: isLoading
                                  ? null
                                  : () => context.read<AuthBloc>().add(
                                        const AuthFacebookSignInRequested(),
                                      ),
                            ),
                            const SizedBox(height: 10),
                            SocialLoginButton.google(
                              onPressed: isLoading
                                  ? null
                                  : () => context.read<AuthBloc>().add(
                                        const AuthGoogleSignInRequested(),
                                      ),
                            ),
                            if (isLoading) ...[
                              const SizedBox(height: 16),
                              const CircularProgressIndicator(
                                color: AppColors.teamGold,
                                strokeWidth: 2.5,
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    Text(
                      "Social sign-in only — we'll ask for your phone once, "
                      'so the manager can reach you and send payment requests.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(
                        size: 11.5,
                        color: const Color(0xFFCFC4B4),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'By continuing you agree to the squad rules and '
                      'privacy notice.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(
                        size: 11.5,
                        color: const Color(0xFFCFC4B4),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
