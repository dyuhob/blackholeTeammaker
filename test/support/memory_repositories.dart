import 'package:flutter/widgets.dart';
import 'package:team_maker/data/member_repository.dart';
import 'package:team_maker/data/team_history_repository.dart';
import 'package:team_maker/data/workspace_repository.dart';
import 'package:team_maker/domain/member.dart';
import 'package:team_maker/domain/team_result.dart';
import 'package:team_maker/domain/workspace_state.dart';
import 'package:team_maker/services/gallery_exporter.dart';

class MemoryMemberRepository implements MemberRepository {
  MemoryMemberRepository([List<Member> initial = const []])
    : values = [...initial];

  List<Member> values;

  @override
  Future<List<Member>> loadAll() async => [...values];

  @override
  Future<void> saveAll(List<Member> members) async {
    values = [...members];
  }
}

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

class MemoryWorkspaceRepository implements WorkspaceRepository {
  WorkspaceState? value;

  @override
  Future<WorkspaceState?> load() async => value;

  @override
  Future<void> save(WorkspaceState state) async {
    value = state;
  }
}

class MemoryGalleryExporter implements GalleryExporter {
  MemoryGalleryExporter({
    this.actionLabel = '갤러리에 저장',
    this.busyLabel = '이미지 생성 중…',
    this.successMessage = '갤러리에 저장했습니다.',
    this.failureMessage = '갤러리에 저장하지 못했습니다.',
  });

  @override
  final String actionLabel;

  @override
  final String busyLabel;

  @override
  final String successMessage;

  @override
  final String failureMessage;

  final List<TeamResult> saved = [];
  final List<TeamResult> shared = [];

  @override
  Future<void> save(BuildContext context, TeamResult result) async {
    saved.add(result);
  }

  @override
  Future<void> share(BuildContext context, TeamResult result) async {
    shared.add(result);
  }
}

class SequenceIds {
  var _value = 0;

  String next() => 'id-${_value++}';
}
