@JS()
library;

import 'dart:js_interop';

import 'pwa_install_service_base.dart';

@JS('teamMakerPwaInstall.shouldShow')
external bool _shouldShow();

@JS('teamMakerPwaInstall.canPrompt')
external bool _canPrompt();

@JS('teamMakerPwaInstall.isIos')
external bool _isIos();

@JS('teamMakerPwaInstall.prompt')
external void _prompt();

@JS('teamMakerPwaInstall.dismiss')
external void _dismiss();

PwaInstallService createPwaInstallService() => const _WebPwaInstallService();

class _WebPwaInstallService implements PwaInstallService {
  const _WebPwaInstallService();

  @override
  bool get canPrompt => _canPrompt();

  @override
  bool get isIos => _isIos();

  @override
  Future<void> dismiss() async => _dismiss();

  @override
  Future<void> requestInstall() async => _prompt();

  @override
  Future<bool> shouldOffer() async => _shouldShow();
}
