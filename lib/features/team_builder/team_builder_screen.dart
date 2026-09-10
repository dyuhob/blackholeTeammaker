import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/navigation_icon_assets.dart';
import '../../domain/manual_score.dart';
import '../../domain/member.dart';
import '../../domain/participant.dart';
import '../../services/gallery_exporter.dart';
import '../history/history_controller.dart';
import '../history/team_result_screen.dart';
import 'team_builder_controller.dart';

const _controlHeight = 48.0;
const _compactCardHeight = 36.0;
const _gridGap = 8.0;
const _focusedInputColor = Color(0xFF42A5F5);
const _guestBackgroundColor = Color(0xFFA7B9ED);
const _actionButtonSize = 24.0;
const _actionIconSize = 14.0;
const _removeButtonSize = 24.0;
const _removeIconSize = 14.0;

class TeamBuilderScreen extends StatefulWidget {
  const TeamBuilderScreen({
    super.key,
    required this.controller,
    required this.historyController,
    required this.galleryExporter,
    this.onHistoryChanged,
  });

  final TeamBuilderController controller;
  final HistoryController historyController;
  final GalleryExporter galleryExporter;
  final Future<bool> Function()? onHistoryChanged;

  @override
  State<TeamBuilderScreen> createState() => _TeamBuilderScreenState();
}

class _TeamBuilderScreenState extends State<TeamBuilderScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _teamSizeController;
  final _invalidScoreParticipantIds = <String>{};

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.controller.title);
    _teamSizeController = TextEditingController(
      text: widget.controller.teamSizeInput,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _teamSizeController.dispose();
    super.dispose();
  }

  Future<void> _addTemporary() async {
    final input = await showDialog<_TemporaryMemberInput>(
      context: context,
      builder: (context) => const _TemporaryMemberDialog(),
    );
    if (!mounted || input == null) return;
    widget.controller.addManualTemporary(input.name, input.score);
  }

  void _buildTeams() {
    final currentParticipantIds = widget.controller.participants
        .map((participant) => participant.id)
        .toSet();
    if (_invalidScoreParticipantIds.any(currentParticipantIds.contains)) {
      _showMessage('모든 점수를 90~200 사이로 입력해 주세요.');
      return;
    }
    final parsedTeamSize = int.tryParse(_teamSizeController.text);
    if (parsedTeamSize == null || parsedTeamSize < 1 || parsedTeamSize > 99) {
      _showMessage('팀당 인원은 1~99명으로 입력해 주세요.');
      return;
    }
    widget.controller
      ..teamSize = parsedTeamSize
      ..title = _titleController.text;
    try {
      final result = widget.controller.buildResult();
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => TeamResultScreen(
            result: result,
            historyController: widget.historyController,
            galleryExporter: widget.galleryExporter,
            initiallySaved: false,
            onHistoryChanged: widget.onHistoryChanged,
            onSaved: (saved) =>
                widget.controller.updateCurrentResult(saved, saved: true),
          ),
        ),
      );
    } on ArgumentError catch (error) {
      _showMessage(error.message?.toString() ?? '팀을 구성할 수 없습니다.');
    }
  }

  void _updateParticipantScore(Participant participant, String value) {
    final score = int.tryParse(value);
    final valid = score != null && isValidManualScore(score);
    setState(() {
      if (valid) {
        _invalidScoreParticipantIds.remove(participant.id);
      } else {
        _invalidScoreParticipantIds.add(participant.id);
      }
    });
    if (valid) {
      widget.controller.updateParticipantScore(participant.id, score);
    }
  }

  void _removeParticipant(Participant participant) {
    _invalidScoreParticipantIds.remove(participant.id);
    if (participant.type.isTemporary) {
      widget.controller.removeParticipant(participant.id);
    } else {
      widget.controller.excludeMember(participant.sourceMemberId!);
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
      final availableMembers = widget.controller.availableMembers;
      final participants = widget.controller.participants;
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            height: _controlHeight,
            child: TextField(
              key: const Key('team-title-input'),
              controller: _titleController,
              onChanged: (value) => widget.controller.title = value,
              decoration: _inputDecoration('팀 편성 이름'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: _controlHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SizedBox(
                    key: const Key('team-size-control'),
                    child: TextField(
                      key: const Key('team-size-input'),
                      controller: _teamSizeController,
                      onChanged: (value) =>
                          widget.controller.teamSizeInput = value,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _inputDecoration('팀당 인원수'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    key: const Key('build-teams-button'),
                    onPressed: participants.isEmpty ? null : _buildTeams,
                    icon: const ImageIcon(
                      AssetImage(NavigationIconAssets.buildTeams),
                    ),
                    label: const Text('팀짜기'),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: Row(
              children: [
                Text(
                  '미참여 클럽원',
                  key: const Key('unselected-section-title'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    _invalidScoreParticipantIds.clear();
                    widget.controller.resetAllMembers();
                  },
                  child: const Text('전체 추가'),
                ),
              ],
            ),
          ),
          _CompactGrid(
            itemCount: availableMembers.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) return _GuestAddCard(onTap: _addTemporary);
              final member = availableMembers[index - 1];
              return _UnselectedMemberCard(
                member: member,
                onAdd: () => widget.controller.addSavedMember(member.id),
              );
            },
          ),
          const Divider(height: 21),
          SizedBox(
            height: 32,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '현재 참가자',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          if (participants.isEmpty)
            const SizedBox(
              height: _compactCardHeight,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('참가자를 한 명 이상 추가해 주세요.'),
              ),
            )
          else
            _CompactGrid(
              itemCount: participants.length,
              itemBuilder: (context, index) {
                final participant = participants[index];
                return _ParticipantCard(
                  participant: participant,
                  onScoreChanged: (value) =>
                      _updateParticipantScore(participant, value),
                  onRemove: () => _removeParticipant(participant),
                );
              },
            ),
          const SizedBox(height: 8),
        ],
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
    borderSide: BorderSide(color: _focusedInputColor, width: 2),
  ),
);

class _CompactGrid extends StatelessWidget {
  const _CompactGrid({required this.itemCount, required this.itemBuilder});

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    padding: EdgeInsets.zero,
    itemCount: itemCount,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: _gridGap,
      mainAxisSpacing: _gridGap,
      mainAxisExtent: _compactCardHeight,
    ),
    itemBuilder: itemBuilder,
  );
}

