import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/member.dart';
import '../../auth/application/auth_providers.dart';
import '../../family/application/family_providers.dart';

/// A criança (member) vinculada ao usuário logado, dentro da família em que
/// ele entra como criança. `null` enquanto carrega ou se o vínculo sumiu.
final currentChildMemberProvider = Provider<Member?>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  final family = ref.watch(childFamilyProvider).asData?.value;
  if (uid == null || family == null) return null;
  final children = ref.watch(familyChildrenProvider).asData?.value ?? const [];
  for (final member in children) {
    if (member.linkedUid == uid) return member;
  }
  return null;
});
