import 'package:flutter/material.dart';
import 'package:mighty_core/core_mighty/mighty_core.dart';
import 'package:drop/driver/utils/Extensions/core_language_parser.dart';
import 'package:drop/driver/utils/Extensions/dataTypeExtensions.dart';

import '../../main.dart';
import '../languageConfiguration/LanguageDataConstant.dart';
import '../languageConfiguration/LanguageDefaultJson.dart';
import '../languageConfiguration/ServerLanguageResponse.dart';
import '../utils/Colors.dart';
import '../utils/Common.dart';
import '../utils/Constants.dart';
import '../utils/Extensions/LiveStream.dart';
import '../utils/Extensions/app_common.dart';

class LanguageScreen extends StatefulWidget {
  @override
  LanguageScreenState createState() => LanguageScreenState();
}

class LanguageScreenState extends State<LanguageScreen> {
  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(language.language, style: boldTextStyle(color: appTextPrimaryColorWhite)),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Wrap(
          runSpacing: 12,
          spacing: 12,
          children: List.generate(defaultServerLanguageData!.length, (index) {
            LanguageJsonData data = defaultServerLanguageData![index];
            print("data.languageCode ${data.languageCode}");
            return inkWellWidget(
              onTap: () async {
                setValue(SELECTED_LANGUAGE_CODE, data.languageCode);
                setValue(SELECTED_LANGUAGE_COUNTRY_CODE, data.countryCode);
                selectedServerLanguageData = data;
                setValue(IS_SELECTED_LANGUAGE_CHANGE, true);
                appStore.setLanguage(data.languageCode!, context: context);
                setState(() {});
                LiveStream().emit(CHANGE_LANGUAGE);
                final langEnum = CoreLanguageParser.fromCode(data.languageCode!);
                MightyCore().updateLanguageConfiguration(
                  defaultLanguage: langEnum,
                );
              },
              child: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(color: (sharedPref.getString(SELECTED_LANGUAGE_CODE) ?? defaultLanguageCode) == data.languageCode ? primaryColor.withValues(alpha: 0.6) : Colors.transparent, border: Border.all(width: 0.4, color: textSecondaryColorGlobal), borderRadius: radius()),
                width: (MediaQuery.of(context).size.width - 44) / 2,
                child: Row(
                  children: [
                    ClipRRect(borderRadius: BorderRadius.circular(4), child: commonCachedNetworkImage(data.languageImage.validate(), width: 34, height: 34)),
                    SizedBox(
                      width: 8,
                    ),
                    Expanded(child: Text('${data.languageName.validate()}', style: primaryTextStyle())),
                    sharedPref.getString(SELECTED_LANGUAGE_CODE).validateLanguage() == data.languageCode ? Icon(Icons.radio_button_checked, size: 20, color: primaryColor) : Icon(Icons.radio_button_off, size: 20, color: dividerColor),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
