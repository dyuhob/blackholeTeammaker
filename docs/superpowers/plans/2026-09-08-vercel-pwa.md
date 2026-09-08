# Vercel PWA Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 기존 Android 동작을 유지하면서 팀짜기 앱을 설치 가능한 정적 PWA로 빌드하고 `main` 푸시마다 Vercel에 자동 배포한다.

**Architecture:** 회원과 기록의 JSON 직렬화 Repository는 공통 `JsonObjectStore`를 사용하고, Android에서는 파일 저장소를, Web에서는 단일 브라우저 로컬 저장 키를 주입한다. 앱 진입점은 조건부 내보내기로 플랫폼별 저장소와 이미지 내보내기를 조립한다. GitHub Actions가 Flutter 검증과 Web 빌드를 수행한 후 정적 결과물을 Vercel의 사전 빌드 출력으로 배포한다.

**Tech Stack:** Flutter 3.47.2, Dart 3.13.2, `package:web`, Flutter Web, Web App Manifest, Service Worker, GitHub Actions, Vercel CLI/Build Output API

**Spec:** `docs/superpowers/specs/2026-09-08-vercel-pwa-design.md`

## Global Constraints

- Android 앱의 앱 전용 JSON 파일 저장과 갤러리 저장 동작을 유지한다.
- Web 데이터는 `team_maker.members_v1`과 `team_maker.team_history_v1` 단일 키에 각각 저장한다.
- Web 저장소는 기본·백업 키나 자동 복구 사본을 만들지 않는다.
- 화면과 컨트롤러는 `MemberRepository`, `TeamHistoryRepository`, `GalleryExporter` 인터페이스에만 의존한다.
- `main` 푸시 배포 전에 `flutter analyze`, `flutter test`, `flutter build web --release`가 모두 성공해야 한다.
- 기존 GitHub APK 릴리스는 삭제하지 않는다.

---

### Task 1: 플랫폼 공통 JSON 저장소 경계

**Files:**
- Create: `lib/core/storage/json_object_store.dart`
- Create: `lib/data/json_member_repository.dart`
- Create: `lib/data/json_team_history_repository.dart`
- Modify: `lib/core/storage/atomic_json_file.dart`
- Delete: `lib/data/file_member_repository.dart`
- Delete: `lib/data/file_team_history_repository.dart`
- Modify: `test/data/file_repositories_test.dart`
- Create: `test/data/json_repositories_test.dart`

**Interfaces:**
- Produces: `JsonObjectStore.read(): Future<Map<String, Object?>?>`
- Produces: `JsonObjectStore.write(Map<String, Object?> value): Future<void>`
- Produces: `JsonMemberRepository(JsonObjectStore store)` implementing `MemberRepository`
- Produces: `JsonTeamHistoryRepository(JsonObjectStore store)` implementing `TeamHistoryRepository`

- [ ] **Step 1: Write failing repository tests against an in-memory `JsonObjectStore`**

```dart
test('member repository stores the versioned member JSON document', () async {
  final store = MemoryJsonObjectStore();
  final repository = JsonMemberRepository(store);
  await repository.saveAll([Member(id: '1', name: '김회원', score: 180)]);
  expect(store.value, {
    'schemaVersion': 1,
    'members': [
      {'id': '1', 'name': '김회원', 'score': 180},
    ],
  });
});
```

Add equivalent load, unsupported-schema, history save/update/delete tests. Keep existing atomic file corruption tests focused on `AtomicJsonFile`.

- [ ] **Step 2: Run the new repository test and verify RED**

Run: `flutter test test/data/json_repositories_test.dart`

Expected: compilation fails because `JsonObjectStore`, `JsonMemberRepository`, and `JsonTeamHistoryRepository` do not exist.

- [ ] **Step 3: Implement the common store interface and JSON repositories**

```dart
abstract interface class JsonObjectStore {
  Future<Map<String, Object?>?> read();
  Future<void> write(Map<String, Object?> value);
}
```

Move the current schema parsing and serialization behavior from the two file-named repositories into the new repositories. Make `AtomicJsonFile implements JsonObjectStore` without changing its atomic file behavior.

- [ ] **Step 4: Run storage tests and verify GREEN**

Run: `flutter test test/data/json_repositories_test.dart test/data/file_repositories_test.dart`

Expected: all storage tests pass.

- [ ] **Step 5: Commit the storage boundary**

