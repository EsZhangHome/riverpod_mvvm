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
  String get login => 'Sign in';

  @override
  String get account => 'Phone or email';

  @override
  String get password => 'Password';

  @override
  String get enterAccount => 'Enter your phone number or email';

  @override
  String get enterPassword => 'Enter your password';

  @override
  String get backHome => 'Back to home';

  @override
  String get noData => 'No data';

  @override
  String get pageNotFound => 'Page not found';

  @override
  String get requestTimeout => 'The request timed out. Try again later.';

  @override
  String get requestCanceled => 'The request was canceled';

  @override
  String get networkError => 'Network connection error';

  @override
  String get unknownError => 'Something went wrong. Try again later.';

  @override
  String get serverError => 'Server error. Try again later.';

  @override
  String get requestFailed => 'Request failed. Try again later.';

  @override
  String get sessionExpired => 'Your session has expired. Sign in again.';

  @override
  String get permissionDenied => 'You do not have permission to do this';

  @override
  String get validationFailed => 'Please check the submitted information';

  @override
  String get storageError => 'Local data could not be saved';

  @override
  String get protocolError => 'The server response format is invalid';

  @override
  String get networkDisconnected =>
      'No network connection. Check your network settings.';

  @override
  String get networkRestored => 'Network connection restored';
}
