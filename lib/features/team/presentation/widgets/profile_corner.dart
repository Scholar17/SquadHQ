import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/domain/entities/app_user.dart';

/// [child] with your profile button in the top-right corner — for the tabs'
/// "not on a team yet" screens, which have no header of their own, so
/// Profile (and Log out) is still a tap away.
class ProfileCorner extends StatelessWidget {
  const ProfileCorner({super.key, required this.user, required this.child});

  final AppUser user;
  final Widget child;

  String get _initials {
    final source = user.username ?? user.name;
    return source.isNotEmpty ? source[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Semantics(
                button: true,
                label: 'Your profile',
                child: GestureDetector(
                  onTap: () => context.push(AppRoutes.profile, extra: user),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: AppColors.neutral300, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(
                      _initials,
                      style: AppTextStyles.body(size: 12, weight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
