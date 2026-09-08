import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Vercel serves the web build and revalidates the service worker', () {
    final config = jsonDecode(
      File('vercel.json').readAsStringSync(),
    ) as Map<String, Object?>;

    expect(config['framework'], isNull);
    expect(config['outputDirectory'], 'build/web');
    final headers = config['headers']! as List<Object?>;
    final workerHeaders = headers.whereType<Map<String, Object?>>().singleWhere(
      (entry) => entry['source'] == '/service_worker.js',
    );
    expect(workerHeaders.toString(), contains('no-cache'));
    expect(workerHeaders.toString(), contains('no-store'));
  });

  test('main pushes validate and deploy a prebuilt PWA to Vercel', () {
    final workflow = File('.github/workflows/deploy-vercel.yml')
        .readAsStringSync();

    expect(workflow, contains('branches: [main]'));
    expect(workflow, contains('workflow_dispatch:'));
    expect(workflow, contains("flutter-version: '3.47.2'"));
    expect(workflow, contains('flutter analyze'));
    expect(workflow, contains('flutter test'));
    expect(
      workflow,
      contains(
        'dart test -p chrome test/web/browser_json_object_store_test.dart',
      ),
    );
    expect(
      workflow,
      contains('flutter build web --release --no-web-resources-cdn'),
    );
    expect(workflow, contains('.vercel/output/static'));
    expect(workflow, contains('"version": 3'));
    expect(workflow, contains('"handle": "filesystem"'));
    expect(workflow, contains('vercel@59.11.7 deploy --prebuilt --prod'));
    expect(workflow, contains('secrets.VERCEL_TOKEN'));
    expect(workflow, contains('secrets.VERCEL_ORG_ID'));
    expect(workflow, contains('secrets.VERCEL_PROJECT_ID'));

    final analyze = workflow.indexOf('flutter analyze');
    final tests = workflow.indexOf('flutter test');
    final build = workflow.indexOf('flutter build web');
    final deploy = workflow.indexOf('vercel@59.11.7 deploy');
    expect(analyze, lessThan(tests));
    expect(tests, lessThan(build));
    expect(build, lessThan(deploy));
  });
}
