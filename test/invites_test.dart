import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:squad_hq/core/di/injection_container.dart';
import 'package:squad_hq/features/invites/domain/entities/group_invite.dart';
import 'package:squad_hq/features/invites/domain/repositories/invite_repository.dart';
import 'package:squad_hq/features/invites/presentation/pages/invitations_page.dart';
import 'package:squad_hq/features/invites/presentation/widgets/group_invite_actions.dart';
import 'package:squad_hq/features/invites/presentation/widgets/invite_people_sheet.dart';
import 'package:squad_hq/features/notifications/domain/entities/app_notification.dart';
import 'package:squad_hq/features/team_membership/domain/entities/team.dart';
import 'package:squad_hq/features/team_membership/presentation/bloc/team_membership_bloc.dart';

import 'fake_invite_repository.dart';
import 'test_helpers.dart';

void main() {
  final fakeInvites = FakeInviteRepository();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initTestSupabase();
    await initDependencies();
    sl
      ..unregister<InviteRepository>()
      ..registerLazySingleton<InviteRepository>(() => fakeInvites);
  });

  setUp(fakeInvites.reset);

  Widget app(Widget child) => BlocProvider(
    create: (_) => sl<TeamMembershipBloc>(),
    child: MaterialApp(home: child),
  );

  GroupInvite invite(String id, String team, {GroupKind kind = GroupKind.team}) => GroupInvite(
    id: id,
    teamId: 'team-$id',
    teamName: team,
    kind: kind,
    memberCount: 8,
    invitedByName: 'Aung Ko',
    createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
  );

  test('Admins and super admins can invite; players cannot', () {
    expect(canInvite(TeamRole.superAdmin), isTrue);
    expect(canInvite(TeamRole.admin), isTrue);
    expect(canInvite(TeamRole.player), isFalse);
  });

  test('An invitation notification opens the Invitations screen', () {
    expect(NotificationKind.fromDb('group_invite'), NotificationKind.groupInvite);
    final notification = AppNotification(
      id: 'n-1',
      kind: NotificationKind.groupInvite,
      title: 'Aung Ko invited you to Sunday FC',
      body: 'Join the team in Squad HQ — accept or decline in Invitations.',
      createdAt: DateTime(2026, 10, 19),
    );
    expect(notification.target, NotificationTarget.invitations);
  });

  testWidgets('Invitations list each group, who invited you, and its size', (tester) async {
    fakeInvites.invites.addAll([invite('1', 'Sunday FC'), invite('2', 'Hua Hin trip', kind: GroupKind.squad)]);
    await tester.pumpWidget(app(const InvitationsPage()));
    await tester.pumpAndSettle();

    expect(find.text('Sunday FC'), findsOneWidget);
    expect(find.text('Football team · 8 members'), findsOneWidget);
    expect(find.text('Hua Hin trip'), findsOneWidget);
    expect(find.text('Squad · 8 members'), findsOneWidget);
    expect(find.textContaining('Aung Ko invited you'), findsNWidgets(2));
  });

  testWidgets('Accept joins and Decline drops, each leaving the list', (tester) async {
    fakeInvites.invites.addAll([invite('1', 'Sunday FC'), invite('2', 'Hua Hin trip')]);
    await tester.pumpWidget(app(const InvitationsPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Accept').first);
    await tester.pumpAndSettle();
    expect(fakeInvites.answers, [('1', true)]);
    expect(find.text('You joined Sunday FC'), findsOneWidget);
    expect(find.text('Sunday FC'), findsNothing);

    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();
    expect(fakeInvites.answers.last, ('2', false));
    expect(find.text('No invitations right now.'), findsOneWidget);
  });

  testWidgets('A refused answer (say, already in 3 teams) keeps the invitation', (tester) async {
    fakeInvites
      ..invites.add(invite('1', 'Sunday FC'))
      ..failNextAnswer = 'You can only be in up to 3 teams';
    await tester.pumpWidget(app(const InvitationsPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    expect(find.text('You can only be in up to 3 teams'), findsOneWidget);
    expect(find.text('Sunday FC'), findsOneWidget);
  });

  testWidgets('Invite people: search your groups by name or @username, then invite', (tester) async {
    fakeInvites.people.addAll(const [
      InviteCandidate(profileId: 'p-1', name: 'Aung Ko', username: 'aungko'),
      InviteCandidate(profileId: 'p-2', name: 'Min Thu', username: 'minthu'),
    ]);
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => Scaffold(
            body: GroupInviteActions(teamId: 'team-9', groupName: 'Sunday FC'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Invite people'));
    await tester.pumpAndSettle();
    expect(find.text('Invite to Sunday FC'), findsOneWidget);
    expect(find.text('Aung Ko'), findsOneWidget);
    expect(find.text('Min Thu'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('invite-search')), '@min');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Aung Ko'), findsNothing);
    expect(find.text('@minthu'), findsOneWidget);

    await tester.tap(find.text('Invite'));
    await tester.pumpAndSettle();
    expect(fakeInvites.sent, [('team-9', 'p-2')]);
    expect(find.text('Invited'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('invite-search')), 'nobody');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('No one from your groups matches.'), findsOneWidget);
  });

  testWidgets('Pending invites shows a count, lists who, and an admin can cancel one', (tester) async {
    fakeInvites.people.add(const InviteCandidate(profileId: 'p-2', name: 'Min Thu', username: 'minthu'));
    await tester.pumpWidget(
      app(const Scaffold(body: GroupInviteActions(teamId: 'team-9', groupName: 'Sunday FC'))),
    );
    await tester.pumpAndSettle();
    final count = find.descendant(of: find.byKey(const ValueKey('pending-invites')), matching: find.text('0'));
    expect(count, findsOneWidget);

    // Inviting from the sheet bumps the count once it closes.
    await tester.tap(find.text('Invite people'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Invite'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byKey(const ValueKey('pending-invites')), matching: find.text('1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('pending-invites')));
    await tester.pumpAndSettle();
    expect(find.text('Min Thu'), findsOneWidget);
    expect(find.textContaining('@minthu · Invited by Test Player'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(fakeInvites.cancelled, ['inv-p-2']);
    expect(find.text('No pending invites.'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(count, findsOneWidget);
  });
}
