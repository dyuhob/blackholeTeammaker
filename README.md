# 블랙홀 팀짜기

클럽원 점수와 참가 인원을 관리하고 무작위로 팀을 편성하는 Flutter 앱입니다. Android 앱과 설치 가능한 Web PWA를 같은 코드로 제공합니다.

## 로컬 실행

```powershell
flutter pub get
flutter run -d chrome
```

Android에서 실행하려면 연결된 기기나 에뮬레이터를 선택해 `flutter run`을 실행합니다.

## 빌드와 검증

```powershell
flutter analyze
flutter test
dart test -p chrome test/web/browser_json_object_store_test.dart
flutter build web --release --no-web-resources-cdn --pwa-strategy=none
flutter build apk --release
```

Web 결과물은 `build/web`, Android APK는 `build/app/outputs/flutter-apk/app-release.apk`에 생성됩니다.

## 데이터 저장

- Android: 앱 지원 디렉터리의 JSON 파일
- Web: 현재 도메인과 브라우저 프로필의 `localStorage`에 저장되는 JSON 문자열

Web 데이터는 사이트 데이터와 함께 삭제될 수 있고 다른 브라우저나 기기로 동기화되지 않습니다. 저장 계층은 Repository 인터페이스로 분리되어 있어 이후 Supabase 구현으로 교체할 수 있습니다.

## PWA 설치

Vercel 프로덕션 주소를 Chrome 또는 Edge에서 연 다음 브라우저 메뉴의 **앱 설치** 또는 **홈 화면에 추가**를 선택합니다. 앱을 온라인에서 한 번 정상 로드하면 필요한 실행 파일이 캐시되어 오프라인에서도 다시 열 수 있습니다.

## Vercel 자동 배포

`.github/workflows/deploy-vercel.yml`은 `main` 브랜치가 갱신될 때 다음 작업을 수행합니다.

1. Flutter 분석과 전체 테스트
2. 실제 브라우저에서 로컬 저장소 테스트
3. Flutter Web 릴리스 빌드
4. Vercel 프로덕션 배포

GitHub 저장소의 Actions Secrets에 다음 값을 등록해야 합니다.

- `VERCEL_TOKEN`
- `VERCEL_ORG_ID`
- `VERCEL_PROJECT_ID`

`.vercel` 디렉터리에는 계정별 프로젝트 정보가 들어가므로 Git에 커밋하지 않습니다.

## 기존 Android 배포

기존 GitHub Releases의 APK는 그대로 유지됩니다. 이후 기본 배포 대상은 Vercel PWA입니다.
