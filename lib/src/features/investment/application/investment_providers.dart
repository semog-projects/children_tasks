import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/firebase/firebase_providers.dart';
import '../../../data/data_providers.dart';
import '../../../data/models/family.dart';
import '../../../data/models/investment_lot.dart';
import '../../../data/models/investment_request.dart';
import '../../../data/models/member.dart';
import '../../auth/application/auth_providers.dart';
import '../../child/application/child_providers.dart';
import '../../family/application/family_providers.dart';

/// Configuração da poupança da família: (% por semana, dias de carência).
final investmentConfigProvider =
    Provider<({double weeklyRatePct, int graceDays})>((ref) {
  final family = ref.watch(currentFamilyProvider).asData?.value;
  return (
    weeklyRatePct:
        family?.investmentWeeklyRatePct ?? Family.defaultInvestmentWeeklyRatePct,
    graceDays: family?.investmentGraceDays ?? Family.defaultInvestmentGraceDays,
  );
});

/// Fila do responsável: pedidos de poupança aguardando decisão.
final pendingInvestmentRequestsProvider =
    StreamProvider<List<InvestmentRequest>>((ref) {
  final family = ref.watch(currentFamilyProvider).asData?.value;
  if (family == null) return Stream.value(const []);
  return ref.watch(investmentRepositoryProvider).watchPending(family.id);
});

/// Lotes da poupança de uma criança (visão do responsável).
final childInvestmentLotsProvider =
    StreamProvider.family<List<InvestmentLot>, String>((ref, memberId) {
  final family = ref.watch(currentFamilyProvider).asData?.value;
  if (family == null) return Stream.value(const []);
  return ref.watch(investmentRepositoryProvider).watchLots(family.id, memberId);
});

final childInvestmentRequestsProvider =
    StreamProvider.family<List<InvestmentRequest>, String>((ref, memberId) {
  final family = ref.watch(currentFamilyProvider).asData?.value;
  if (family == null) return Stream.value(const []);
  return ref
      .watch(investmentRepositoryProvider)
      .watchRequestsForMember(family.id, memberId);
});

/// Lotes da própria criança logada — filtra por `memberUid` (rules #34).
final myInvestmentLotsProvider = StreamProvider<List<InvestmentLot>>((ref) {
  final family = ref.watch(childFamilyProvider).asData?.value;
  final member = ref.watch(currentChildMemberProvider);
  final uid = ref.watch(currentUserProvider)?.uid;
  if (family == null || member == null || uid == null) {
    return Stream.value(const []);
  }
  return ref
      .watch(investmentRepositoryProvider)
      .watchLotsByUid(family.id, member.id, uid);
});

final myInvestmentRequestsProvider =
    StreamProvider<List<InvestmentRequest>>((ref) {
  final family = ref.watch(childFamilyProvider).asData?.value;
  final uid = ref.watch(currentUserProvider)?.uid;
  if (family == null || uid == null) return Stream.value(const []);
  return ref
      .watch(investmentRepositoryProvider)
      .watchRequestsByUid(family.id, uid);
});

/// Erro de negócio na poupança, com mensagem pt-BR pronta pra SnackBar.
class InvestmentException implements Exception {
  const InvestmentException(this.message);
  final String message;
}

/// Pedir aporte/resgate, aprovar, recusar e cancelar (issue #73). Espelha
/// `CashOutController`.
class InvestmentController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  String get _familyId => ref.read(currentFamilyIdProvider);

  Future<void> _callRequest(Map<String, dynamic> data, String fallback) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(functionsProvider)
          .httpsCallable('requestInvestment')
          .call<dynamic>({'familyId': _familyId, ...data});
      state = const AsyncData(null);
    } on FirebaseFunctionsException catch (e, st) {
      state = AsyncError(InvestmentException(e.message ?? fallback), st);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Pede o aporte de [points] pontos da criança [child].
  Future<void> requestDeposit(
      {required Member child, required int points}) {
    return _callRequest(
      {'memberId': child.id, 'kind': 'deposit', 'points': points},
      'Não foi possível pedir o investimento.',
    );
  }

  /// Pede o resgate total da poupança da criança [child].
  Future<void> requestWithdraw({required Member child}) {
    return _callRequest(
      {'memberId': child.id, 'kind': 'withdraw'},
      'Não foi possível pedir o resgate.',
    );
  }

  /// Aprova um pedido (débito/crédito transacional feito pela Function).
  Future<void> approve(String reqId) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(functionsProvider)
          .httpsCallable('approveInvestment')
          .call<dynamic>({'familyId': _familyId, 'reqId': reqId});
      state = const AsyncData(null);
    } on FirebaseFunctionsException catch (e, st) {
      state = AsyncError(
        InvestmentException(e.message ?? 'Não foi possível aprovar.'),
        st,
      );
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> reject(String reqId, {String? note}) async {
    final uid = ref.read(currentUserProvider)!.uid;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(investmentRepositoryProvider)
          .reject(_familyId, reqId, uid, note: note),
    );
  }

  Future<void> cancel(String reqId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(investmentRepositoryProvider).cancel(_familyId, reqId),
    );
  }
}

final investmentControllerProvider =
    AsyncNotifierProvider<InvestmentController, void>(InvestmentController.new);
