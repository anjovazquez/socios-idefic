import 'package:flutter/foundation.dart';

import '../../application/app_use_cases.dart';
import '../../domain/member/club_member.dart';
import '../../domain/payment/payment.dart';
import '../payment/payment_labels.dart';
import '../../domain/season/season.dart';
import '../../domain/season/season_membership.dart';
import '../season/seasons_view_model.dart';

class MembersViewModel extends ChangeNotifier {
  MembersViewModel(this._useCases, {required this.clubId});

  final AppUseCases _useCases;
  final String clubId;

  List<ClubMember> _members = const [];
  List<ClubMember> get members => _members;

  int _total = 0;
  int get total => _total;

  bool get hasMore => _members.length < _total;

  String _query = '';
  String get query => _query;

  MemberStatus? _status;
  MemberStatus? get status => _status;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _loadError;
  String? get loadError => _loadError;

  /// Ignores answers of searches that were replaced while loading.
  int _request = 0;

  Future<void> load() => _fetch(reset: true);

  Future<void> search(String query) {
    _query = query;
    return _fetch(reset: true);
  }

  Future<void> filter(MemberStatus? status) {
    _status = status;
    return _fetch(reset: true);
  }

  Future<void> loadMore() =>
      hasMore && !_isLoading ? _fetch(reset: false) : Future.value();

  Future<void> _fetch({required bool reset}) async {
    final request = ++_request;
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      final page = await _useCases.getClubMembers(
        clubId,
        query: _query,
        status: _status,
        offset: reset ? 0 : _members.length,
      );
      if (request != _request) return;
      _members = reset ? page.members : [..._members, ...page.members];
      _total = page.total;
    } on MemberFailure catch (failure) {
      if (request == _request) _loadError = messageFor(failure);
    } catch (_) {
      if (request == _request) {
        _loadError = messageFor(const MemberUnavailableFailure());
      }
    } finally {
      if (request == _request) {
        _isLoading = false;
        notifyListeners();
      }
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

  Future<String> deactivate(ClubMember member) async {
    await _guard(() => _useCases.deactivateMember(member));
    await load();
    return '${member.displayName} ha causado baja en el club';
  }

  Future<String> reactivate(ClubMember member) async {
    final status = await _guard(() => _useCases.reactivateMember(member));
    await load();
    return status == MemberStatus.invited
        ? '${member.displayName} vuelve como invitado: reenvíale la invitación'
        : '${member.displayName} vuelve a ser socio del club';
  }

  /// Changes the fee of [member] in the active season (RF-010).
  Future<String> changeFee(ClubMember member, String fee) async {
    await _guard(
      () => _useCases.setMemberFee(
        seasonMembershipId: member.seasonMembershipId!,
        fee: fee,
      ),
    );
    await load();
    return 'Cuota de ${member.displayName} actualizada';
  }

  Future<String> regenerateCard(ClubMember member) async {
    try {
      await _useCases.regenerateCard(member.seasonMembershipId!);
    } catch (_) {
      throw messageFor(const MemberUnavailableFailure());
    }
    return 'Carnet de ${member.displayName} regenerado: el QR anterior ya no '
        'sirve';
  }

  Future<List<Payment>> payments(ClubMember member) =>
      member.seasonMembershipId == null
      ? Future.value(const [])
      : _useCases.getSeasonPayments(member.seasonMembershipId!);

  /// Records a fee paid outside the app (transfer, Bizum, cash).
  Future<String> recordPayment(
    ClubMember member, {
    required PaymentMethod method,
    required String amount,
    required String reference,
  }) async {
    await _payment(
      () => _useCases.recordManualPayment(
        seasonMembershipId: member.seasonMembershipId!,
        method: method,
        amount: amount,
        reference: reference,
      ),
    );
    await load();
    return 'Pago de ${member.displayName} registrado';
  }

  Future<String> cancelPayment(ClubMember member, Payment payment) async {
    await _payment(() => _useCases.cancelPayment(payment));
    await load();
    return 'Pago anulado';
  }

  Future<void> _payment(Future<void> Function() action) async {
    try {
      await action();
    } on PaymentFailure catch (failure) {
      throw paymentFailureMessage(failure);
    }
  }

  Future<List<MemberSeason>> seasons(ClubMember member) =>
      _useCases.getMemberSeasons(member.membershipId);

  Future<String?> photoUrl(ClubMember member) =>
      _useCases.getMemberPhotoUrl(member);

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on MemberFailure catch (failure) {
      throw messageFor(failure);
    } on InvalidSeasonDataFailure catch (failure) {
      throw failure.field == SeasonField.fee
          ? 'Escribe una cuota válida (0 € o más)'
          : SeasonsViewModel.messageFor(failure);
    } on SeasonFailure catch (failure) {
      throw SeasonsViewModel.messageFor(failure);
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
    CannotDeactivateAdminFailure() =>
      'El administrador del club no puede darse de baja',
    InvitationNotPendingFailure() =>
      'Esta persona ya activó su cuenta; no hace falta reenviar',
    MemberPermissionFailure() =>
      'Solo el administrador del club puede gestionar socios',
    MemberUnavailableFailure() =>
      'No hemos podido conectar. Inténtalo de nuevo en un momento',
  };
}
