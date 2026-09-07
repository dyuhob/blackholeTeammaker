import '../core/storage/atomic_json_file.dart';
import '../domain/member.dart';
import 'member_repository.dart';

class FileMemberRepository implements MemberRepository {
  const FileMemberRepository(this._file);

  final AtomicJsonFile _file;

  @override
  Future<List<Member>> loadAll() async {
    final json = await _file.read();
    if (json == null) return const [];
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported members schema version.');
    }
    return (json['members']! as List<Object?>)
        .map((value) => Member.fromJson(value! as Map<String, Object?>))
        .toList();
  }

  @override
  Future<void> saveAll(List<Member> members) => _file.write({
    'schemaVersion': 1,
    'members': members.map((member) => member.toJson()).toList(),
  });
}
