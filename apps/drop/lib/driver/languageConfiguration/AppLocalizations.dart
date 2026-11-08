import 'package:flutter/material.dart';

import 'BaseLanguage.dart';
import 'LanguageDataConstant.dart';

class AppLocalizations extends LocalizationsDelegate<BaseLanguage> {
  const AppLocalizations();

  @override
  Future<BaseLanguage> load(Locale locale) async {
    switch (locale.languageCode) {
      case 'en':
        return BaseLanguage();
      default:
        return BaseLanguage();
    }
  }

  @override
  bool isSupported(Locale locale) =>
      getSupportedLocales().contains(locale.languageCode);

  @override
  bool shouldReload(LocalizationsDelegate<BaseLanguage> old) => false;
}