class _GuestAddCard extends StatelessWidget {
  const _GuestAddCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('guest-add-card'),
    margin: EdgeInsets.zero,
    elevation: 0,
    color: _guestBackgroundColor,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '게스트 추가',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 6),
          CircularAssetIconButton(
            key: const Key('guest-add-icon'),
            tooltip: '게스트 추가',
            onPressed: onTap,
            assetPath: NavigationIconAssets.participantAdd,
            size: _actionButtonSize,
            iconSize: _actionIconSize,
          ),
        ],
      ),
    ),
  );
}

class _UnselectedMemberCard extends StatelessWidget {
  const _UnselectedMemberCard({required this.member, required this.onAdd});

  final Member member;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Card(
    key: ValueKey('unselected-card-${member.id}'),
    margin: EdgeInsets.zero,
    elevation: 0,
    color: Colors.white,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.only(left: 9, right: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              member.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 3),
          Text('${member.score}', style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 8),
          CircularAssetIconButton(
            tooltip: '참가자에 추가',
            onPressed: onAdd,
            assetPath: NavigationIconAssets.participantAdd,
            size: _actionButtonSize,
            iconSize: _actionIconSize,
          ),
        ],
      ),
    ),
  );
}

class _ParticipantCard extends StatelessWidget {
  const _ParticipantCard({
    required this.participant,
    required this.onScoreChanged,
    required this.onRemove,
  });

  final Participant participant;
  final ValueChanged<String> onScoreChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Card(
    key: ValueKey('participant-card-${participant.id}'),
    margin: EdgeInsets.zero,
    elevation: 0,
    color: Colors.white,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.only(left: 9, right: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              participant.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 3),
          SizedBox(
            width: 45,
            height: 34,
            child: TextFormField(
              key: ValueKey('participant-score-${participant.id}'),
              initialValue: '${participant.score}',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: onScoreChanged,
              textAlign: TextAlign.center,
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(horizontal: 4),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircularAssetIconButton(
            tooltip: '참가자 제외',
            onPressed: onRemove,
            assetPath: NavigationIconAssets.participantRemove,
            size: _removeButtonSize,
            iconSize: _removeIconSize,
          ),
        ],
      ),
    ),
  );
}

class _TemporaryMemberInput {
  const _TemporaryMemberInput({required this.name, required this.score});

  final String name;
  final int score;
}

class _TemporaryMemberDialog extends StatefulWidget {
  const _TemporaryMemberDialog();

  @override
  State<_TemporaryMemberDialog> createState() => _TemporaryMemberDialogState();
}

class _TemporaryMemberDialogState extends State<_TemporaryMemberDialog> {
  final _nameController = TextEditingController();
  final _scoreController = TextEditingController();
  String? _nameError;
  String? _scoreError;

  @override
  void dispose() {
    _nameController.dispose();
    _scoreController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final score = int.tryParse(_scoreController.text);
    final validName = name.isNotEmpty;
    final validScore = score != null && isValidManualScore(score);
    if (!validName || !validScore) {
      setState(() {
        _nameError = validName ? null : '이름을 입력해 주세요.';
        _scoreError = validScore ? null : '점수는 90~200 사이여야 합니다.';
      });
      return;
    }
    Navigator.pop(context, _TemporaryMemberInput(name: name, score: score));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('게스트 추가'),
    content: SizedBox(
      width: 280,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: _controlHeight,
            child: TextField(
              key: const Key('temporary-name-input'),
              controller: _nameController,
              decoration: _inputDecoration('이름'),
            ),
          ),
          if (_nameError != null) ...[
            const SizedBox(height: 4),
            Text(
              _nameError!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: _controlHeight,
            child: TextField(
              key: const Key('temporary-score-input'),
              controller: _scoreController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _inputDecoration('점수 (90~200)'),
            ),
          ),
          if (_scoreError != null) ...[
            const SizedBox(height: 4),
            Text(
              _scoreError!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      FilledButton(
        key: const Key('add-temporary-button'),
        onPressed: _submit,
        child: const Text('추가'),
      ),
    ],
  );
}
