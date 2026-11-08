import 'package:mighty_core/utils/core_enum.dart';

extension CoreLanguageParser on CoreLanguages {
  static CoreLanguages fromCode(String code) {
    switch (code.toLowerCase()) {
      case 'en':
        return CoreLanguages.english;
      case 'hi':
        return CoreLanguages.hindi;
      case 'ar':
        return CoreLanguages.arabic;
      case 'es':
        return CoreLanguages.spanish;
      case 'zh':
        return CoreLanguages.mandarin;
      case 'fr':
        return CoreLanguages.french;
      case 'bn':
        return CoreLanguages.bengali;
      case 'pt':
        return CoreLanguages.portuguese;
      case 'ru':
        return CoreLanguages.russian;
      case 'ja':
        return CoreLanguages.japanese;
      case 'de':
        return CoreLanguages.german;
      case 'pa':
        return CoreLanguages.punjabi;
      case 'jv':
        return CoreLanguages.javanese;
      case 'ko':
        return CoreLanguages.korean;
      case 'ta':
        return CoreLanguages.tamil;
      case 'tr':
        return CoreLanguages.turkish;
      case 'ur':
        return CoreLanguages.urdu;
      case 'vi':
        return CoreLanguages.vietnamese;
      case 'it':
        return CoreLanguages.italian;
      default:
        return CoreLanguages.english; // fallback
    }
  }
}