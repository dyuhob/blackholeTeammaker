import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/manual_score.dart';
import 'member_controller.dart';

const _controlHeight = 48.0;
const _memberCardHeight = 48.0;

class MemberScreen extends StatefulWidget {
  const MemberScreen({super.key, required this.controller});

  final MemberController controller;

  @override
  State<MemberScreen> createState() => _MemberScreenState();
}

class _MemberScreenState extends State<MemberScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _scoreController;
  final _invalidScoreMemberIds = <String>{};

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.controller.pendingName,
    );
    _scoreController = TextEditingController(
      text: widget.controller.pendingScore,
    );
  }

  @override
  void dispose() {
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
    _showMessage(
      saved
          ? '클럽원 명단을 저장했습니다.'
          : widget.controller.errorMessage ?? '저장하지 못했습니다.',
    );
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
                  const SizedBox(width: 8),
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
                  const SizedBox(width: 8),
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
                      separatorBuilder: (_, _) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final member = widget.controller.draftMembers[index];
                        return SizedBox(
                          height: _memberCardHeight,
                          child: Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 4, 2, 4),
                              child: Row(
                                children: [
                                  Expanded(child: Text(member.name)),
                                  Text(
                                    '점수',
                                    key: ValueKey(
                                      'member-score-label-${member.id}',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 76,
                                    height: 36,
                                    child: TextFormField(
                                      key: ValueKey(
                                        'member-score-${member.id}',
                                      ),
                                      initialValue: '${member.score}',
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      autovalidateMode:
                                          AutovalidateMode.onUserInteraction,
                                      validator: (value) {
                                        final score = int.tryParse(value ?? '');
                                        return score != null &&
                                                isValidManualScore(score)
                                            ? null
                                            : '90~200';
                                      },
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
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 8,
                                        ),
                                        errorStyle: TextStyle(
                                          fontSize: 0,
                                          height: 0,
                                        ),
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '클럽원 삭제',
                                    onPressed: () {
                                      _invalidScoreMemberIds.remove(member.id);
                                      widget.controller.deleteMember(member.id);
                                    },
                                    constraints: const BoxConstraints.tightFor(
                                      width: 36,
                                      height: 36,
                                    ),
                                    padding: EdgeInsets.zero,
                                    iconSize: 20,
                                    icon: const Icon(Icons.delete_outline),
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
                  widget.controller.hasUnsavedChanges &&
                      !widget.controller.isSaving
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
