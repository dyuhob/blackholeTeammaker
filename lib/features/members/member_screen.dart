import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/navigation_icon_assets.dart';
import '../../domain/manual_score.dart';
import 'member_controller.dart';

const _controlHeight = 48.0;
const _memberCardHeight = 48.0;

class MemberScreen extends StatefulWidget {
  const MemberScreen({super.key, required this.controller, this.onSaved});

  final MemberController controller;
  final Future<bool> Function()? onSaved;

  @override
  State<MemberScreen> createState() => _MemberScreenState();
}

class _MemberScreenState extends State<MemberScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _scoreController;
  final _invalidScoreMemberIds = <String>{};
  late int _inputRevision;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.controller.pendingName,
    );
    _scoreController = TextEditingController(
      text: widget.controller.pendingScore,
    );
    _inputRevision = widget.controller.inputRevision;
    widget.controller.addListener(_syncPendingInputs);
  }

  void _syncPendingInputs() {
    if (_inputRevision == widget.controller.inputRevision) return;
    _inputRevision = widget.controller.inputRevision;
    _nameController.text = widget.controller.pendingName;
    _scoreController.text = widget.controller.pendingScore;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncPendingInputs);
    _nameController.dispose();
    _scoreController.dispose();
    super.dispose();
  }

  void _addMember() {
    final score = int.tryParse(_scoreController.text);
    if (_nameController.text.trim().isEmpty ||
        score == null ||
        !isValidManualScore(score)) {
      _showMessage('이름과 90~200 사이의 점수를 입력해 주세요.');
      return;
    }
    widget.controller.addMember(_nameController.text, score);
    widget.controller.clearPendingMember();
    _nameController.clear();
    _scoreController.clear();
  }

  Future<void> _save() async {
    if (_invalidScoreMemberIds.isNotEmpty) {
      _showMessage('모든 점수를 90~200 사이로 입력해 주세요.');
      return;
    }
    final saved = await widget.controller.save();
    if (!mounted) return;
    if (!saved) {
      _showMessage(widget.controller.errorMessage ?? '저장하지 못했습니다.');
      return;
    }
    final synchronized = await widget.onSaved?.call() ?? false;
    if (mounted && synchronized) {
      _showMessage('클럽원 명단을 저장했습니다.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      if (widget.controller.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: _controlHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('member-name-input'),
                      controller: _nameController,
                      onChanged: (value) =>
                          widget.controller.pendingName = value,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration('클럽원 이름'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 92,
                    child: TextField(
                      key: const Key('member-score-input'),
                      controller: _scoreController,
                      onChanged: (value) =>
                          widget.controller.pendingScore = value,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onSubmitted: (_) => _addMember(),
                      decoration: _inputDecoration('점수'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(onPressed: _addMember, child: const Text('추가')),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (widget.controller.hasUnsavedChanges)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  '저장되지 않은 변경사항이 있습니다.',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
            Expanded(
              child: widget.controller.draftMembers.isEmpty
                  ? const Center(child: Text('클럽원 이름과 점수를 추가해 주세요.'))
                  : ListView.separated(
                      itemCount: widget.controller.draftMembers.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final member = widget.controller.draftMembers[index];
                        final hasInvalidScore = _invalidScoreMemberIds.contains(
                          member.id,
                        );
                        return SizedBox(
                          key: ValueKey('member-card-${member.id}'),
                          height: _memberCardHeight,
                          child: Card(
                            margin: EdgeInsets.zero,
                            elevation: 0,
                            color: Colors.white,
                            surfaceTintColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      member.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '에버리지',
                                    key: ValueKey(
                                      'member-score-label-${member.id}',
                                    ),
                                    style: const TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 76,
                                    height: _memberCardHeight,
                                    child: Center(
                                      child: SizedBox(
                                        width: 76,
                                        height: 40,
                                        child: TextFormField(
                                          key: ValueKey(
                                            'member-score-${member.id}',
                                          ),
                                          initialValue: '${member.score}',
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
                                          onChanged: (value) {
                                            final score = int.tryParse(value);
                                            final valid =
                                                score != null &&
                                                isValidManualScore(score);
                                            setState(() {
                                              if (valid) {
                                                _invalidScoreMemberIds.remove(
                                                  member.id,
                                                );
                                              } else {
                                                _invalidScoreMemberIds.add(
                                                  member.id,
                                                );
                                              }
                                            });
                                            if (valid) {
                                              widget.controller.updateScore(
                                                member.id,
                                                score,
                                              );
                                            }
                                          },
                                          textAlignVertical:
                                              TextAlignVertical.center,
                                          textAlign: TextAlign.center,
                                          decoration: InputDecoration(
                                            isDense: true,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                ),
                                            border: const OutlineInputBorder(),
                                            enabledBorder: OutlineInputBorder(
                                              borderSide: BorderSide(
                                                color: hasInvalidScore
                                                    ? const Color(0xFFD32F2F)
                                                    : const Color(0xFFBDBDBD),
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderSide: BorderSide(
                                                color: hasInvalidScore
                                                    ? const Color(0xFFD32F2F)
                                                    : const Color(0xFF42A5F5),
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  BorderedAssetIconButton(
                                    tooltip: '클럽원 삭제',
                                    onPressed: () {
                                      _invalidScoreMemberIds.remove(member.id);
                                      widget.controller.deleteMember(member.id);
                                    },
                                    assetPath:
                                        NavigationIconAssets.memberDelete,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            FilledButton(
              key: const Key('save-members-button'),
              onPressed:
                  !widget.controller.isSaving &&
                      (widget.controller.hasUnsavedChanges ||
                          widget.controller.draftMembers.isNotEmpty)
                  ? _save
                  : null,
              child: Text(widget.controller.isSaving ? '저장 중…' : '저장'),
            ),
          ],
        ),
      );
    },
  );
}

InputDecoration _inputDecoration(String label) => InputDecoration(
  labelText: label,
  isDense: true,
  filled: true,
  fillColor: Colors.white,
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  border: const OutlineInputBorder(),
  enabledBorder: const OutlineInputBorder(
    borderSide: BorderSide(color: Color(0xFFBDBDBD)),
  ),
  focusedBorder: const OutlineInputBorder(
    borderSide: BorderSide(color: Color(0xFF42A5F5), width: 2),
  ),
);
