// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get starterMessage =>
      'The enterprise starter is ready. Replace this page with your first business feature.';

  @override
  String get initializationFailed => 'Application initialization failed';

  @override
  String failedStages(String stages) {
    return 'Failed stages: $stages';
  }

  @override
  String get retry => 'Retry';
}
