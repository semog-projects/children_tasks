import 'package:childrentasks/src/data/firestore_refs.dart';
import 'package:childrentasks/src/data/models/family.dart';
import 'package:childrentasks/src/data/models/ledger_entry.dart';
import 'package:childrentasks/src/data/models/member.dart';
import 'package:childrentasks/src/data/models/reward.dart';
import 'package:childrentasks/src/data/models/task.dart';
import 'package:childrentasks/src/data/repositories/family_repository.dart';
import 'package:childrentasks/src/data/repositories/ledger_repository.dart';
import 'package:childrentasks/src/data/repositories/member_repository.dart';
import 'package:childrentasks/src/data/repositories/reward_repository.dart';
import 'package:childrentasks/src/data/repositories/task_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreRefs refs;

  setUp(() {
    db = FakeFirebaseFirestore();
    refs = FirestoreRefs(db);
  });

  test('FamilyRepository: cria com o criador como responsável e consulta por uid',
      () async {
    final repo = FamilyRepository(refs);
    final id = await repo.create(
      const Family(id: '', name: 'Silva', guardianUids: [], timezone: 'America/Sao_Paulo'),
      creator: const GuardianRef(uid: 'uid-1', displayName: 'Ana'),
    );

    final family = await repo.get(id);
    expect(family!.name, 'Silva');
    expect(family.guardianUids, ['uid-1']);
    expect(family.guardianFor('uid-1')?.displayName, 'Ana');

    final list = await repo.watchForGuardian('uid-1').first;
    expect(list.single.id, id);

    final none = await repo.watchForGuardian('outro').first;
    expect(none, isEmpty);
  });

  test('MemberRepository: adiciona, filtra crianças e remove', () async {
    final repo = MemberRepository(refs);
    await repo.add('f1', const Member(id: '', type: MemberType.guardian, displayName: 'Pai'));
    final childId = await repo.add(
      'f1',
      const Member(id: '', type: MemberType.child, displayName: 'Bia'),
    );

    final all = await repo.watchAll('f1').first;
    expect(all.length, 2);

    final children = await repo.watchChildren('f1').first;
    expect(children.single.displayName, 'Bia');

    await repo.remove('f1', childId);
    expect((await repo.watchChildren('f1').first), isEmpty);
  });

  test('TaskRepository: create, watchActive e archive', () async {
    final repo = TaskRepository(refs);
    final id = await repo.create(
      'f1',
      Task(
        id: '',
        title: 'Arrumar a cama',
        points: 10,
        category: TaskCategory.routine,
        recurrence: Recurrence(type: RecurrenceType.daily, startDate: DateTime(2026, 8, 15)),
      ),
    );

    expect((await repo.watchActive('f1').first).single.title, 'Arrumar a cama');

    await repo.archive('f1', id);
    expect(await repo.watchActive('f1').first, isEmpty);

    final archived = await repo.get('f1', id);
    expect(archived!.active, isFalse);
  });

  test('RewardRepository: watchActive ignora inativas', () async {
    final repo = RewardRepository(refs);
    await repo.create('f1', const Reward(id: '', title: 'Sorvete', cost: 50));
    await repo.create('f1', const Reward(id: '', title: 'Cinema', cost: 200, active: false));

    expect((await repo.watchActive('f1').first).single.title, 'Sorvete');
    expect((await repo.watchAll('f1').first).length, 2);
  });

  test('LedgerRepository: saldo é a soma das entradas', () async {
    final repo = LedgerRepository(refs);
    await repo.addAdjustment('f1', memberId: 'm1', points: 30, createdByUid: 'g1');
    await repo.addAdjustment('f1', memberId: 'm1', points: -10, createdByUid: 'g1');
    await repo.addAdjustment('f1', memberId: 'm2', points: 100, createdByUid: 'g1');

    expect(await repo.watchBalance('f1', 'm1').first, 20);
    expect(await repo.watchBalance('f1', 'm2').first, 100);

    final entries = await repo.watchForMember('f1', 'm1').first;
    expect(entries.length, 2);
    expect(entries.every((e) => e.type == LedgerEntryType.adjustment), isTrue);
  });

  test('modelos: round-trip de Task com recorrência semanal', () async {
    final repo = TaskRepository(refs);
    final id = await repo.create(
      'f1',
      Task(
        id: '',
        title: 'Estudar',
        description: 'Ler 15 min',
        points: 5,
        category: TaskCategory.study,
        assigneeMemberId: 'm1',
        requiresApproval: false,
        recurrence: Recurrence(
          type: RecurrenceType.weekly,
          daysOfWeek: const [1, 3, 5],
          startDate: DateTime(2026, 8, 15),
          endDate: DateTime(2026, 12, 20),
        ),
      ),
    );

    final task = await repo.get('f1', id);
    expect(task!.recurrence.type, RecurrenceType.weekly);
    expect(task.recurrence.daysOfWeek, [1, 3, 5]);
    expect(task.recurrence.endDate, DateTime(2026, 12, 20));
    expect(task.assigneeMemberId, 'm1');
    expect(task.requiresApproval, isFalse);
  });
}
