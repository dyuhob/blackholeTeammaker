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
    width: 720,
    padding: const EdgeInsets.all(32),
    color: Colors.white,
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
          '${formatDateTime(result.createdAt)} · ${result.teams.length}팀 · 팀당 ${result.teamSize}명',
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
    child: Padding(
      padding: const EdgeInsets.all(16),
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
                  Expanded(
                    child: Text(
                      participant.type == ParticipantType.manualTemporary
                          ? '${participant.name} · 임시'
                          : participant.name,
                    ),
                  ),
                  Text('${participant.score}'),
                ],
              ),
            ),
          const Divider(),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '총점',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                team.bonusScore > 0
                    ? '${team.rawScore} +${team.bonusScore}'
                    : '${team.rawScore}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

String formatDateTime(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')} '
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';
