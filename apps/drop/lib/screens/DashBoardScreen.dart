import 'package:flutter/material.dart';

import 'PassengerHomeScreen.dart';

/// Passenger home. Kept under its old name so every place that opens the dashboard still works;
/// the screen itself is now [PassengerHomeScreen], built on the DROP rides API.
class DashBoardScreen extends StatelessWidget {
  final String? cancelReason;

  const DashBoardScreen({Key? key, this.cancelReason}) : super(key: key);

  @override
  Widget build(BuildContext context) => PassengerHomeScreen(cancelReason: cancelReason);
}
