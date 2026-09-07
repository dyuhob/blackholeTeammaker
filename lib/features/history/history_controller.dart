import 'package:flutter/foundation.dart';

import '../../data/team_history_repository.dart';
import '../../domain/team_result.dart';

class HistoryController extends ChangeNotifier {
  HistoryController(this._repository);

  final TeamHistoryRepository _repository;
  List<TeamResult> _results = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  List<TeamResult> get results => List.unmodifiable(_results);
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _results = await _repository.loadAll();
      _sort();
    } catch (error) {
      _errorMessage = '팀 편성 기록을 불러오지 못했습니다: $error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveResult(TeamResult result) async {
    if (_isSaving) return false;
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.save(result);
      final index = _results.indexWhere((value) => value.id == result.id);
      if (index == -1) {
        _results.add(result);
      } else {
        _results[index] = result;
      }
      _sort();
      return true;
    } catch (error) {
      _errorMessage = '기록을 저장하지 못했습니다: $error';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> updateTitle(String resultId, String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      _errorMessage = '제목을 입력해 주세요.';
      notifyListeners();
      return false;
    }
    final result = _results.firstWhere((value) => value.id == resultId);
    return saveResult(result.copyWith(title: trimmed));
  }

  Future<bool> deleteResult(String resultId) async {
    try {
      await _repository.delete(resultId);
      _results.removeWhere((value) => value.id == resultId);
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = '기록을 삭제하지 못했습니다: $error';
      notifyListeners();
      return false;
    }
  }

  void _sort() {
    _results.sort((left, right) => right.createdAt.compareTo(left.createdAt));
  }
}
