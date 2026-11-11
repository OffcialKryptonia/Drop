import 'package:flutter/material.dart';

import '../../manage_imports.dart';

/// What happens after DROP's own server accepts a login or sign-up: connect the chat/cloud
/// session (Firebase), grab the location, and open the app. Nothing here may block the user, so
/// every step is best-effort.
Future<void> dropFinishSignIn(BuildContext context, UserModel user, String password) async {
  final String username = user.username.validate();
  final String email = user.email.validate().isNotEmpty ? user.email.validate() : '$username@users.drop.ng';
  try {
    final FirebaseAuth auth = FirebaseAuth.instance;
    User? fbUser;
    try {
      fbUser = (await auth.signInWithEmailAndPassword(email: email, password: password)).user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'invalid-email') {
        fbUser = (await auth.createUserWithEmailAndPassword(email: email, password: password)).user;
        if (fbUser != null) {
          final UserModel doc = UserModel()
            ..uid = fbUser.uid
            ..email = email
            ..contactNumber = user.contactNumber.validate()
            ..username = username
            ..userType = RIDER
            ..displayName = user.displayName.validate()
            ..firstName = user.firstName.validate()
            ..lastName = user.lastName.validate()
            ..createdAt = DateTime.now().toString()
            ..updatedAt = DateTime.now().toString()
            ..playerId = sharedPref.getString(PLAYER_ID).validate();
          await userService.addDocumentWithCustomId(fbUser.uid, doc.toJson());
        }
      } else {
        rethrow;
      }
    }
    if (fbUser != null) {
      await sharedPref.setString(UID, fbUser.uid);
      await updateProfileUid();
    }
  } catch (e) {
    log('firebase session skipped: $e');
  }
  try {
    if (await checkPermission()) {
      final p = await Geolocator.getCurrentPosition();
      await sharedPref.setDouble(LATITUDE, p.latitude);
      await sharedPref.setDouble(LONGITUDE, p.longitude);
    }
  } catch (e) {
    log('location skipped: $e');
  }
  appStore.setLoading(false);
  if (context.mounted) {
    launchScreen(context, DashBoardScreen(), isNewTask: true, pageRouteAnimation: PageRouteAnimation.Slide);
  }
}
