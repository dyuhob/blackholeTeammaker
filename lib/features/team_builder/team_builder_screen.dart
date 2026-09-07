import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/gallery_export_service.dart';
import '../history/history_controller.dart';
import '../history/team_result_screen.dart';
import 'team_builder_controller.dart';

class TeamBuilderScreen extends StatefulWidget {
  const TeamBuilderScreen({
    super.key,
    required this.controller,
    required this.historyController,
    required this.galleryExporter,
  });

  final TeamBuilderController controller;
  final HistoryController historyController;
  final GalleryExporter galleryExporter;

  @override
  State<TeamBuilderScreen> createState() => _TeamBuilderScreenState();
}

class _TeamBuilderScreenState extends State<TeamBuilderScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _teamSizeController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.controller.title);
    _teamSizeController = TextEditingController(
      text: '${widget.controller.teamSize}',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _teamSizeController.dispose();
    super.dispose();
  }

  Future<void> _addTemporary() async {
    final name = TextEditingController();
    final score = TextEditingController();
    final added = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('임시 회원 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: '이름'),
            ),
            TextField(
              controller: score,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: '점수 (0~300)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(score.text);
              if (name.text.trim().isEmpty ||
                  parsed == null ||
                  parsed < 0 ||
                  parsed > 300) {
                return;
              }
              widget.controller.addManualTemporary(name.text, parsed);
              Navigator.pop(context, true);
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
    name.dispose();
    score.dispose();
    if (added == false && mounted) return;
  }

  void _buildTeams() {
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
            onSaved: (saved) =>
                widget.controller.updateCurrentResult(saved, saved: true),
          ),
        ),
      );
    } on ArgumentError catch (error) {
      _showMessage(error.message?.toString() ?? '팀을 구성할 수 없습니다.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) => ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: '편성 제목 (선택)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('team-size-input'),
          controller: _teamSizeController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: '팀당 인원수',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Text('제외된 회원', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            TextButton.icon(
              onPressed: widget.controller.resetAllMembers,
              icon: const Icon(Icons.group_add_outlined),
              label: const Text('전체 회원 다시 추가'),
            ),
          ],
        ),
        if (widget.controller.availableMembers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('제외된 회원이 없습니다.'),
          )
        else
          for (final member in widget.controller.availableMembers)
            ListTile(
              title: Text(member.name),
              subtitle: Text('${member.score}점'),
              trailing: IconButton(
                tooltip: '참가자에 추가',
                onPressed: () => widget.controller.addSavedMember(member.id),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ),
        const Divider(height: 28),
        Text('현재 참가자', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (widget.controller.participants.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('참가자를 한 명 이상 추가해 주세요.'),
          ),
        for (final participant in widget.controller.participants) ...[
          if (participant.type.isTemporary &&
              widget.controller.participants.indexOf(participant) > 0 &&
              !widget
                  .controller
                  .participants[widget.controller.participants.indexOf(
                        participant,
                      ) -
                      1]
                  .type
                  .isTemporary)
            const Padding(
              padding: EdgeInsets.only(top: 12, bottom: 4),
              child: Text('임시 회원'),
            ),
          Card(
            child: ListTile(
              title: Text(participant.name),
              subtitle: participant.type.isTemporary
                  ? const Text('임시 회원')
                  : null,
              trailing: SizedBox(
                width: 140,
                child: Row(
                  children: [
                    SizedBox(
                      width: 76,
                      child: TextFormField(
                        key: ValueKey('participant-score-${participant.id}'),
                        initialValue: '${participant.score}',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (value) {
                          final score = int.tryParse(value);
                          if (score != null && score >= 0 && score <= 300) {
                            widget.controller.updateParticipantScore(
                              participant.id,
                              score,
                            );
                          }
                        },
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '참가자 제외',
                      onPressed: () => participant.type.isTemporary
                          ? widget.controller.removeParticipant(participant.id)
                          : widget.controller.excludeMember(
                              participant.sourceMemberId!,
                            ),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        OutlinedButton.icon(
          onPressed: _addTemporary,
          icon: const Icon(Icons.person_add_alt),
          label: const Text('임시 회원 추가'),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('build-teams-button'),
          onPressed: widget.controller.participants.isEmpty
              ? null
              : _buildTeams,
          icon: const Icon(Icons.shuffle),
          label: const Text('팀짜기'),
        ),
      ],
    ),
  );
}
