import 'package:flutter/material.dart';

import '../../domain/participant.dart';
import '../../domain/team.dart';
import '../../domain/team_result.dart';

class TeamResultContent extends StatelessWidget {
  const TeamResultContent({super.key, required this.result});

  final TeamResult result;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [for (final team in result.teams) _TeamCard(team: team)],
  );
}

class TeamResultExportWidget extends StatelessWidget {
  const TeamResultExportWidget({super.key, required this.result});

  final TeamResult result;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('team-result-export-background'),
    width: 720,
    padding: const EdgeInsets.all(32),
    color: const Color(0xFFF3F4F6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          result.title,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        Text(
          '팀당 ${result.teamSize}명 · ${result.teams.length}팀 · '
          '${formatDateTime(result.createdAt)}',
          style: const TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 24),
        TeamResultContent(result: result),
      ],
    ),
  );
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.team});

  final Team team;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    elevation: 0,
    color: Colors.white,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${team.number}팀',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              for (final participant in team.participants)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(_participantLabel(participant))),
                      Text('${participant.score}'),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Container(
          key: ValueKey('team-total-panel-${team.number}'),
          width: double.infinity,
          color: Colors.white,
          child: Column(
            children: [
              const Divider(
                height: 1,
                thickness: 1,
                indent: 16,
                endIndent: 16,
                color: Colors.black,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  key: ValueKey('team-total-row-${team.number}'),
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Expanded(
                      child: Text(
                        '총점',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (team.bonusScore > 0) ...[
                      Text(
                        '+${team.bonusScore}',
                        key: ValueKey('team-bonus-score-${team.number}'),
                        style: const TextStyle(
                          color: Color(0xFF1976D2),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    Text(
                      '${team.rawScore}',
                      key: ValueKey('team-total-score-${team.number}'),
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

String _participantLabel(Participant participant) =>
    participant.type == ParticipantType.manualTemporary
    ? '${participant.name} (게스트)'
    : participant.name;

String formatDateTime(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')} '
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';
