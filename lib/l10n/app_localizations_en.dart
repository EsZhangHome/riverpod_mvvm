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
  String get privacyConsentTitle => 'Agreements and privacy notice';

  @override
  String get privacyInitialConsentIntroduction =>
      'Before first use, review the privacy policy and user agreement. Accepting selects the agreement option on sign-in. Declining closes this dialog and remains on sign-in without sending a request; it will be shown again on the next launch.';

  @override
  String get privacyLoginConsentIntroduction =>
      'Review and accept the privacy policy and user agreement before signing in. Accepting selects the agreement option and continues when both credentials are present; otherwise it only selects the option without showing an input message. Declining clears the selection and stays on sign-in.';

  @override
  String get privacyPolicyUpgradeTitle => 'Privacy policy updated';

  @override
  String get privacyPolicyUpgradeIntroduction =>
      'The privacy policy has changed. Accept to remain on the current screen. Declining signs out the current account and returns to sign-in; the update will be shown again next launch.';

  @override
  String get privacyPolicyUpgradeLoginIntroduction =>
      'The privacy policy has changed. Review it before signing in again. Accepting continues this sign-in; declining closes the dialog and stays on sign-in.';

  @override
  String privacyConsentVersion(String version) {
    return 'Consent version: $version';
  }

  @override
  String privacyDocumentVersion(String version) {
    return 'Policy document version: $version';
  }

  @override
  String userAgreementDocumentVersion(String version) {
    return 'User agreement document version: $version';
  }

  @override
  String get privacyPolicyAddress => 'Full privacy policy address';

  @override
  String get viewFullPrivacyPolicy => 'Read the full privacy policy';

  @override
  String get viewFullUserAgreement => 'Read the full user agreement';

  @override
  String get privacyPolicyOpenFailed =>
      'The agreement page could not be opened. Check your browser or network and try again.';

  @override
  String get privacyDisclosureDataTitle => 'Information processed';

  @override
  String get privacyDisclosureDataBody =>
      'Sign-in processes the account and password you enter. Other information must be explained when you use the corresponding feature.';

  @override
  String get privacyDisclosurePurposeTitle => 'Why it is processed';

  @override
  String get privacyDisclosurePurposeBody =>
      'It is used for identity verification, session maintenance, and account security, within what the current feature requires.';

  @override
  String get privacyDisclosureThirdPartyTitle =>
      'Permissions and third parties';

  @override
  String get privacyDisclosureThirdPartyBody =>
      'Consent-protected deferred capabilities do not start before acceptance. A real project must list its actual permissions, SDKs, shared data, and purposes in the full policy.';

  @override
  String get privacyDisclosureRightsTitle => 'Your choices and rights';

  @override
  String get privacyDisclosureRightsBody =>
      'You may decline and remain on sign-in. A real project must also provide withdrawal, correction, deletion, account closure, and complaint channels.';

  @override
  String get privacyCenterTitle => 'Privacy center';

  @override
  String get privacyCenterIntroduction =>
      'Review the current agreement versions, previous consent record, and data-handling summary. You can also open the full documents or withdraw consent at any time.';

  @override
  String get privacyCenterStatusTitle => 'Current consent status';

  @override
  String get privacyCenterStatusAccepted => 'Current version accepted';

  @override
  String get privacyCenterStatusOutdated =>
      'The accepted version is outdated and requires confirmation';

  @override
  String get privacyCenterStatusNotAccepted => 'Current version not accepted';

  @override
  String privacyCenterAcceptedVersion(String version) {
    return 'Previously accepted version: $version';
  }

  @override
  String privacyCenterAcceptedAt(String time) {
    return 'Accepted at: $time';
  }

  @override
  String get privacyCenterAcceptedAtUnknown =>
      'The legacy record did not store a time';

  @override
  String get privacyCenterDisclosureTitle => 'How information is processed';

  @override
  String get privacyCenterDocumentsTitle => 'Full agreement documents';

  @override
  String get privacyCenterRevokeTitle => 'Withdraw privacy consent';

  @override
  String get privacyCenterRevokeDescription =>
      'Withdrawal prevents consent-protected capabilities that have not started, removes the current consent record, and signs you out. A real project must also stop already initialized SDK collection according to vendor guidance and require an app restart when necessary.';

  @override
  String get privacyCenterRevokeAction => 'Withdraw consent and sign out';

  @override
  String get privacyCenterRevokeConfirmTitle => 'Withdraw privacy consent?';

  @override
  String get privacyCenterRevokeConfirmBody =>
      'Your current account will be signed out. You must review and accept the current agreements before signing in again.';

  @override
  String get privacyCenterRevokeConfirmAction => 'Withdraw';

  @override
  String get privacyCenterRevokeSucceeded => 'Privacy consent withdrawn';

  @override
  String get privacyCenterRevokeFailed =>
      'The consent record or sign-in session could not be cleared. Try again. This process will not treat the app as consented when starting new capabilities.';

  @override
  String get cancel => 'Cancel';

  @override
  String get agreeAndContinue => 'Agree and continue';

  @override
  String get agreeAndContinueUsing => 'Agree and keep using';

  @override
  String get declineAndLogout => 'Decline and sign out';

  @override
  String get disagree => 'Disagree';

  @override
  String get privacyConsentSaveFailed =>
      'The consent choice could not be saved. The sign-in request has not been sent. Try again.';

  @override
  String get privacyLogoutFailed =>
      'Sign-out or session cleanup failed. The current screen remains protected. Try again.';

  @override
  String get privacyLoginPreparationFailed =>
      'The previous sign-in state could not be cleared, so sign-in is temporarily unavailable. Try again.';

  @override
  String get login => 'Sign in';

  @override
  String get loginAgreementPrefix => 'I agree to the';

  @override
  String get privacyAgreementName => 'Privacy Policy';

  @override
  String get agreementAnd => 'and';

  @override
  String get userAgreementName => 'User Agreement';

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
