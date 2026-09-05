import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Corpo do `onRefresh` de um `RefreshIndicator`: roda [invalidate] (onde a
/// tela derruba seus `StreamProvider`s, que re-assinam e vão ao servidor) e um
/// trabalho extra opcional ([also], ex.: re-materializar as tarefas de hoje).
/// Segura o indicador por um mínimo de ~350ms pra não piscar.
Future<void> pullRefresh(
  WidgetRef ref, {
  void Function(WidgetRef ref)? invalidate,
  Future<void> Function()? also,
}) async {
  invalidate?.call(ref);
  await Future.wait<void>([
    Future<void>.delayed(const Duration(milliseconds: 350)),
    if (also != null) also(),
  ]);
}
