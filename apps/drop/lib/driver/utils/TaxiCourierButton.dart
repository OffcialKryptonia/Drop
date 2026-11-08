import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:drop/driver/main.dart';

class TaxiCourierButton extends StatelessWidget {
  final String? ScheduleTime;

  TaxiCourierButton({
    Key? key,
    this.ScheduleTime,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final utcDateTime = DateTime.parse("${ScheduleTime}");

    final istDateTime =
        utcDateTime.toLocal().add(Duration(hours: 5, minutes: 30));
    final formattedDate = DateFormat('dd MMM yyyy').format(istDateTime);
    final formattedTime = DateFormat('hh:mm a').format(istDateTime);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.black38,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            offset: Offset(2, 2),
            blurRadius: 5,
          ),
        ],
      ),
      padding: EdgeInsets.all(4),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 5, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.yellow[600],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "${language.schedule_at}: ${formattedDate} ${formattedTime}",
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
