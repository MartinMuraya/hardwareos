// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swahili (`sw`).
class AppLocalizationsSw extends AppLocalizations {
  AppLocalizationsSw([String locale = 'sw']) : super(locale);

  @override
  String get dashboard => 'Dashibodi';

  @override
  String get pos => 'Uuzaji (POS)';

  @override
  String get inventory => 'Stoo';

  @override
  String get accounting => 'Uhasibu';

  @override
  String get expenses => 'Matumizi';

  @override
  String get reports => 'Ripoti';

  @override
  String get customers => 'Wateja';

  @override
  String get checkout => 'Kamilisha';

  @override
  String get total => 'Jumla';

  @override
  String get pay => 'Lipa';
}

/// The translations for Swahili, as used in Kenya (`sw_KE`).
class AppLocalizationsSwKe extends AppLocalizationsSw {
  AppLocalizationsSwKe() : super('sw_KE');

  @override
  String get dashboard => 'Base';

  @override
  String get pos => 'Kuuza';

  @override
  String get inventory => 'Mzigo';

  @override
  String get accounting => 'Hesabu';

  @override
  String get expenses => 'Matumizi';

  @override
  String get reports => 'Ripo';

  @override
  String get customers => 'Mawania';

  @override
  String get checkout => 'Maliza';

  @override
  String get total => 'Jumla';

  @override
  String get pay => 'Chapaa';
}
