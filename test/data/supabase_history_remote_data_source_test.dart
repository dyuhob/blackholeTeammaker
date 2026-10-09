import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:team_maker/data/supabase/supabase_history_remote_data_source.dart';

void main() {
  test('history remote data source selects participant handicap', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode(<Object>[]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );

    await SupabaseHistoryRemoteDataSource(client).fetchAll();

    final participantsRequest = requests.singleWhere(
      (request) => request.url.path == '/rest/v1/participants',
    );
    expect(
      participantsRequest.url.queryParameters['select'],
      contains('handicap'),
    );
  });
}
