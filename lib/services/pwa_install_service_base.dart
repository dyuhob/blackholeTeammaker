abstract interface class PwaInstallService {
  Future<bool> shouldOffer();
  bool get canPrompt;
  bool get isIos;
  Future<void> requestInstall();
  Future<void> dismiss();
}
