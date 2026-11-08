import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:intl/intl.dart';
import 'package:drop/driver/utils/Extensions/context_extensions.dart';
import '../main.dart';
import '../network/RestApis.dart';
import '../utils/Colors.dart';
import '../utils/Common.dart';
import '../utils/Extensions/app_common.dart';
import '../model/ReviewsModel.dart';

class ReviewsListScreen extends StatefulWidget {
  @override
  ReviewsListScreenState createState() => ReviewsListScreenState();
}

class ReviewsListScreenState extends State<ReviewsListScreen> with TickerProviderStateMixin {
  ScrollController scrollController = ScrollController();
  int currentPage = 1;

  bool mIsLastPage = false;
  List<ReviewsList> reviewList = [];

  @override
  void initState() {
    super.initState();
    init();
    scrollController.addListener(() {
      if (scrollController.position.pixels == scrollController.position.maxScrollExtent) {
        if (!mIsLastPage) {
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
    getReviewList(page: currentPage).then((value) {
      appStore.setLoading(false);
      mIsLastPage = value.data.length < currentPage;
      if (currentPage == 1) {
        reviewList.clear();
      }
      reviewList.addAll(value.data);
      setState(() {});
    }).catchError((error) {
      appStore.setLoading(false);
      log(error);
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
        title: Text(language.reviews, style: boldTextStyle(color: Colors.white)),
      ),
      body: Observer(builder: (context) {
        return Stack(
          children: [
            if (reviewList.isNotEmpty)
              ListView.separated(
                controller: scrollController,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                itemCount: reviewList.length,
                itemBuilder: (_, index) {
                  ReviewsList data = reviewList[index];

                  final rider = data.rider;
                  final rideRequest = data.rideRequest;
                  final int rating = data.rating;
                  final String? comment = data.comment;
                  final String? createdAt = data.createdAt.toString();

                  return Container(
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.directions_car_rounded, size: 15, color: primaryColor),
                                  SizedBox(width: 6),
                                  Text(
                                    '${language.rideId} #${rideRequest.id}',
                                    style: boldTextStyle(size: 12, color: primaryColor),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Icon(Icons.access_time_rounded, size: 13, color: Colors.grey.shade500),
                                  SizedBox(width: 4),
                                  Text(
                                    createdAt != null ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(createdAt).toLocal()) : '',
                                    style: secondaryTextStyle(size: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 28,
                                        backgroundColor: primaryColor.withValues(alpha: 0.1),
                                        backgroundImage: rider.profileImage.isNotEmpty ? NetworkImage(rider.profileImage) : null,
                                        child: rider.profileImage.isEmpty ? Icon(Icons.person_rounded, color: primaryColor, size: 26) : null,
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            color: rating > 0 ? Color(0xFFFFC107) : Colors.grey.shade400,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: context.cardColor, width: 1.5),
                                          ),
                                          child: Icon(Icons.star_rounded, size: 10, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        RichText(
                                          text: TextSpan(
                                            children: [
                                              TextSpan(
                                                text: rider.displayName,
                                                style: boldTextStyle(size: 14),
                                              ),
                                              TextSpan(
                                                text: ' ${language.ratedYou}',
                                                style: secondaryTextStyle(size: 13),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(height: 6),
                                        Row(
                                          children: [
                                            _buildStarRating(rating),
                                            SizedBox(width: 8),
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: rating > 0 ? Color(0xFFFFF8E1) : Colors.grey.shade100,
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                rating > 0 ? '$rating / 5' : '${language.noRating}',
                                                style: boldTextStyle(
                                                  size: 11,
                                                  color: rating > 0 ? Color(0xFFF59E0B) : Colors.grey.shade500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (comment != null && comment.isNotEmpty) ...[
                                SizedBox(height: 12),
                                IntrinsicHeight(
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 3.5,
                                        decoration: BoxDecoration(
                                          color: primaryColor,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(Icons.chat_bubble_outline_rounded, size: 12, color: primaryColor),
                                                SizedBox(width: 4),
                                                Text(language.comment, style: boldTextStyle(size: 11, color: primaryColor)),
                                              ],
                                            ),
                                            SizedBox(height: 3),
                                            Text(
                                              comment,
                                              style: secondaryTextStyle(size: 13),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
                separatorBuilder: (_, __) => SizedBox(height: 14),
              )
            else
              !appStore.isLoading ? emptyWidget() : SizedBox(),
            Visibility(visible: appStore.isLoading, child: loaderWidget()),
          ],
        );
      }),
    );
  }

  Widget _buildStarRating(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star_rounded : Icons.star_outline_rounded,
          color: index < rating ? Color(0xFFFFC107) : Colors.grey.shade300,
          size: 18,
        );
      }),
    );
  }
}
