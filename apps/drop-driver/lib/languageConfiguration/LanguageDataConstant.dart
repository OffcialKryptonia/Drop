import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:taxi_driver/utils/utils.dart';

import '../main.dart';
import 'LanguageDefaultJson.dart';
import 'LocalLanguageResponse.dart';
import 'ServerLanguageResponse.dart';

const LanguageJsonDataRes = 'LanguageJsonDataRes'; // DO NOT CHANGE
const CURRENT_LAN_VERSION = 'LanguageData'; // DO NOT CHANGE
const LanguageVersion = '0'; // DO NOT CHANGE
const SELECTED_LANGUAGE_CODE = 'selected_language_code'; // DO NOT CHANGE
const SELECTED_LANGUAGE_COUNTRY_CODE = 'selected_language_country_code'; // DO NOT CHANGE
const IS_SELECTED_LANGUAGE_CHANGE = 'isSelectedLanguageChange';

Locale defaultLanguageLocale = Locale(defaultLanguageCode, defaultCountryCode);

// Locale setDefaultLocate() {
//   String getJsonData = sharedPref.getString(LanguageJsonDataRes) ?? "";
//   if (getJsonData.isNotEmpty) {
//     ServerLanguageResponse languageSettings =
//         ServerLanguageResponse.fromJson(json.decode(getJsonData.trim()));
//     if (languageSettings.data!.length > 0) {
//       defaultServerLanguageData = languageSettings.data;
//       performLanguageOperation(defaultServerLanguageData);
//     }
//   }
//   if (defaultServerLanguageData != null &&
//       defaultServerLanguageData!.length > 0) {
//     performLanguageOperation(defaultServerLanguageData);
//   }
//
//   return defaultLanguageLocale;
// }

Locale setDefaultLocate() {
  try {
    String getJsonData = sharedPref.getString(LanguageJsonDataRes) ?? "";

    if (getJsonData.isNotEmpty) {
      ServerLanguageResponse response = ServerLanguageResponse.fromJson(json.decode(getJsonData.trim()));

      if (response.data != null && response.data!.isNotEmpty) {
        defaultServerLanguageData = response.data;
        performLanguageOperation(defaultServerLanguageData);
      }
    }
  } catch (e) {
    debugPrint('Language parse error: $e');
  }

  // Always return a valid locale
  return const Locale('en');
}

performLanguageOperation(List<LanguageJsonData>? _defaultServerLanguageData) {
  String selectedLanguageCode = sharedPref.getString(SELECTED_LANGUAGE_CODE) ?? "";
  bool isFoundLocalSelectedLanguage = false;
  bool isFoundSelectedLanguageFromServer = false;

  for (int index = 0; index < _defaultServerLanguageData!.length; index++) {
    if (selectedLanguageCode.isNotEmpty) {
      if (_defaultServerLanguageData[index].languageCode == selectedLanguageCode) {
        isFoundLocalSelectedLanguage = true;
        defaultLanguageLocale = Locale(_defaultServerLanguageData[index].languageCode!, _defaultServerLanguageData[index].countryCode!);
        selectedServerLanguageData = _defaultServerLanguageData[index];
        break;
      }
    }
    if (_defaultServerLanguageData[index].isDefaultLanguage == 1) {
      isFoundSelectedLanguageFromServer = true;
      defaultLanguageLocale = Locale(_defaultServerLanguageData[index].languageCode!, _defaultServerLanguageData[index].countryCode!);
      selectedServerLanguageData = _defaultServerLanguageData[index];
    }
  }

  if (!isFoundLocalSelectedLanguage && !isFoundSelectedLanguageFromServer) {
    selectedServerLanguageData = null;
  }
}

// List<Locale> getSupportedLocales() {
//   print("get supported called");
//   List<Locale> list = [];
//   if (defaultServerLanguageData != null && defaultServerLanguageData!.length > 0) {
//     for (int index = 0; index < defaultServerLanguageData!.length; index++) {
//       list.add(Locale(defaultServerLanguageData![index].languageCode!, defaultServerLanguageData![index].countryCode!));
//     }
//   } else {
//     list.add(defaultLanguageLocale);
//   }
//   return list;
// }

List<Locale> getSupportedLocales() {
  final List<Locale> list = [];

  if (defaultServerLanguageData != null && defaultServerLanguageData!.isNotEmpty) {
    for (var lang in defaultServerLanguageData!) {
      if (lang.languageCode?.isNotEmpty == true) {
        list.add(
          lang.countryCode?.isNotEmpty == true ? Locale(lang.languageCode!) : Locale(lang.languageCode!),
        );
      }
    }
  }

  // ALWAYS ensure English fallback
  if (!list.any((l) => l.languageCode == 'en')) {
    list.add(const Locale('en'));
  }

  return list;
}

String getContentValueFromKey(int keywordId) {
  String defaultKeyValue = defaultKeyNotFoundValue;
  bool isFoundKey = false;
  if (selectedServerLanguageData != null) {
    for (int index = 0; index < selectedServerLanguageData!.contentData!.length; index++) {
      if (selectedServerLanguageData!.contentData![index].keywordId == keywordId) {
        defaultKeyValue = selectedServerLanguageData!.contentData![index].keywordValue!;
        isFoundKey = true;
        break;
      }
    }
  } else {
    for (int index = 0; index < defaultLanguageDataKeys.length; index++) {
      if (defaultLanguageDataKeys[index].keywordId == keywordId) {
        defaultKeyValue = defaultLanguageDataKeys[index].keywordValue!;
        isFoundKey = true;
        break;
      }
    }
  }
  if (!isFoundKey) {
    defaultKeyValue = defaultKeyValue + "($keywordId)";
  }
  return defaultKeyValue.toString().trim();
}

initJsonFile() async {
  final String jsonString = await rootBundle.loadString(languageJsonPath);
  final list = json.decode(jsonString) as List;
  List<LocalLanguageResponse> finalList = list.map((jsonElement) => LocalLanguageResponse.fromJson(jsonElement)).toList();
  defaultLanguageDataKeys.clear();
  for (int index = 0; index < finalList.length; index++) {
    for (int i = 0; i < finalList[index].keywordData!.length; i++) {
      defaultLanguageDataKeys.add(ContentData(keywordId: finalList[index].keywordData![i].keywordId, keywordName: finalList[index].keywordData![i].keywordName, keywordValue: finalList[index].keywordData![i].keywordValue));
    }
  }
}

// DO NOT CHANGE

String getCountryCode() {
  String defaultCode = defaultCountry;
  String selectedLang = sharedPref.getString(SELECTED_LANGUAGE_CODE) ?? defaultLanguageCode;
  if (defaultServerLanguageData != null && defaultServerLanguageData!.length > 0) {
    for (int index = 0; index < defaultServerLanguageData!.length; index++) {
      if (selectedLang == defaultServerLanguageData![index].languageCode) {
        List<String> selectedCoutry = defaultServerLanguageData![index].countryCode!.split("-");
        if (selectedCoutry.length > 0) {
          defaultCode = selectedCoutry[1];
        }
      }
    }
  }

  return defaultCode;
}
