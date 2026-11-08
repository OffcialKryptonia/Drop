import '../manage_imports.dart';


class WalkThroughScreen extends StatefulWidget {
  @override
  WalkThroughScreenState createState() => WalkThroughScreenState();
}

class WalkThroughScreenState extends State<WalkThroughScreen> {
  PageController pageController = PageController();
  int currentPage = 0;

  List<WalkThroughModel> walkThroughClass = [
    WalkThroughModel(
        name: language.walkthrough_title_1,
        text: language.walkthrough_subtitle_1,
        img: ic_walk1),
    WalkThroughModel(
        name: language.walkthrough_title_2,
        text: language.walkthrough_subtitle_2,
        img: ic_walk2),
    WalkThroughModel(
        name: language.walkthrough_title_3,
        text: language.walkthrough_subtitle_3,
        img: ic_walk3)
  ];

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        toolbarHeight: 0,
      ),
      body: Stack(
        children: [
          PageView.builder(
            itemCount: walkThroughClass.length,
            controller: pageController,
            itemBuilder: (context, i) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    walkThroughClass[i].img.toString(),
                    fit: BoxFit.cover,
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height,
                  ),
                ],
              );
            },
            onPageChanged: (int i) {
              currentPage = i;
              setState(() {});
            },
          ),
          Positioned(
            bottom: 10,
            right: 0,
            left: 0,
            child: Column(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(walkThroughClass[currentPage].name!,
                        style: boldTextStyle(size: 32, color: Colors.white),
                        textAlign: TextAlign.center),
                    SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(walkThroughClass[currentPage].text.toString(),
                          style:
                              secondaryTextStyle(size: 14, color: Colors.white),
                          textAlign: TextAlign.center),
                    ),
                  ],
                ),
                SizedBox(height: 32),
                dotIndicator(walkThroughClass, currentPage),
                SizedBox(height: 28),
                GestureDetector(
                  onTap: () {
                    if (currentPage.toInt() >= 2) {
                      launchScreen(context, SignInScreen(), isNewTask: true);
                      sharedPref.setBool(IS_FIRST_TIME, false);
                    } else {
                      pageController.nextPage(
                          duration: Duration(seconds: 1),
                          curve: Curves.linearToEaseOut);
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: primaryColor),
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.arrow_forward, color: Colors.white),
                  ),
                ),
                SizedBox(height: 28),
              ],
            ),
          ),
          Positioned(
            top: 30,
            right: 0,
            child: TextButton(
              onPressed: () {
                launchScreen(context, SignInScreen(), isNewTask: true);
                sharedPref.setBool(IS_FIRST_TIME, false);
              },
              child: Text(language.skip,
                  style: boldTextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
