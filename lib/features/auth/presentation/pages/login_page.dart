import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/legal_links.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../widgets/social_login_button.dart';

/// The prototype's login screen: full-bleed pitch/squad photo, dark scrim,
/// "Every match, sorted." pitch, and the two social sign-in doors — social
/// sign-in only, phone number is collected later during onboarding.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Back from the sign-in browser — lets the bloc drop the spinner if the
  // sign-in was closed without finishing.
  late final _lifecycle = AppLifecycleListener(
    onResume: () => context.read<AuthBloc>().add(const AuthAppResumed()),
  );

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
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
        backgroundColor: AppColors.neutral900,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const Image(image: AssetImage('assets/images/pitch_bg.png'), fit: BoxFit.cover),
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
              // Scrolls on a short screen instead of overflowing; at least
              // the screen's height otherwise, with the gap between the intro
              // and sign-in taking up the rest.
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
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
                                'Your squad,\nsorted.',
                                style: AppTextStyles.heading(size: 38, color: AppColors.onDark),
                              ),
                              const SizedBox(height: 12),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 300),
                                child: Text(
                                  'Football matches, trips, shared bills and monthly '
                                  "subscriptions — who's in, who paid, who owes what. "
                                  'One app instead of four chat threads.',
                                  style: AppTextStyles.body(
                                    size: 14,
                                    color: const Color(0xFFE4DBCD),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              BlocBuilder<AuthBloc, AuthState>(
                                builder: (context, state) {
                                  final isLoading = state is AuthLoading;
                                  return Column(
                                    children: [
                                      SocialLoginButton.google(
                                        onPressed: isLoading
                                            ? null
                                            : () => context.read<AuthBloc>().add(
                                                const AuthGoogleSignInRequested(),
                                              ),
                                      ),
                                      const SizedBox(height: 10),
                                      SocialLoginButton.facebook(
                                        onPressed: isLoading
                                            ? null
                                            : () => context.read<AuthBloc>().add(
                                                const AuthFacebookSignInRequested(),
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
                                'so your squad can reach you and send payment requests.',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.body(
                                  size: 11.5,
                                  color: const Color(0xFFCFC4B4),
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const _LegalLine(),
                            ],
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
      ),
    );
  }
}

/// "By continuing you agree to the Terms of Service and Privacy Policy."
/// — both links tappable. Real text links (not embedded widgets), so the
/// screen can measure its height and scroll when it's short.
class _LegalLine extends StatefulWidget {
  const _LegalLine();

  @override
  State<_LegalLine> createState() => _LegalLineState();
}

class _LegalLineState extends State<_LegalLine> {
  late final _terms = TapGestureRecognizer()..onTap = () => openTermsOfService(context);
  late final _privacy = TapGestureRecognizer()..onTap = () => openPrivacyPolicy(context);

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final link = AppTextStyles.body(
      size: 11.5,
      weight: FontWeight.w700,
      color: AppColors.teamGold,
      height: 1.5,
    ).copyWith(decoration: TextDecoration.underline);
    return Text.rich(
      TextSpan(
        text: 'By continuing you agree to the ',
        children: [
          TextSpan(text: 'Terms of Service', style: link, recognizer: _terms),
          const TextSpan(text: ' and '),
          TextSpan(text: 'Privacy Policy', style: link, recognizer: _privacy),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
      style: AppTextStyles.body(size: 11.5, color: const Color(0xFFCFC4B4), height: 1.5),
    );
  }
}
