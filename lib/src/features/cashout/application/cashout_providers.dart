import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/firebase/firebase_providers.dart';
import '../../../data/data_providers.dart';
import '../../../data/models/cash_out.dart';
import '../../../data/models/family.dart';
import '../../../data/models/member.dart';
import '../../auth/application/auth_providers.dart';
import '../../family/application/family_providers.dart';

/// Cotação do câmbio da família atual (centavos de BRL por ponto).
final pointValueCentsProvider = Provider<double>((ref) {
  final family = ref.watch(currentFamilyProvider).asData?.value;
  return family?.pointValueCents ?? Family.defaultPointValueCents;
});

/// Fila do responsável: pedidos aguardando decisão ou pagamento.
final pendingCashOutsProvider = StreamProvider<List<CashOut>>((ref) {
  final family = ref.watch(currentFamilyProvider).asData?.value;
  if (family == null) return Stream.value(const []);
  return ref.watch(cashOutRepositoryProvider).watchPending(family.id);
});

/// Pedidos de câmbio de uma criança (visão do responsável).
final childCashOutsProvider =
    StreamProvider.family<List<CashOut>, String>((ref, memberId) {
  final family = ref.watch(currentFamilyProvider).asData?.value;
  if (family == null) return Stream.value(const []);
  return ref.watch(cashOutRepositoryProvider).watchForMember(family.id, memberId);
});

/// Pedidos da própria criança logada — filtra por `memberUid` (rules #34).
final myCashOutsProvider = StreamProvider<List<CashOut>>((ref) {
  final family = ref.watch(childFamilyProvider).asData?.value;
  final uid = ref.watch(currentUserProvider)?.uid;
  if (family == null || uid == null) return Stream.value(const []);
  return ref.watch(cashOutRepositoryProvider).watchForMemberUid(family.id, uid);
});

/// Erro de negócio no câmbio (saldo, valor inválido…), com mensagem pt-BR.
class CashOutException implements Exception {
  const CashOutException(this.message);
  final String message;
}

/// Pedir, aprovar, recusar, pagar e cancelar câmbios (issue #66). Espelha
/// `RedemptionController`.
class CashOutController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  String get _familyId => ref.read(currentFamilyIdProvider);

  /// Pede a troca de [points] pontos (múltiplo de 5) da criança [child].
  /// O responsável também pode chamar (para qualquer criança).
  Future<void> request({required Member child, required int points}) async {
    state = const AsyncLoading();
    try {
      await ref.read(functionsProvider).httpsCallable('requestCashOut').call<dynamic>({
        'familyId': _familyId,
        'memberId': child.id,
        'points': points,
      });
      state = const AsyncData(null);
    } on FirebaseFunctionsException catch (e, st) {
      state = AsyncError(
        CashOutException(e.message ?? 'Não foi possível pedir a troca.'),
        st,
      );
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Aprova (débito transacional dos pontos, feito pela Function).
  Future<void> approve(String cashOutId) async {
    state = const AsyncLoading();
    try {
      await ref.read(functionsProvider).httpsCallable('approveCashOut').call<dynamic>({
        'familyId': _familyId,
        'cashOutId': cashOutId,
      });
      state = const AsyncData(null);
    } on FirebaseFunctionsException catch (e, st) {
      state = AsyncError(
        CashOutException(e.message ?? 'Não foi possível aprovar.'),
        st,
      );
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> reject(String cashOutId, {String? note}) async {
    final uid = ref.read(currentUserProvider)!.uid;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(cashOutRepositoryProvider)
          .reject(_familyId, cashOutId, uid, note: note),
    );
  }

  Future<void> markPaid(String cashOutId) async {
    final uid = ref.read(currentUserProvider)!.uid;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(cashOutRepositoryProvider).markPaid(_familyId, cashOutId, uid),
    );
  }

  Future<void> cancel(String cashOutId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(cashOutRepositoryProvider).cancel(_familyId, cashOutId),
    );
  }
}

final cashOutControllerProvider =
    AsyncNotifierProvider<CashOutController, void>(CashOutController.new);
