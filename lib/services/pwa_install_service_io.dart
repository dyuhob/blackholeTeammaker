import 'pwa_install_service_base.dart';

PwaInstallService createPwaInstallService() => const _NoPwaInstallService();

class _NoPwaInstallService implements PwaInstallService {
  const _NoPwaInstallService();

  @override
  bool get canPrompt => false;

  @override
  bool get isIos => false;

  @override
  Future<void> dismiss() async {}

  @override
  Future<void> requestInstall() async {}

  @override
  Future<bool> shouldOffer() async => false;
}
