// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get initializationFailed => 'Application initialization failed';

  @override
  String failedStages(String stages) {
    return 'Failed stages: $stages';
  }

  @override
  String get retry => 'Retry';

  @override
  String get networkDisconnected =>
      'No network connection. Check your network settings.';

  @override
  String get networkRestored => 'Network connection restored';

  @override
  String get networkPoor => 'The network is slow. Trying to reconnect.';

  @override
  String get networkQualityRestored => 'Network quality restored';
}
