# Vercel PWA 전환 설계

## 목적

현재 Android Flutter 앱을 동일한 기능의 정적 웹 앱으로도 빌드하고 Vercel에 배포한다. 사용자는 배포 URL을 휴대폰 브라우저에서 열거나 홈 화면에 설치해 사용할 수 있다. `main` 브랜치에 푸시하면 검증된 웹 빌드가 Vercel 프로덕션 환경에 자동 배포된다.

기존 Android APK 빌드는 계속 가능하게 유지한다. 기존 GitHub Releases의 APK는 삭제하지 않지만, 이 작업 이후의 주 배포 경로는 Vercel PWA다.

## 범위

- 기존 Flutter 프로젝트에 Web 플랫폼 파일을 추가한다.
- 회원 목록과 팀 편성 기록을 웹 브라우저의 로컬 저장소에 JSON 문자열로 저장한다.
- Android에서는 현재 앱 전용 JSON 파일 저장 방식을 유지한다.
- 웹의 결과 이미지 저장은 PNG 파일 다운로드로 제공한다.
- 설치 가능한 웹 앱 메타데이터와 오프라인 실행용 서비스 워커를 추가한다.
- GitHub Actions에서 테스트와 웹 빌드를 수행한 후 Vercel에 정적 파일을 배포한다.

이번 범위에는 로그인, 기기 간 데이터 동기화, 서버 저장, Supabase 연동, 저장 데이터의 기본·백업 키 운용이 포함되지 않는다.

## 저장 구조

기존 `MemberRepository`와 `TeamHistoryRepository` 인터페이스를 유지한다. 화면과 컨트롤러는 저장 위치를 알지 못하며 플랫폼 조립 단계에서 구현체만 선택한다. 이 경계를 유지하면 이후 브라우저 저장소 구현을 Supabase 구현으로 교체해도 기능 화면을 수정할 필요가 없다.

Android 조립 코드는 현재의 `FileMemberRepository`, `FileTeamHistoryRepository`, `AtomicJsonFile`을 사용한다. 웹 조립 코드는 브라우저 로컬 저장소를 사용하는 구현을 주입한다.

웹에서는 다음 두 키에 기존 파일 저장소와 동일한 스키마의 JSON 문자열을 저장한다.

- `team_maker.members_v1`: `schemaVersion`과 `members` 배열
- `team_maker.team_history_v1`: `schemaVersion`과 `records` 배열

각 키는 한 번의 쓰기로 교체한다. 별도의 백업 키나 자동 복구 사본은 만들지 않는다. JSON이 손상됐거나 지원하지 않는 스키마라면 기존 컨트롤러 오류 흐름을 통해 사용자에게 불러오기 실패를 알리고 원본 값을 임의로 덮어쓰지 않는다.

브라우저 데이터는 도메인과 브라우저 프로필에 종속된다. 사용자가 사이트 데이터나 브라우저 저장소를 삭제하면 함께 삭제되며, 다른 기기로 자동 동기화되지 않는다.

## 플랫폼 조립

`main.dart`에서는 조건부 내보내기를 사용하는 앱 조립 함수만 호출한다.

- IO 플랫폼 조립: 앱 지원 디렉터리의 JSON 파일 저장소와 `Gal` 기반 갤러리 내보내기
- Web 플랫폼 조립: 브라우저 JSON 저장소와 PNG 다운로드 내보내기

웹 컴파일 경로에서는 `dart:io`, `path_provider`, `gal`을 가져오지 않는다. Android 컴파일 경로에서는 브라우저 API를 가져오지 않는다. 공통 화면은 `GalleryExporter` 인터페이스만 의존하도록 인터페이스와 플랫폼 구현 파일을 분리한다.

## 결과 이미지 다운로드

팀 결과 이미지를 만드는 과정은 현재와 같이 `ScreenshotController`와 `TeamResultExportWidget`을 사용한다. Android 구현은 생성한 PNG 바이트를 갤러리에 저장한다. 웹 구현은 같은 PNG 바이트로 브라우저 다운로드를 시작한다.

웹에서는 “갤러리에 저장” 문구가 실제 동작에 맞게 “이미지 다운로드”로 표시된다. 성공과 실패 메시지도 플랫폼에 맞는 표현을 사용한다. 다운로드 파일명은 현재 제목 정제 규칙과 생성 시각을 유지한다.

