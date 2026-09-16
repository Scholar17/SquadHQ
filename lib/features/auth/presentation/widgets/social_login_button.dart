import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class SocialLoginButton extends StatelessWidget {
  const SocialLoginButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.badge,
  });

  factory SocialLoginButton.facebook({
    Key? key,
    required VoidCallback? onPressed,
  }) =>
      SocialLoginButton(
        key: key,
        label: 'Continue with Facebook',
        onPressed: onPressed,
        backgroundColor: const Color(0xFF3B5998),
        foregroundColor: AppColors.neutral100,
        badge: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(7),
          ),
          alignment: Alignment.center,
          child: const Text(
            'f',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      );

  factory SocialLoginButton.google({
    Key? key,
    required VoidCallback? onPressed,
  }) =>
      SocialLoginButton(
        key: key,
        label: 'Continue with Google',
        onPressed: onPressed,
        backgroundColor: AppColors.neutral100,
        foregroundColor: AppColors.text,
        badge: Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: AppColors.neutral300,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Text(
            'G',
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      );

  final String label;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final Widget badge;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: backgroundColor.withValues(alpha: 0.6),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          elevation: 0,
        ),
        child: Row(
          children: [
            badge,
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: foregroundColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