```bash
git add lib/core/storage lib/data test/data
git commit -m "refactor: separate JSON repositories from file storage"
```

### Task 2: 브라우저 단일 키 저장소

**Files:**
- Create: `lib/core/storage/browser_json_object_store.dart`
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Create: `test/web/browser_json_object_store_test.dart`

**Interfaces:**
- Consumes: `JsonObjectStore`, `JsonMemberRepository`, `JsonTeamHistoryRepository`
- Produces: `BrowserJsonObjectStore(String key)` using exactly one `window.localStorage` entry

- [ ] **Step 1: Write browser tests for missing, valid, malformed, and overwritten JSON**

```dart
@TestOn('browser')
void main() {
  test('writes one JSON value and reads it back', () async {
    final store = BrowserJsonObjectStore('team_maker.test');
    await store.write({'schemaVersion': 1, 'members': <Object>[]});
    expect(await store.read(), {'schemaVersion': 1, 'members': <Object>[]});
  });
}
```

Clear the test key in setup and teardown. Assert malformed JSON throws `FormatException` and that no secondary key is created.

- [ ] **Step 2: Run the browser test and verify RED**

Run: `flutter test --platform chrome test/web/browser_json_object_store_test.dart`

Expected: compilation fails because `BrowserJsonObjectStore` does not exist.

- [ ] **Step 3: Add `package:web` and implement browser storage**

```dart
final class BrowserJsonObjectStore implements JsonObjectStore {
  const BrowserJsonObjectStore(this.key);
  final String key;

  @override
  Future<Map<String, Object?>?> read() async {
    final source = window.localStorage.getItem(key);
    if (source == null) return null;
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('JSON root must be an object.');
    }
    return decoded;
  }

  @override
  Future<void> write(Map<String, Object?> value) async {
    window.localStorage.setItem(key, jsonEncode(value));
  }
}
```

Use the current stable `package:web` API. Do not create a backup key.

- [ ] **Step 4: Run browser storage and existing app tests**

Run: `flutter test --platform chrome test/web/browser_json_object_store_test.dart`

Run: `flutter test`

Expected: both commands pass.

- [ ] **Step 5: Commit browser storage**

```bash
git add lib/core/storage pubspec.yaml pubspec.lock test/web
git commit -m "feat: add browser JSON storage"
```

### Task 3: 플랫폼별 결과 이미지 저장

**Files:**
- Create: `lib/services/gallery_exporter.dart`
- Create: `lib/services/team_result_image_renderer.dart`
- Modify: `lib/services/gallery_export_service.dart`
- Create: `lib/services/web_gallery_export_service.dart`
- Create: `lib/bootstrap/app_factory.dart`
- Create: `lib/bootstrap/app_factory_io.dart`
- Create: `lib/bootstrap/app_factory_web.dart`
- Modify: `lib/main.dart`
- Modify: `lib/app/app_shell.dart`
- Modify: `lib/app/team_maker_app.dart`
- Modify: `lib/features/history/history_screen.dart`
- Modify: `lib/features/history/team_result_screen.dart`
- Modify: `lib/features/team_builder/team_builder_screen.dart`
- Modify: `test/support/memory_repositories.dart`
- Create: `test/app/export_copy_test.dart`

**Interfaces:**
- Produces: `GalleryExporter.actionLabel`, `busyLabel`, `successMessage`, `failureMessage`
- Produces: `GalleryExporter.save(BuildContext context, TeamResult result)`
- Produces: `captureTeamResultImage(BuildContext context, TeamResult result): Future<Uint8List>`
- Produces: `WebGalleryExportService` that downloads generated PNG bytes

- [ ] **Step 1: Write a widget test for platform-provided export copy**

```dart
testWidgets('result screen uses the exporter download labels', (tester) async {
  final exporter = MemoryGalleryExporter(
    actionLabel: '이미지 다운로드',
    successMessage: '이미지를 다운로드했습니다.',
  );
  await tester.pumpWidget(MaterialApp(
    home: TeamResultScreen(
      result: sampleResult,
      historyController: historyController,
      galleryExporter: exporter,
      initiallySaved: true,
    ),
  ));
  expect(find.text('이미지 다운로드'), findsOneWidget);
  await tester.tap(find.text('이미지 다운로드'));
  await tester.pumpAndSettle();
  expect(find.text('이미지를 다운로드했습니다.'), findsOneWidget);
});
```