## PWA 구성

Flutter 3.47.2 형식의 Web 진입 파일을 생성하고 앱 이름, 설명, 테마 색상, 시작 URL, standalone 표시 모드를 manifest에 정의한다. 현재 Android 런처 아이콘을 바탕으로 192px와 512px 일반·maskable 아이콘 및 favicon을 만든다.

Flutter가 기본 서비스 워커를 더 이상 생성하지 않으므로 프로젝트가 관리하는 `service_worker.js`를 등록한다. 서비스 워커는 다음 정책을 사용한다.

- 같은 출처의 GET 요청은 온라인에서 최신 응답을 우선 사용하고 성공한 응답을 캐시에 갱신한다.
- 네트워크를 사용할 수 없으면 캐시된 응답을 반환한다.
- 문서 탐색 요청이 캐시에 없으면 캐시된 `/index.html`로 대체한다.
- 서비스 워커 파일 자체는 Vercel에서 재검증하도록 캐시 방지 헤더를 설정한다.

이 정책은 온라인 접속 시 새 배포를 우선 반영하면서, 한 번 정상 로드한 앱은 오프라인에서도 다시 열 수 있게 한다.

## Vercel 배포

GitHub Actions 워크플로는 `main` 푸시와 수동 실행에서 동작한다.

1. 저장소를 체크아웃한다.
2. 프로젝트에 고정된 Flutter 버전 3.47.2를 설치하고 패키지를 받는다.
3. `flutter analyze`와 `flutter test`를 실행한다.
4. `flutter build web --release`로 `build/web`을 생성한다.
5. 결과물을 Vercel Build Output API의 `.vercel/output/static` 구조로 준비한다.
6. Vercel CLI의 `deploy --prebuilt --prod`로 프로덕션 배포한다.

Vercel 정적 설정은 SPA 진입 처리, 서비스 워커 캐시 헤더, 보안 관련 기본 헤더를 저장소에서 관리한다. 배포 워크플로에는 다음 GitHub Actions Secrets가 필요하다.

- `VERCEL_TOKEN`
- `VERCEL_ORG_ID`
- `VERCEL_PROJECT_ID`

최초 한 번 Vercel 계정 로그인과 프로젝트 연결을 완료한 뒤 값을 GitHub 저장소 Secrets에 등록한다. 이후 `main` 푸시는 별도 수동 작업 없이 프로덕션 URL을 갱신한다.

## 오류 처리

- 웹 저장소 접근이나 JSON 해석 실패는 Repository 예외로 전달하고 기존 화면의 오류 메시지로 표시한다.
- 저장 실패 시 메모리의 편집 상태를 유지해 사용자가 다시 시도할 수 있게 한다.
- 이미지 생성 또는 다운로드 실패는 현재 결과 화면의 스낵바로 알린다.
- 분석이나 테스트, 웹 빌드 중 하나라도 실패하면 GitHub Actions는 Vercel 배포를 실행하지 않는다.
- 배포 실패는 기존 프로덕션 배포에 영향을 주지 않고 실패한 워크플로 실행에 기록한다.

## 검증

- 브라우저 저장소 회원·기록 Repository의 JSON 읽기, 쓰기, 삭제 테스트
- 잘못된 JSON과 지원하지 않는 스키마 처리 테스트
- 플랫폼 조건부 조립에 대한 분석 및 Android·Web 빌드 검증
- 기존 전체 Flutter 테스트
- Chrome에서 회원 저장 후 새로고침, 팀 기록 재열람, PNG 다운로드 확인
- manifest, 아이콘, 서비스 워커 등록 및 오프라인 재실행 확인
- Vercel 프로덕션 URL의 HTTP 200 응답과 `main` 푸시 자동 배포 확인

## 향후 Supabase 전환

Supabase 연동 시 `MemberRepository`와 `TeamHistoryRepository`의 새 구현을 추가하고 Web 앱 조립에서 주입 대상을 바꾼다. 인증과 사용자별 데이터 구조는 그 작업에서 별도로 설계한다. 이번 브라우저 JSON 형식은 필요하면 초기 마이그레이션 입력으로 사용할 수 있지만, 자동 업로드나 동기화는 수행하지 않는다.
