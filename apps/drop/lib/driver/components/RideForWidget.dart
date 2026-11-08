import 'package:flutter/material.dart';
import 'package:drop/driver/utils/Extensions/dataTypeExtensions.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../utils/Common.dart';
import '../utils/Extensions/app_common.dart';

class Rideforwidget extends StatelessWidget {
  final String name, contact;

  Rideforwidget({super.key, required this.name, required this.contact});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${language.ridingPerson}',
                    style: secondaryTextStyle(size: 14)),
                Text('${name.validate().capitalizeFirstLetter()}',
                    style: boldTextStyle()),
              ],
            ),
          ),
          inkWellWidget(
            onTap: () {
              launchUrl(Uri.parse('tel:${contact}'),
                  mode: LaunchMode.externalApplication);
            },
            child: chatCallWidget(Icons.call),
          ),
        ],
      ),
    );
  }
}