In the test file, construct `sampleResult` with one regular participant and construct `historyController` with `MemoryHistoryRepository`; dispose the controller with `addTearDown`.

- [ ] **Step 2: Run the copy test and verify RED**

Run: `flutter test test/app/export_copy_test.dart`

Expected: compilation fails because exporter copy properties and constructor arguments do not exist.

- [ ] **Step 3: Split the interface and image renderer from mobile export**

Move the interface into `gallery_exporter.dart`. Extract screenshot capture into `team_result_image_renderer.dart`. Keep `GalleryExportService` responsible only for Android/desktop gallery saving and give it the existing gallery wording.

- [ ] **Step 4: Implement Web PNG download**

Use `package:web` and `dart:js_interop` to create an `image/png` Blob, create a temporary object URL, click an anchor with the sanitized `<title>_<milliseconds>.png` filename, remove the anchor, and revoke the object URL. Give the exporter the Web copy “이미지 다운로드”, “이미지 생성 중…”, “이미지를 다운로드했습니다.”, and “이미지를 다운로드하지 못했습니다.”.

- [ ] **Step 5: Add conditional platform app factories**

`app_factory.dart` conditionally exports the IO implementation and selects the Web implementation for `dart.library.js_interop`. The IO factory uses two `AtomicJsonFile` stores and `GalleryExportService`. The Web factory uses two `BrowserJsonObjectStore` instances with the exact keys from Global Constraints and `WebGalleryExportService`. `main.dart` only initializes Flutter and calls `runApp(createApp())`.

- [ ] **Step 6: Make result UI read copy from the exporter and verify GREEN**

Run: `flutter test test/app/export_copy_test.dart test/app/app_flow_test.dart`

Expected: the Web-style test copy and existing flows pass.

- [ ] **Step 7: Commit platform export behavior and composition**

```bash
git add lib/services lib/bootstrap lib/main.dart lib/app lib/features test
git commit -m "feat: download team result images on web"
```

### Task 4: 설치 가능하고 오프라인 실행되는 Web 앱

**Files:**
- Create: `web/index.html`
- Create: `web/manifest.json`
- Create: `web/service_worker.js`
- Create: `web/favicon.png`
- Create: `web/icons/Icon-192.png`
- Create: `web/icons/Icon-512.png`
- Create: `web/icons/Icon-maskable-192.png`
- Create: `web/icons/Icon-maskable-512.png`
- Create: `test/config/pwa_assets_test.dart`

**Interfaces:**
- Consumes: Flutter-generated `flutter_bootstrap.js` and `main.dart.js`
- Produces: installable manifest at `/manifest.json`
- Produces: network-first, cache-fallback service worker at `/service_worker.js`

- [ ] **Step 1: Write configuration tests for the PWA files**

Parse `web/manifest.json` and assert Korean name, `/` start URL, `standalone` display, theme colors, and 192/512 normal and maskable icons. Assert `index.html` links the manifest and registers `/service_worker.js`. Assert the worker handles install, activate, fetch, cache fallback, and `/index.html` navigation fallback.

- [ ] **Step 2: Run the PWA configuration test and verify RED**

Run: `flutter test test/config/pwa_assets_test.dart`

Expected: failure because the `web` files do not exist.

- [ ] **Step 3: Add the Flutter 3.47 Web scaffold and PWA metadata**

Use the current Flutter bootstrap token and no deprecated generated-service-worker token. Set manifest display to `standalone`, orientation to `portrait-primary`, theme color to `#1976D2`, and background color to `#FFFFFF`.

- [ ] **Step 4: Generate icon assets from the current launcher icon**

Resize the committed 192px Android launcher icon with high-quality resampling to favicon, 192px, and 512px outputs. Produce maskable icons with sufficient safe-zone padding and verify each PNG's exact dimensions.

- [ ] **Step 5: Add and syntax-check the custom service worker**

Implement online network response caching for same-origin GET requests, cached fallback, and navigation fallback. Use a versioned cache name and remove older `team-maker-` caches on activation.

Run: `node --check web/service_worker.js`

Expected: exit code 0.

- [ ] **Step 6: Run PWA tests and a release Web build**

Run: `flutter test test/config/pwa_assets_test.dart`

Run: `flutter build web --release`

Expected: tests pass and `build/web/index.html`, manifest, worker, icons, and Flutter bundles exist.

- [ ] **Step 7: Commit the PWA shell**

```bash
git add web test/config
git commit -m "feat: add installable offline PWA shell"
```

