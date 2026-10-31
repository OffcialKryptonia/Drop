import '../manage_imports.dart';

class CouPonWidget extends StatefulWidget {
  final int? servicesId;

  CouPonWidget(this.servicesId, {Key? key}) : super(key: key);
  @override
  CouPonWidgetState createState() => CouPonWidgetState();
}

class CouPonWidgetState extends State<CouPonWidget> {
  ScrollController scrollController = ScrollController();

  List<CouponData> couponData = [];
  int currentPage = 1;
  int totalPage = 1;

  @override
  void initState() {
    super.initState();
    init();
    scrollController.addListener(() {
      if (scrollController.position.pixels ==
          scrollController.position.maxScrollExtent) {
        if (currentPage < totalPage) {
          appStore.setLoading(true);
          currentPage++;
          setState(() {});

          init();
        }
      }
    });
    afterBuildCreated(() => appStore.setLoading(true));
  }

  void init() async {
    await getCouponList(
      page: currentPage,
      serviceId: widget.servicesId!,
    ).then((value) {
      appStore.setLoading(false);
      currentPage = value.pagination!.currentPage!;
      totalPage = value.pagination!.totalPages!;
      if (currentPage == 1) {
        couponData.clear();
      }
      couponData.addAll(value.data!);
      setState(() {});
    }).catchError((error) {
      appStore.setLoading(false);
      log(error.toString());
    });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        return Stack(
          children: [
            Container(
              padding: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.only(
                      topLeft: radiusCircular(defaultRadius),
                      topRight: radiusCircular(defaultRadius))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: 12, right: 0, top: 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(language.availableOffers, style: boldTextStyle()),
                        IconButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: Icon(
                            Icons.close,
                            size: 20,
                          ),
                        )
                      ],
                    ),
                  ),
                  Divider(color: Colors.grey),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: EdgeInsets.zero,
                      itemCount: couponData.length,
                      itemBuilder: (_, index) {
                        CouponData data = couponData[index];
                        return Container(
                          decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black45,
                                    spreadRadius: 1,
                                    blurRadius: 1)
                              ],
                              borderRadius: BorderRadius.circular(14)),
                          margin:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Padding(
                            padding: EdgeInsets.only(
                                left: 8, right: 8, top: 8, bottom: 8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    DottedBorder(
                                      strokeCap: StrokeCap.butt,
                                      borderType: BorderType.Oval,
                                      strokeWidth: 2.5,
                                      padding: EdgeInsets.all(8),
                                      child: Text(data.code.validate(),
                                          style: boldTextStyle()),
                                      color:
                                          primaryColor.withValues(alpha: 0.3),
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                        child: Text(data.title.validate(),
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: boldTextStyle(size: 14))),
                                    MaterialButton(
                                        onPressed: () {
                                          String codeData = data.code!;
                                          Navigator.pop(context, codeData);
                                          toast(language.copied);
                                        },
                                        color: primaryColor,
                                        shape: BeveledRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(6)),
                                        child: Icon(Icons.content_copy,
                                            size: 18, color: Colors.white)),
                                  ],
                                ),
                                // SizedBox(height: 8),
                                Text(
                                    data.discountType == CHARGE_TYPE_FIXED
                                        ? '${language.get} ${data.discount}'
                                        : '${language.get} ${data.discount} % ${language.off}',
                                    style: primaryTextStyle(
                                        weight: FontWeight.w500)),
                                if (data.description != null)
                                  SizedBox(height: 8),
                                if (data.description != null)
                                  Text(
                                    data.description.validate(),
                                    style: secondaryTextStyle(),
                                    overflow: TextOverflow.visible,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                      separatorBuilder: (_, index) {
                        return SizedBox();
                      },
                    ),
                  )
                ],
              ),
            ),
            Visibility(
              visible: appStore.isLoading,
              child: loaderWidget(),
            ),
            if (!appStore.isLoading && couponData.isEmpty) emptyWidget()
          ],
        );
      },
    );
  }
}
