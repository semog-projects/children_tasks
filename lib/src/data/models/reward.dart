import 'package:cloud_firestore/cloud_firestore.dart';

/// Recompensa resgatável com pontos.
class Reward {
  const Reward({
    required this.id,
    required this.title,
    this.description,
    required this.cost,
    this.active = true,
    this.stock,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String? description;
  final int cost;
  final bool active;

  /// `null` = estoque ilimitado.
  final int? stock;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get inStock => stock == null || stock! > 0;

  factory Reward.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Reward(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String?,
      cost: (data['cost'] as num?)?.toInt() ?? 0,
      active: data['active'] as bool? ?? true,
      stock: (data['stock'] as num?)?.toInt(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toWriteData() => {
        'title': title,
        if (description != null) 'description': description,
        'cost': cost,
        'active': active,
        'stock': stock,
      };

  Reward copyWith({
    String? title,
    String? description,
    int? cost,
    bool? active,
    int? stock,
  }) =>
      Reward(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        cost: cost ?? this.cost,
        active: active ?? this.active,
        stock: stock ?? this.stock,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
