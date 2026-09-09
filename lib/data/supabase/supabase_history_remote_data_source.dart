import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/team_result.dart';
import '../sync/pending_mutation.dart';
import 'history_remote_data_source.dart';
import 'history_row_codec.dart';

class SupabaseHistoryRemoteDataSource implements HistoryRemoteDataSource {
  const SupabaseHistoryRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<void> push(PendingMutation mutation) async {
    switch (mutation.kind) {
      case SyncMutationKind.upsert:
        final result = TeamResult.fromJson(mutation.payload);
        await _client.rpc(
          'save_team_record',
          params: {'p_record': teamResultToRemotePayload(result)},
        );
      case SyncMutationKind.delete:
        await _client.rpc(
          'delete_team_record',
          params: {'p_record_client_id': mutation.entityId},
        );
    }
  }

  @override
  Future<List<TeamResult>> fetchAll() async {
    final gameResponse = await _client
        .from('game')
        .select(
          'id,client_id,name,created_at,group_count,group_size,'
          'highest_average,deleted_at',
        )
        .isFilter('deleted_at', null);
    final participantResponse = await _client
        .from('participants')
        .select(
          'client_id,game_id,user_id,name,average,team_no,'
          'auto_insert,deleted_at',
        )
        .isFilter('deleted_at', null);
    final participants = participantResponse
        .map((row) => Map<String, Object?>.from(row))
        .toList();
    final results = <TeamResult>[];
    for (final rawGame in gameResponse) {
      final game = Map<String, Object?>.from(rawGame);
      final gameId = (game['id']! as num).toInt();
      final rows = participants
          .where((row) => (row['game_id']! as num).toInt() == gameId)
          .toList();
      results.add(teamResultFromRemoteRows(game, rows));
    }
    results.sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return results;
  }
}
