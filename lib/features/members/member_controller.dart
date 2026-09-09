import 'package:flutter/foundation.dart';

import '../../data/member_repository.dart';
import '../../domain/manual_score.dart';
import '../../domain/member.dart';

class MemberController extends ChangeNotifier {
  MemberController({required this._repository, required this._idFactory});

  final MemberRepository _repository;
  final String Function() _idFactory;
  List<Member> _savedMembers = [];
  List<Member> _draftMembers = [];
  String _pendingName = '';
  String _pendingScore = '';
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  int _inputRevision = 0;

  List<Member> get savedMembers => List.unmodifiable(_savedMembers);
  List<Member> get draftMembers => List.unmodifiable(_draftMembers);
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  bool get hasUnsavedChanges => !_membersEqual(_savedMembers, _draftMembers);
  String get pendingName => _pendingName;
  String get pendingScore => _pendingScore;
  int get inputRevision => _inputRevision;

  set pendingName(String value) {
    if (value == _pendingName) return;
    _pendingName = value;
    notifyListeners();
  }

  set pendingScore(String value) {
    if (value == _pendingScore) return;
    _pendingScore = value;
    notifyListeners();
  }

  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final loaded = await _repository.loadAll();
      final sorted = _sortedMembers(loaded);
      _savedMembers = [...sorted];
      _draftMembers = [...sorted];
    } catch (error) {
      _errorMessage = '클럽원 명단을 불러오지 못했습니다: $error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reloadFromLocal() async {
    final loaded = _sortedMembers(await _repository.loadAll());
    _savedMembers = [...loaded];
    _draftMembers = [...loaded];
    _pendingName = '';
    _pendingScore = '';
    _inputRevision++;
    _errorMessage = null;
    notifyListeners();
  }

  void addMember(String name, int score) {
    validateManualScore(score);
    _draftMembers.add(Member(id: _idFactory(), name: name, score: score));
    _draftMembers.sort(_compareMembersByName);
    _errorMessage = null;
    notifyListeners();
  }

  void clearPendingMember() {
    if (_pendingName.isEmpty && _pendingScore.isEmpty) return;
    _pendingName = '';
    _pendingScore = '';
    notifyListeners();
  }

  void restoreWorkspace({
    required List<Member> draftMembers,
    required String pendingName,
    required String pendingScore,
  }) {
    _draftMembers = _sortedMembers(draftMembers);
    _pendingName = pendingName;
    _pendingScore = pendingScore;
    notifyListeners();
  }

  void updateScore(String memberId, int score) {
    validateManualScore(score);
    final index = _draftMembers.indexWhere((member) => member.id == memberId);
    if (index == -1) return;
    _draftMembers[index] = _draftMembers[index].copyWith(score: score);
    notifyListeners();
  }

  void deleteMember(String memberId) {
    _draftMembers.removeWhere((member) => member.id == memberId);
    notifyListeners();
  }

  Future<bool> save() async {
    if (_isSaving) return false;
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.saveAll(_draftMembers);
      _savedMembers = [..._draftMembers];
      return true;
    } catch (error) {
      _errorMessage = '클럽원 명단을 저장하지 못했습니다: $error';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}

List<Member> _sortedMembers(Iterable<Member> members) =>
    [...members]..sort(_compareMembersByName);

int _compareMembersByName(Member left, Member right) =>
    left.name.compareTo(right.name);

bool _membersEqual(List<Member> left, List<Member> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
