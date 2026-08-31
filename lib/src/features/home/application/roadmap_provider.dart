import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Item do roadmap exibido na tela inicial enquanto o app está em bootstrap.
class RoadmapItem {
  const RoadmapItem({required this.issue, required this.title});

  final int issue;
  final String title;
}

/// Fonte temporária: espelha o backlog da Sprint 1 (GitHub Project #13).
/// Será substituído pelos dados reais de tarefas quando a feature existir.
final roadmapProvider = Provider<List<RoadmapItem>>((ref) {
  return const [
    RoadmapItem(issue: 4, title: 'Configurar Firebase (Auth, Firestore, FCM)'),
    RoadmapItem(issue: 5, title: 'Autenticação com Google Sign-In'),
    RoadmapItem(issue: 6, title: 'Modelo de dados e regras do Firestore'),
    RoadmapItem(issue: 7, title: 'Cadastro e gestão da família'),
    RoadmapItem(issue: 8, title: 'Perfis: modo responsável e modo criança'),
    RoadmapItem(issue: 9, title: 'CRUD de tarefas com pontos e categorias'),
  ];
});
