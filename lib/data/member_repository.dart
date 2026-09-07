import '../domain/member.dart';

abstract interface class MemberRepository {
  Future<List<Member>> loadAll();
  Future<void> saveAll(List<Member> members);
}