### Task 5: Vercel 정적 설정과 `main` 자동 배포

**Files:**
- Create: `vercel.json`
- Create: `.github/workflows/deploy-vercel.yml`
- Create: `test/config/vercel_deployment_test.dart`
- Modify: `.gitignore`
- Modify: `README.md`

**Interfaces:**
- Consumes secrets: `VERCEL_TOKEN`, `VERCEL_ORG_ID`, `VERCEL_PROJECT_ID`
- Produces: `.vercel/output/config.json` with Build Output API version 3
- Produces: Vercel production deployment on every `main` push

- [ ] **Step 1: Write static deployment configuration tests**

Assert `vercel.json` applies `no-cache` to `/service_worker.js` and SPA fallback to `/index.html`. Assert the workflow triggers on `main` push and manual dispatch, pins Flutter `3.47.2`, runs analyze/test/Web build before deploy, builds `.vercel/output/static`, and invokes `vercel deploy --prebuilt --prod` with the three secret names.

- [ ] **Step 2: Run deployment configuration tests and verify RED**

Run: `flutter test test/config/vercel_deployment_test.dart`

Expected: failure because Vercel configuration and workflow do not exist.

- [ ] **Step 3: Add Vercel routing and headers**

Set `framework` to null, disable Vercel's own build command for prebuilt workflow usage, add the service worker cache header, and configure a filesystem-first SPA fallback so static Flutter assets remain directly accessible.

- [ ] **Step 4: Add the GitHub Actions workflow**

Use maintained checkout and Flutter setup actions, cache Flutter dependencies, run all three validation commands in order, copy `build/web` into `.vercel/output/static`, generate project metadata from the three secrets without logging them, install the pinned Vercel CLI, and deploy production only after all validation steps succeed.

- [ ] **Step 5: Update repository documentation**

Document local Web execution, release Web build, browser-local data limitations, PWA installation, required Vercel/GitHub configuration, and the fact that future storage can replace Repository implementations with Supabase.

- [ ] **Step 6: Run configuration tests and commit**

Run: `flutter test test/config/vercel_deployment_test.dart`

Expected: pass.

```bash
git add vercel.json .github/workflows/deploy-vercel.yml .gitignore README.md test/config
git commit -m "ci: deploy Flutter PWA to Vercel"
```

### Task 6: 전체 검증과 프로덕션 연결

**Files:**
- Modify: `pubspec.yaml` (release version)
- Modify: `README.md` (production URL after deployment)

**Interfaces:**
- Consumes: Vercel account authentication and GitHub repository secret permissions
- Produces: public Vercel production URL and automatic deployment workflow

- [ ] **Step 1: Run local quality gates**

Run: `dart format --output=none --set-exit-if-changed lib test`

Run: `flutter analyze`

Run: `flutter test`

Run: `flutter test --platform chrome test/web/browser_json_object_store_test.dart`

Expected: all commands pass with no analyzer issues.

- [ ] **Step 2: Build both supported targets**

Run: `flutter build web --release`

Run: `flutter build apk --release`

Expected: both builds complete and produce `build/web` and `build/app/outputs/flutter-apk/app-release.apk`.

- [ ] **Step 3: Perform a local browser smoke check**

Serve `build/web` over HTTP. Verify the app opens, member save survives reload, a result record survives reload, result PNG downloads, manifest is reachable, and service worker becomes active. Disable the network and reload once to verify cached app startup.

- [ ] **Step 4: Link or create the Vercel project**

Install the current Vercel CLI locally, authenticate the user's existing account, and link the repository to a Vercel project. Read the resulting organization and project IDs without committing `.vercel/project.json`.

- [ ] **Step 5: Configure deployment credentials**

Create a Vercel access token in the user's account and store it as `VERCEL_TOKEN`; store the linked IDs as `VERCEL_ORG_ID` and `VERCEL_PROJECT_ID` in GitHub Actions Secrets. Never print the token or commit any of these values.

- [ ] **Step 6: Merge, push, and verify automatic deployment**

Merge the feature branch into `main`, push `main`, watch the deployment workflow to completion, and verify the public URL returns HTTP 200 for `/`, `/manifest.json`, and `/service_worker.js`.

- [ ] **Step 7: Record the production URL**

Add the verified URL to `README.md`, commit, push, confirm the second automatic deployment succeeds, and ensure the repository is clean and synchronized with `origin/main`.
