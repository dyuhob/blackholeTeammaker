import 'package:flutter/widgets.dart';

import '../domain/team_result.dart';

abstract interface class GalleryExporter {
  String get actionLabel;

  String get busyLabel;

  String get successMessage;

  String get failureMessage;

  Future<void> save(BuildContext context, TeamResult result);

  Future<void> share(BuildContext context, TeamResult result);
}
