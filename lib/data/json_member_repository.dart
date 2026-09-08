import '../core/storage/json_object_store.dart';
import '../domain/member.dart';
import 'member_repository.dart';

class JsonMemberRepository implements MemberRepository {
  const JsonMemberRepository(this._store);

  final JsonObjectStore _store;

  @override
  Future<List<Member>> loadAll() async {
    final json = await _store.read();
    if (json == null) return const [];
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported members schema version.');
    }
    return (json['members']! as List<Object?>)
        .map((value) => Member.fromJson(value! as Map<String, Object?>))
        .toList();
  }

  @override
  Future<void> saveAll(List<Member> members) => _store.write({
    'schemaVersion': 1,
    'members': members.map((member) => member.toJson()).toList(),
  });
}
