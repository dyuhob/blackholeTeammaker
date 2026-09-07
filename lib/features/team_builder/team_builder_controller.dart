import 'package:flutter/foundation.dart';

import '../../domain/member.dart';
import '../../domain/participant.dart';
import '../../domain/team_allocator.dart';
import '../../domain/team_result.dart';

class TeamBuilderController extends ChangeNotifier {
  TeamBuilderController({
    required TeamAllocator allocator,
    required String Function() idFactory,
    required DateTime Function() now,
  }) : _allocator = allocator,
       _idFactory = idFactory,
       _now = now;

  final TeamAllocator _allocator;
  final String Function() _idFactory;
  final DateTime Function() _now;
  List<Member> _savedMembers = [];
  final List<Participant> _participants = [];
  int _teamSize = 3;
  String _title = '';
  TeamResult? _currentResult;
  bool _isCurrentResultSaved = false;

  List<Member> get availableMembers {
    final selectedIds = _participants
        .where((participant) => participant.type == ParticipantType.regular)
        .map((participant) => participant.sourceMemberId)
        .toSet();
    return _savedMembers
        .where((member) => !selectedIds.contains(member.id))
        .toList(growable: false);
  }

  List<Participant> get participants => List.unmodifiable(_participants);
  int get teamSize => _teamSize;
  String get title => _title;
  TeamResult? get currentResult => _currentResult;
  bool get isCurrentResultSaved => _isCurrentResultSaved;

  set teamSize(int value) {
    if (value < 1 || value == _teamSize) return;
    _teamSize = value;
    notifyListeners();
  }

  set title(String value) {
    if (value == _title) return;
    _title = value;
    notifyListeners();
  }

  void setSavedMembers(List<Member> members) {
    _savedMembers = [...members];
    resetAllMembers();
  }

  void resetAllMembers() {
    _participants.removeWhere(
      (participant) => participant.type == ParticipantType.regular,
    );
    _participants.insertAll(
      0,
      _savedMembers.map(
        (member) => Participant(
          id: 'participant-${member.id}',
          sourceMemberId: member.id,
          name: member.name,
          score: member.score,
          type: ParticipantType.regular,
        ),
      ),
    );
    _sortParticipants();
    notifyListeners();
  }

  void excludeMember(String memberId) {
    _participants.removeWhere(
      (participant) =>
          participant.type == ParticipantType.regular &&
          participant.sourceMemberId == memberId,
    );
    notifyListeners();
  }

  void addSavedMember(String memberId) {
    if (_participants.any((participant) => participant.sourceMemberId == memberId)) {
      return;
    }
    final member = _savedMembers.firstWhere((value) => value.id == memberId);
    _participants.add(
      Participant(
        id: 'participant-${member.id}',
        sourceMemberId: member.id,
        name: member.name,
        score: member.score,
        type: ParticipantType.regular,
      ),
    );
    _sortParticipants();
    notifyListeners();
  }

  void addManualTemporary(String name, int score) {
    _participants.add(
      Participant(
        id: _idFactory(),
        name: name,
        score: score,
        type: ParticipantType.manualTemporary,
      ),
    );
    _sortParticipants();
    notifyListeners();
  }

  void removeParticipant(String participantId) {
    _participants.removeWhere((participant) => participant.id == participantId);
    notifyListeners();
  }

  void updateParticipantScore(String participantId, int score) {
    final index = _participants.indexWhere(
      (participant) => participant.id == participantId,
    );
    if (index == -1) return;
    _participants[index] = _participants[index].copyWith(score: score);
    notifyListeners();
  }

  TeamResult buildResult() {
    final createdAt = _now();
    final regulars = _participants
        .where((participant) => participant.type == ParticipantType.regular)
        .toList();
    final temporary = _participants
        .where(
          (participant) => participant.type == ParticipantType.manualTemporary,
        )
        .toList();
    final result = TeamResult(
      id: _idFactory(),
      title: _title.trim().isEmpty ? _defaultTitle(createdAt) : _title.trim(),
      createdAt: createdAt,
      teamSize: _teamSize,
      teams: _allocator.allocate(
        regularMembers: regulars,
        manualTemporaryMembers: temporary,
        teamSize: _teamSize,
      ),
    );
    _currentResult = result;
    _isCurrentResultSaved = false;
    notifyListeners();
    return result;
  }

  void updateCurrentResult(TeamResult result, {required bool saved}) {
    _currentResult = result;
    _isCurrentResultSaved = saved;
    notifyListeners();
  }

  void _sortParticipants() {
    final regulars = _participants
        .where((participant) => participant.type == ParticipantType.regular)
        .toList()
      ..sort((left, right) {
        final leftIndex = _savedMembers.indexWhere(
          (member) => member.id == left.sourceMemberId,
        );
        final rightIndex = _savedMembers.indexWhere(
          (member) => member.id == right.sourceMemberId,
        );
        return leftIndex.compareTo(rightIndex);
      });
    final temporary = _participants
        .where((participant) => participant.type.isTemporary)
        .toList();
    _participants
      ..clear()
      ..addAll(regulars)
      ..addAll(temporary);
  }

  String _defaultTitle(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')} '
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')} 팀 편성';
}
