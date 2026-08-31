/// Perfil ativo no app. `guardian` libera tudo; `child` é a visão simplificada
/// de uma criança; `none` mostra o seletor de perfil.
sealed class ActiveProfile {
  const ActiveProfile();

  const factory ActiveProfile.none() = ProfileNone;
  const factory ActiveProfile.guardian() = ProfileGuardian;
  const factory ActiveProfile.child(String memberId) = ProfileChild;

  bool get isGuardian => this is ProfileGuardian;
  bool get isChild => this is ProfileChild;

  String? get childId => switch (this) {
        ProfileChild(:final memberId) => memberId,
        _ => null,
      };

  /// Serialização para o `shared_preferences`.
  String encode() => switch (this) {
        ProfileNone() => 'none',
        ProfileGuardian() => 'guardian',
        ProfileChild(:final memberId) => 'child:$memberId',
      };

  static ActiveProfile decode(String? raw) {
    if (raw == 'guardian') return const ProfileGuardian();
    if (raw != null && raw.startsWith('child:')) {
      return ProfileChild(raw.substring('child:'.length));
    }
    return const ProfileNone();
  }
}

final class ProfileNone extends ActiveProfile {
  const ProfileNone();
}

final class ProfileGuardian extends ActiveProfile {
  const ProfileGuardian();
}

final class ProfileChild extends ActiveProfile {
  const ProfileChild(this.memberId);
  final String memberId;

  @override
  bool operator ==(Object other) =>
      other is ProfileChild && other.memberId == memberId;

  @override
  int get hashCode => memberId.hashCode;
}
