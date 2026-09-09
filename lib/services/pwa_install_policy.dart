bool shouldOfferPwaInstall({
  required bool isStandalone,
  required DateTime? dismissedAt,
  required DateTime now,
}) {
  if (isStandalone) return false;
  if (dismissedAt == null) return true;
  return !now.isBefore(dismissedAt.add(const Duration(days: 7)));
}
