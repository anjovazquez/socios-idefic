import 'package:flutter/foundation.dart';

import '../../application/app_use_cases.dart';
import '../../domain/member/club_member.dart';

class MembersViewModel extends ChangeNotifier {
  MembersViewModel(this._useCases, {required this.clubId});

  final AppUseCases _useCases;
  final String clubId;

  List<ClubMember> _members = const [];
  List<ClubMember> get members => _members;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _loadError;
  String? get loadError => _loadError;

  Future<void> load() async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      _members = await _useCases.getClubMembers(clubId);
    } on MemberFailure catch (failure) {
      _loadError = messageFor(failure);
    } catch (_) {
      _loadError = messageFor(const MemberUnavailableFailure());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Returns the confirmation to show, or throws the error message.
  Future<String> invite({
    required String firstName,
    required String email,
  }) async {
    final outcome = await _guard(
      () => _useCases.inviteMember(
        clubId: clubId,
        email: email,
        firstName: firstName,
      ),
    );
    await load();
    final normalized = email.trim().toLowerCase();
    return switch (outcome) {
      InvitationOutcome.invited => 'Invitación enviada a $normalized',
      InvitationOutcome.addedExistingAccount =>
        '$normalized ya tenía cuenta: ahora también es socio del club',
    };
  }

  Future<String> changeNumber(ClubMember member, String number) async {
    await _guard(
      () => _useCases.setMemberNumber(
        membershipId: member.membershipId,
        number: number,
      ),
    );
    await load();
    return 'Número de socio actualizado';
  }

  Future<String> resend(ClubMember member) async {
    await _guard(() => _useCases.resendInvitation(member.membershipId));
    await load();
    return 'Nueva invitación enviada a ${member.email}';
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on MemberFailure catch (failure) {
      throw messageFor(failure);
    } catch (error) {
      if (error is String) rethrow;
      throw messageFor(const MemberUnavailableFailure());
    }
  }

  static String messageFor(MemberFailure failure) => switch (failure) {
    InvalidMemberDataFailure(field: MemberField.name) =>
      'Escribe el nombre del socio',
    InvalidMemberDataFailure(field: MemberField.email) =>
      'Escribe un email válido',
    InvalidMemberDataFailure(field: MemberField.memberNumber) =>
      'Escribe un número mayor que 0',
    AlreadyMemberFailure() => 'Esta persona ya es socia del club',
    MemberNumberTakenFailure() => 'Ese número ya está asignado',
    InvitationNotPendingFailure() =>
      'Esta persona ya activó su cuenta; no hace falta reenviar',
    MemberPermissionFailure() =>
      'Solo el administrador del club puede dar de alta socios',
    MemberUnavailableFailure() =>
      'No hemos podido conectar. Inténtalo de nuevo en un momento',
  };
}
