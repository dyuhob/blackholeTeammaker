import 'package:flutter/material.dart';

import '../../app/navigation_icon_assets.dart';
import '../../domain/team_result.dart';
import '../../services/gallery_exporter.dart';
import 'history_controller.dart';
import 'team_result_content.dart';

class TeamResultScreen extends StatefulWidget {
  const TeamResultScreen({
    super.key,
    required this.result,
    required this.historyController,
    required this.galleryExporter,
    required this.initiallySaved,
    this.onSaved,
    this.onHistoryChanged,
  });

  final TeamResult result;
  final HistoryController historyController;
  final GalleryExporter galleryExporter;
  final bool initiallySaved;
  final ValueChanged<TeamResult>? onSaved;
  final Future<void> Function()? onHistoryChanged;

  @override
  State<TeamResultScreen> createState() => _TeamResultScreenState();
}

class _TeamResultScreenState extends State<TeamResultScreen> {
  late final TextEditingController _titleController;
  late TeamResult _result;
  late bool _saved;
  late String _savedTitle;
  bool _exporting = false;
  bool _sharing = false;

  bool get _hasSavedTitle =>
      _saved && _titleController.text.trim() == _savedTitle;

  @override
  void initState() {
    super.initState();
    _result = widget.result;
    _saved = widget.initiallySaved;
    _savedTitle = widget.initiallySaved ? widget.result.title : '';
    _titleController = TextEditingController(text: widget.result.title)
      ..addListener(_titleChanged);
  }

  @override
  void dispose() {
    _titleController
      ..removeListener(_titleChanged)
      ..dispose();
    super.dispose();
  }

  void _titleChanged() => setState(() {});

  Future<void> _saveResult() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showMessage('제목을 입력해 주세요.');
      return;
    }
    final updated = _result.copyWith(title: title);
    if (await widget.historyController.saveResult(updated) && mounted) {
      setState(() {
        _result = updated;
        _saved = true;
        _savedTitle = title;
      });
      widget.onSaved?.call(updated);
      await widget.onHistoryChanged?.call();
      if (!mounted) return;
      _showMessage('기록에 저장했습니다.');
    } else if (mounted) {
      _showMessage(widget.historyController.errorMessage ?? '저장하지 못했습니다.');
    }
  }

  Future<void> _saveGallery() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    final exportResult = _result.copyWith(
      title: _titleController.text.trim().isEmpty
          ? _result.title
          : _titleController.text.trim(),
    );
    try {
      await widget.galleryExporter.save(context, exportResult);
      if (mounted) _showMessage(widget.galleryExporter.successMessage);
    } catch (error) {
      if (mounted) {
        _showMessage('${widget.galleryExporter.failureMessage}: $error');
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _saveAndShare() async {
    if (_exporting || _sharing) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showMessage('제목을 입력해 주세요.');
      return;
    }
    setState(() => _sharing = true);
    final updated = _result.copyWith(title: title);
    var savedLocally = false;
    try {
      final saved = await widget.historyController.saveResult(updated);
      if (!saved) {
        if (mounted) {
          _showMessage(
            widget.historyController.errorMessage ?? '기록을 저장하지 못했습니다.',
          );
        }
        return;
      }
      savedLocally = true;
      if (!mounted) return;
      setState(() {
        _result = updated;
        _saved = true;
        _savedTitle = title;
      });
      widget.onSaved?.call(updated);
      await widget.galleryExporter.save(context, updated);
      if (!mounted) return;
      await widget.galleryExporter.share(context, updated);
      if (mounted) _showMessage('저장 후 공유했습니다.');
    } catch (error) {
      if (mounted) _showMessage('저장 후 공유하지 못했습니다: $error');
    } finally {
      if (savedLocally) await widget.onHistoryChanged?.call();
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _requestDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('결과를 닫을까요?'),
        content: const Text('저장하지 않은 팀 편성 결과는 사라집니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('계속 보기'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('저장하지 않고 닫기'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.pop(context);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _saved,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && !_saved) _requestDiscard();
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('팀 편성 결과'),
        shape: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: '팀 편성 이름',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${formatDateTime(_result.createdAt)} · ${_result.teams.length}팀 · 팀당 ${_result.teamSize}명',
          ),
          const SizedBox(height: 16),
          TeamResultContent(result: _result),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        child: SafeArea(
          minimum: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _exporting || _sharing ? null : _saveGallery,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  icon: const ImageIcon(
                    AssetImage(NavigationIconAssets.gallerySave),
                    size: 20,
                  ),
                  label: Text(
                    _exporting
                        ? widget.galleryExporter.busyLabel
                        : widget.galleryExporter.actionLabel,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  key: const Key('save-and-share-button'),
                  onPressed: _exporting || _sharing ? null : _saveAndShare,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: Text(_sharing ? '공유 준비 중…' : '저장 후 공유'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  key: const Key('save-result-button'),
                  onPressed: _hasSavedTitle || _exporting || _sharing
                      ? null
                      : _saveResult,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  icon: const ImageIcon(
                    AssetImage(NavigationIconAssets.recordSave),
                    size: 20,
                  ),
                  label: Text(
                    _hasSavedTitle ? '저장됨' : (_saved ? '변경사항 저장' : '기록 저장'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
