import 'package:flutter_test/flutter_test.dart';
import 'package:team_maker/data/team_history_repository.dart';
import 'package:team_maker/domain/participant.dart';
import 'package:team_maker/domain/team.dart';
import 'package:team_maker/domain/team_result.dart';
import 'package:team_maker/features/history/history_controller.dart';

void main() {
  test('a result appears only after save is requested', () async {
    final repository = MemoryHistoryRepository();
    final controller = HistoryController(repository);
    await controller.initialize();
    final value = result('1', '저장 전 결과');

    expect(controller.results, isEmpty);
    expect(await controller.saveResult(value), isTrue);
    expect(controller.results, [value]);
  });

  test('updating a title persists the changed historical result', () async {
    final repository = MemoryHistoryRepository()
      ..values.add(result('1', '원래 제목'));
    final controller = HistoryController(repository);
    await controller.initialize();

    expect(await controller.updateTitle('1', '수정 제목'), isTrue);

    expect(controller.results.single.title, '수정 제목');
    expect(repository.values.single.title, '수정 제목');
  });

  test('deleting a result removes it from persistent history', () async {
    final repository = MemoryHistoryRepository()
      ..values.add(result('1', '삭제할 결과'));
    final controller = HistoryController(repository);
    await controller.initialize();

    expect(await controller.deleteResult('1'), isTrue);

    expect(controller.results, isEmpty);
    expect(repository.values, isEmpty);
  });
}

TeamResult result(String id, String title) => TeamResult(
  id: id,
  title: title,
  createdAt: DateTime(2026, 9, 7),
  teamSize: 1,
  teams: [
    Team(
      number: 1,
      participants: [
        Participant(
          id: 'p-$id',
          name: '회원',
          score: 180,
          type: ParticipantType.regular,
        ),
      ],
    ),
  ],
);

class MemoryHistoryRepository implements TeamHistoryRepository {
  final List<TeamResult> values = [];

  @override
  Future<List<TeamResult>> loadAll() async => [...values];

  @override
  Future<void> save(TeamResult result) async {
    final index = values.indexWhere((value) => value.id == result.id);
    if (index == -1) {
      values.add(result);
    } else {
      values[index] = result;
    }
  }

  @override
  Future<void> delete(String resultId) async {
    values.removeWhere((value) => value.id == resultId);
  }
}
