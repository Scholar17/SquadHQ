import 'package:flutter/widgets.dart';

import '../../../squad/presentation/active_group.dart';

/// One tab slot of the app shell, showing the football [team] page or the
/// [squad] page depending on the active group's kind — so the shell keeps
/// one set of branches (and routes) for both.
class GroupTab extends StatelessWidget {
  const GroupTab({super.key, required this.team, required this.squad});

  final Widget team;
  final Widget squad;

  @override
  Widget build(BuildContext context) =>
      (watchActiveGroup(context)?.isSquad ?? false) ? squad : team;
}
