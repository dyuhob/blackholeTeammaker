import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:team_maker/data/supabase/supabase_member_remote_data_source.dart';
import 'package:team_maker/data/sync/pending_mutation.dart';

void main() {
  test('member remote data source reads and writes the member table', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode(<Object>[]),
          request.method == 'GET' ? 200 : 201,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    final source = SupabaseMemberRemoteDataSource(client);
    const mutation = PendingMutation(
      id: 'upsert:member-1',
      entityId: 'member-1',
      kind: SyncMutationKind.upsert,
      payload: {'id': 'member-1', 'name': '회원', 'score': 180},
    );

    await source.push(mutation);
    await source.fetchAll();

    expect(requests, hasLength(2));
    expect(requests[0].method, 'POST');
    expect(requests[0].url.path, '/rest/v1/member');
    expect(requests[1].method, 'GET');
    expect(requests[1].url.path, '/rest/v1/member');
  });
}
