import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskCategory {
  routine('Rotina'),
  study('Estudos'),
  chores('Casa'),
  hygiene('Higiene'),
  other('Outros');

  const TaskCategory(this.label);

  final String label;

  static TaskCategory fromName(String? value) => TaskCategory.values
      .firstWhere((c) => c.name == value, orElse: () => TaskCategory.other);
}

enum RecurrenceType {
  once('Uma vez'),
  daily('Todo dia'),
  weekly('Dias da semana');

  const RecurrenceType(this.label);

  final String label;

  static RecurrenceType fromName(String? value) => RecurrenceType.values
      .firstWhere((t) => t.name == value, orElse: () => RecurrenceType.once);
}

/// 1=Seg … 7=Dom.
const List<String> weekdayShortLabels = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

/// Regra de repetição de uma tarefa. `daysOfWeek`: 1=seg … 7=dom.
class Recurrence {
  const Recurrence({
    required this.type,
    this.daysOfWeek = const [],
    required this.startDate,
    this.endDate,
  });

  final RecurrenceType type;
  final List<int> daysOfWeek;
  final DateTime startDate;
  final DateTime? endDate;

  factory Recurrence.fromMap(Map<String, dynamic> map) => Recurrence(
        type: RecurrenceType.fromName(map['type'] as String?),
        daysOfWeek: (map['daysOfWeek'] as List<dynamic>? ?? const []).cast<int>(),
        startDate: (map['startDate'] as Timestamp?)?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0),
        endDate: (map['endDate'] as Timestamp?)?.toDate(),
      );

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'daysOfWeek': daysOfWeek,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': endDate == null ? null : Timestamp.fromDate(endDate!),
      };

  /// Resumo curto para exibição, ex.: "Todo dia", "Seg, Qua, Sex", "Uma vez".
  String get summary {
    switch (type) {
      case RecurrenceType.once:
        return 'Uma vez';
      case RecurrenceType.daily:
        return 'Todo dia';
      case RecurrenceType.weekly:
        if (daysOfWeek.isEmpty) return 'Semanal';
        final sorted = [...daysOfWeek]..sort();
        return sorted.map((d) => weekdayShortLabels[(d - 1) % 7]).join(', ');
    }
  }
}

/// Definição de uma tarefa. As ocorrências ficam em `taskInstances`.
class Task {
  const Task({
    required this.id,
    required this.title,
    this.description,
    required this.points,
    required this.category,
    this.assigneeMemberId,
    required this.recurrence,
    this.requiresApproval = true,
    this.active = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String? description;
  final int points;
  final TaskCategory category;

  /// `null` = vale para todas as crianças.
  final String? assigneeMemberId;

  final Recurrence recurrence;
  final bool requiresApproval;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Task.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Task(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String?,
      points: (data['points'] as num?)?.toInt() ?? 0,
      category: TaskCategory.fromName(data['category'] as String?),
      assigneeMemberId: data['assigneeMemberId'] as String?,
      recurrence: Recurrence.fromMap(
        (data['recurrence'] as Map<String, dynamic>?) ?? const {},
      ),
      requiresApproval: data['requiresApproval'] as bool? ?? true,
      active: data['active'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toWriteData() => {
        'title': title,
        'description': description,
        'points': points,
        'category': category.name,
        'assigneeMemberId': assigneeMemberId,
        'recurrence': recurrence.toMap(),
        'requiresApproval': requiresApproval,
        'active': active,
      };

  Task copyWith({
    String? title,
    String? description,
    int? points,
    TaskCategory? category,
    String? assigneeMemberId,
    Recurrence? recurrence,
    bool? requiresApproval,
    bool? active,
  }) =>
      Task(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        points: points ?? this.points,
        category: category ?? this.category,
        assigneeMemberId: assigneeMemberId ?? this.assigneeMemberId,
        recurrence: recurrence ?? this.recurrence,
        requiresApproval: requiresApproval ?? this.requiresApproval,
        active: active ?? this.active,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
