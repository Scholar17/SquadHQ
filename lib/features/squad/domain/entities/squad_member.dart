import 'package:equatable/equatable.dart';

import '../../../team_membership/domain/entities/team.dart';

/// Someone in the squad, with how friends can pay them.
class SquadMember extends Equatable {
  const SquadMember({
    required this.profileId,
    required this.name,
    required this.role,
    this.avatarUrl,
    this.walletQrPath,
    this.bankName,
    this.bankAccountName,
    this.bankAccountNo,
  });

  final String profileId;
  final String name;
  final TeamRole role;
  final String? avatarUrl;
  final String? walletQrPath;
  final String? bankName;
  final String? bankAccountName;
  final String? bankAccountNo;

  bool get isAdmin => role != TeamRole.player;

  bool get hasQr => walletQrPath != null;

  bool get hasBankDetails => bankAccountNo != null && bankAccountNo!.isNotEmpty;

  /// "Owner · Admin · Member" — the squad words for the team roles.
  String get roleLabel => switch (role) {
    TeamRole.superAdmin => 'Owner',
    TeamRole.admin => 'Admin',
    TeamRole.player => 'Member',
  };

  String get initial => name.isEmpty ? '?' : String.fromCharCode(name.runes.first).toUpperCase();

  @override
  List<Object?> get props => [
    profileId,
    name,
    role,
    avatarUrl,
    walletQrPath,
    bankName,
    bankAccountName,
    bankAccountNo,
  ];
}

/// Your own bank details, for the profile page.
class BankDetails extends Equatable {
  const BankDetails({this.bankName, this.accountName, this.accountNo});

  final String? bankName;
  final String? accountName;
  final String? accountNo;

  bool get isEmpty => (accountNo ?? '').isEmpty;

  @override
  List<Object?> get props => [bankName, accountName, accountNo];
}
