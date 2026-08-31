import 'package:cloud_firestore/cloud_firestore.dart';

enum MemberType {
  guardian,
  child;

  static MemberType fromName(String? value) =>
      MemberType.values.firstWhere((t) => t.name == value, orElse: () => MemberType.child);
}

/// Um integrante da família: responsável ou criança.
class Member {
  const Member({
    required this.id,
    required this.type,
    required this.displayName,
    this.avatarColor,
    this.photoUrl,
    this.linkedUid,
    this.pinHash,
    this.birthDate,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final MemberType type;
  final String displayName;
  final String? avatarColor;
  final String? photoUrl;

  /// Responsável: seu `auth.uid`. Criança: reservado para login futuro.
  final String? linkedUid;

  /// Hash do PIN do responsável (issue #8). Nunca o PIN em claro.
  final String? pinHash;

  final DateTime? birthDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isGuardian => type == MemberType.guardian;
  bool get isChild => type == MemberType.child;

  factory Member.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Member(
      id: doc.id,
      type: MemberType.fromName(data['type'] as String?),
      displayName: data['displayName'] as String? ?? '',
      avatarColor: data['avatarColor'] as String?,
      photoUrl: data['photoUrl'] as String?,
      linkedUid: data['linkedUid'] as String?,
      pinHash: data['pinHash'] as String?,
      birthDate: (data['birthDate'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toWriteData() => {
        'type': type.name,
        'displayName': displayName,
        if (avatarColor != null) 'avatarColor': avatarColor,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (linkedUid != null) 'linkedUid': linkedUid,
        if (pinHash != null) 'pinHash': pinHash,
        if (birthDate != null) 'birthDate': Timestamp.fromDate(birthDate!),
      };

  Member copyWith({
    String? displayName,
    String? avatarColor,
    String? photoUrl,
    String? linkedUid,
    String? pinHash,
    DateTime? birthDate,
  }) =>
      Member(
        id: id,
        type: type,
        displayName: displayName ?? this.displayName,
        avatarColor: avatarColor ?? this.avatarColor,
        photoUrl: photoUrl ?? this.photoUrl,
        linkedUid: linkedUid ?? this.linkedUid,
        pinHash: pinHash ?? this.pinHash,
        birthDate: birthDate ?? this.birthDate,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
