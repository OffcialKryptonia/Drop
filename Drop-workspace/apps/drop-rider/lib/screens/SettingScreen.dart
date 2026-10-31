import '../manage_imports.dart';

class SettingScreen extends StatefulWidget {
  @override
  SettingScreenState createState() => SettingScreenState();
}

class SettingScreenState extends State<SettingScreen> {
  SettingModel settingModel = SettingModel();
  String? privacyPolicy;
  String? termsCondition;

  @override
  void initState() {
    super.initState();
    init();
  }

  void init() async {
    LiveStream().on(CHANGE_LANGUAGE, (p0) {
      setState(() {});
    });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(language.settings,
            style: boldTextStyle(color: appTextPrimaryColorWhite)),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: 16, top: 16),
        child: Column(
          children: [
            Visibility(
              visible: sharedPref.getString(LOGIN_TYPE) != 'mobile' &&
                  sharedPref.getString(LOGIN_TYPE) != LoginTypeGoogle &&
                  sharedPref.getString(LOGIN_TYPE) != null,
              child: settingItemWidget(
                  Ionicons.ios_lock_closed_outline, language.changePassword,
                  () {
                launchScreen(context, ChangePasswordScreen(),
                    pageRouteAnimation: PageRouteAnimation.Slide);
              }),
            ),
            settingItemWidget(Ionicons.language_outline, language.language, () {
              launchScreen(context, LanguageScreen(),
                  pageRouteAnimation: PageRouteAnimation.Slide);
            }),
            if (appStore.privacyPolicy != null)
              settingItemWidget(
                  Ionicons.ios_document_outline, language.privacyPolicy, () {
                launchScreen(
                    context,
                    TermsConditionScreen(
                        title: language.privacyPolicy,
                        subtitle: PRIVACY_URL),
                    pageRouteAnimation: PageRouteAnimation.Slide);
              }),
            if (appStore.mHelpAndSupport != null)
              settingItemWidget(Ionicons.help_outline, language.helpSupport,
                  () {
                if (appStore.mHelpAndSupport != null) {
                  launchUrl(Uri.parse(appStore.mHelpAndSupport!));
                } else {
                  toast(language.txtURLEmpty);
                }
              }),
            if (appStore.termsCondition != null)
              settingItemWidget(
                  Ionicons.document_outline, language.termsConditions, () {
                if (appStore.termsCondition != null) {
                  launchScreen(
                      context,
                      TermsConditionScreen(
                          title: language.termsConditions,
                          subtitle: TNC_URL),
                      pageRouteAnimation: PageRouteAnimation.Slide);
                } else {
                  toast(language.txtURLEmpty);
                }
              }),
            settingItemWidget(
              Ionicons.information,
              language.aboutUs,
              () {
                launchScreen(
                    context, AboutScreen(settingModel: appStore.settingModel),
                    pageRouteAnimation: PageRouteAnimation.Slide);
              },
            ),
            settingItemWidget(
                Ionicons.ios_trash_outline,
                color: Colors.red,
                language.deleteAccount, () {
              launchScreen(context, DeleteAccountScreen(),
                  pageRouteAnimation: PageRouteAnimation.Slide);
            }, isLast: true),
          ],
        ),
      ),
    );
  }

  Widget settingItemWidget(IconData icon, String title, Function() onTap,
      {bool isLast = false, Widget? suffixIcon, Color? color}) {
    return inkWellWidget(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(left: 16, right: 16, bottom: 12, top: 8),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                  border:
                      Border.all(color: color != null ? color : dividerColor),
                  borderRadius: radius(defaultRadius)),
              child: Icon(icon,
                  size: 20, color: color != null ? color : primaryColor),
            ),
            SizedBox(width: 12),
            Expanded(
                child: Text(title,
                    style:
                        primaryTextStyle(color: color != null ? color : null))),
            suffixIcon != null
                ? suffixIcon
                : Icon(Icons.navigate_next,
                    color: color != null ? color : dividerColor),
          ],
        ),
      ),
    );
  }
}
