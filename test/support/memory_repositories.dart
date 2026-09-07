import 'package:flutter/widgets.dart';
import 'package:team_maker/data/member_repository.dart';
import 'package:team_maker/data/team_history_repository.dart';
import 'package:team_maker/domain/member.dart';
import 'package:team_maker/domain/team_result.dart';
import 'package:team_maker/services/gallery_export_service.dart';

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

class MemoryGalleryExporter implements GalleryExporter {
  final List<TeamResult> saved = [];

  @override
  Future<void> save(BuildContext context, TeamResult result) async {
    saved.add(result);
  }
}

class SequenceIds {
  var _value = 0;

  String next() => 'id-${_value++}';
}
