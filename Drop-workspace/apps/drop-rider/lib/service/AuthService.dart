import 'package:http/http.dart' as http;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../manage_imports.dart';

final FirebaseAuth _auth = FirebaseAuth.instance;

class AuthServices {
  Future<User?> createAuthUser(String? email, String? password, bool isOtpLogin) async {
    User? userCredential;
    try {
      if (!isOtpLogin) {
        await _auth.createUserWithEmailAndPassword(email: email!, password: password!).then((value) {
          userCredential = value.user!;
        });
      } else {
        userCredential = _auth.currentUser;
      }
    } on FirebaseException catch (error) {
      if (error.code == "ERROR_EMAIL_ALREADY_IN_USE" || error.code == "account-exists-with-different-credential" || error.code == "email-already-in-use") {
        await _auth.signInWithEmailAndPassword(email: email!, password: password!).then((value) {
          userCredential = value.user!;
        });
      } else {
        toast(getMessageFromErrorCode(error));
      }
    }
    return userCredential;
  }

  Future<void> signUpWithEmailPassword(
    context, {
    String? email,
    String? password,
    String? mobileNumber,
    String? fName,
    String? lName,
    String? userName,
    String? userType,
    bool isOtpLogin = false,
  }) async {
    try {
      createAuthUser(email, password, isOtpLogin).then((user) async {
        if (user != null) {
          User currentUser = user;

          UserModel userModel = UserModel();

          /// Create user
          userModel.uid = currentUser.uid.validate();
          userModel.email = email;
          userModel.contactNumber = mobileNumber.validate();
          userModel.username = userName.validate();
          userModel.userType = userType.validate();
          userModel.displayName = fName.validate() + " " + lName.validate();
          userModel.firstName = fName.validate();
          userModel.lastName = lName.validate();
          userModel.createdAt = Timestamp.now().toDate().toString();
          userModel.updatedAt = Timestamp.now().toDate().toString();
          userModel.playerId = sharedPref.getString(PLAYER_ID).validate();
          sharedPref.setString(UID, user.uid.validate());

          await userService.addDocumentWithCustomId(currentUser.uid, userModel.toJson()).then((value) async {
            Map request = {
              "email": userModel.email,
              "password": password,
              "player_id": sharedPref.getString(PLAYER_ID).validate(),
              'user_type': RIDER,
            };
            if (isOtpLogin) {
              appStore.setLoading(false);
              updateProfileUid();
              launchScreen(context, DashBoardScreen(), isNewTask: true, pageRouteAnimation: PageRouteAnimation.Slide);
            } else {
              await logInApi(request).then((res) async {
                appStore.setLoading(false);
                updateProfileUid();
                launchScreen(context, DashBoardScreen(), isNewTask: true, pageRouteAnimation: PageRouteAnimation.Slide);
              }).catchError((e) {
                appStore.setLoading(false);
                log(e.toString());
                toast(e.toString());
              });
            }
          });
        } else {
          appStore.setLoading(false);
          throw 'Something went wrong';
        }
      });
    } on FirebaseException catch (error) {
      appStore.setLoading(false);
      toast(getMessageFromErrorCode(error));
    }
  }

  Future<void> loginFromFirebaseUser(User currentUser, {LoginResponse? loginDetail, String? fullName}) async {
    UserModel userModel = UserModel();
    if (await userService.isUserExist(loginDetail!.data!.email)) {
      ///Return user data
      await userService.userByEmail(loginDetail.data!.email).then((user) async {
        userModel = user;
        appStore.setUserEmail(userModel.email.validate());
        appStore.setUId(userModel.uid.validate());

        // await updateUserData(user);
      }).catchError((e) {
        log(e);
        throw e;
      });
    } else {
      /// Create user
      userModel.uid = currentUser.uid.validate();
      userModel.id = loginDetail.data!.id;
      userModel.email = loginDetail.data!.email.validate();
      userModel.username = loginDetail.data!.username.validate();
      userModel.contactNumber = loginDetail.data!.contactNumber.validate();
      userModel.username = loginDetail.data!.username.validate();
      userModel.email = loginDetail.data!.email.validate();

      if (Platform.isIOS) {
        userModel.username = fullName;
      } else {
        userModel.username = loginDetail.data!.username.validate();
      }

      userModel.contactNumber = loginDetail.data!.contactNumber.validate();
      userModel.profileImage = loginDetail.data!.profileImage.validate();
      userModel.playerId = sharedPref.getString(PLAYER_ID);

      sharedPref.setString(UID, currentUser.uid.validate());
      log(sharedPref.getString(UID));
      sharedPref.setString(USER_EMAIL, userModel.email.validate());
      sharedPref.setBool(IS_LOGGED_IN, true);

      log(userModel.toJson());

      await userService.addDocumentWithCustomId(currentUser.uid, userModel.toJson()).then((value) {
        //
      }).catchError((e) {
        throw e;
      });
    }
  }

  Future<void> loginWithOTP(BuildContext context, String phoneNumber) async {
    appStore.setLoading(true);
    return await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        appStore.setLoading(false);
      },
      verificationFailed: (FirebaseAuthException e) {
        if (e.code == 'invalid-phone-number') {
          toast('The provided phone number is not valid.');
          throw 'The provided phone number is not valid.';
        } else {
          log('**************${e.toString()}');
          appStore.setLoading(false);
          toast(e.toString());
          throw e.toString();
        }
      },
      codeSent: (String verificationId, int? resendToken) async {
        Navigator.pop(context);
        appStore.setLoading(false);
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(content: OTPDialog(verificationId: verificationId, isCodeSent: true, phoneNumber: phoneNumber)),
          barrierDismissible: false,
        );
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        appStore.setLoading(false);
      },
    );
  }

  Future deleteUserFirebase() async {
    if (FirebaseAuth.instance.currentUser != null) {
      FirebaseAuth.instance.currentUser!.delete();
      await FirebaseAuth.instance.signOut();
    }
  }

// Future<void> updateUserData(UserModel user) async {
//   userService.updateDocument({
//     'player_id': sharedPref.getString(PLAYER_ID),
//     'updatedAt': Timestamp.now(),
//   }, user.uid);
// }
// Future<void> signInWithEmailPassword(context, {required String email, required String password}) async {
//   await _auth.signInWithEmailAndPassword(email: email, password: password).then((value) async {
//     appStore.setLoading(true);
//     final User user = value.user!;
//     UserModel userModel = await userService.getUser(email: user.email);
//     //await updateUserData(userModel);
//
//     appStore.setLoading(true);
//     //Login Details to SharedPreferences
//     sharedPref.setString(UID, userModel.uid.validate());
//     sharedPref.setString(USER_EMAIL, userModel.email.validate());
//     sharedPref.setBool(IS_LOGGED_IN, true);
//
//     //Login Details to AppStore
//     appStore.setUserEmail(userModel.email.validate());
//     appStore.setUId(userModel.uid.validate());
//
//     //
//   }).catchError((e) {
//     toast(e.toString());
//     log(e.toString());
//   });
// }
}

class GoogleAuthServices {
  final GoogleSignIn googleSignIn = GoogleSignIn(scopes: [
    'email',
  ]);

  Future<void> signInWithGoogle(BuildContext context) async {
    try {
      GoogleSignInAccount? googleSignInAccount = await googleSignIn.signIn();
      if (googleSignInAccount != null) {
        //Authentication
        final GoogleSignInAuthentication googleSignInAuthentication = await googleSignInAccount.authentication;

        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleSignInAuthentication.accessToken,
          idToken: googleSignInAuthentication.idToken,
        );

        final UserCredential authResult = await _auth.signInWithCredential(credential);
        final User user = authResult.user!;

        assert(!user.isAnonymous);

        final User currentUser = _auth.currentUser!;
        assert(user.uid == currentUser.uid);

        googleSignIn.signOut();

        await loginFromFirebase(user, LoginTypeGoogle, googleSignInAuthentication.accessToken, '', false, context);
      } else {
        throw errorSomethingWentWrong;
      }
    } catch (e) {
      throw e;
    }
  }
}

/// Sign-In with Apple.

// Future<void> appleLogIn() async {
//   if (await TheAppleSignIn.isAvailable()) {
//     AuthorizationResult result = await TheAppleSignIn.performRequests([
//       AppleIdRequest(requestedScopes: [Scope.email, Scope.fullName])
//     ]);
//     switch (result.status) {
//       case AuthorizationStatus.authorized:
//         final appleIdCredential = result.credential!;
//         final oAuthProvider = OAuthProvider('apple.com');
//         final credential = oAuthProvider.credential(
//           idToken: String.fromCharCodes(appleIdCredential.identityToken!),
//           accessToken: String.fromCharCodes(appleIdCredential.authorizationCode!),
//         );
//         final authResult = await _auth.signInWithCredential(credential);
//         final user = authResult.user!;
//
//         if (result.credential!.email != null) {
//           await saveAppleData(result);
//         }
//
//         await loginFromFirebase(user, LoginTypeApple, String.fromCharCodes(appleIdCredential.authorizationCode!));
//         break;
//       case AuthorizationStatus.error:
//         throw ("Sign in failed: ${result.error!.localizedDescription}");
//       case AuthorizationStatus.cancelled:
//         throw ('User cancelled');
//     }
//   } else {
//     throw ('Apple SignIn is not available for your device');
//   }
// }
//
// Future<void> saveAppleData(AuthorizationResult result) async {
//   await sharedPref.setString('appleEmail', result.credential!.email.validate());
//   await sharedPref.setString('appleGivenName', result.credential!.fullName!.givenName.validate());
//   await sharedPref.setString('appleFamilyName', result.credential!.fullName!.familyName.validate());
// }

// Future deleteUser(String email, String password) async {
//   if (FirebaseAuth.instance.currentUser != null) {
//     FirebaseAuth.instance.currentUser!.delete();
//     await FirebaseAuth.instance.signOut();
//   }
// }

Future<UserCredential?> appleLogIn(BuildContext context) async {
  try {
    final rawNonce = generateNonceData();
    final nonce = sha256ofString(rawNonce);

    final appleCred = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    final oauthCredential = OAuthProvider("apple.com").credential(
      idToken: appleCred.identityToken,
      rawNonce: rawNonce,
      accessToken: appleCred.authorizationCode,
    );

    final result = await FirebaseAuth.instance.signInWithCredential(oauthCredential);

    debugPrint("APPLE EMAIL: ${appleCred.email}");
    debugPrint("APPLE USER ID: ${appleCred.userIdentifier}");
    debugPrint("APPLE USER fname: ${appleCred.givenName}");

    if (sharedPref.getString('appleGivenName').isEmptyOrNull) {
      await setValue('appleGivenName', appleCred.givenName);
    }

    // FIRST TIME → Apple gives email
    if (!appleCred.email.isEmptyOrNull && !appleCred.givenName.isEmptyOrNull) {
      await saveAppleData(result, context, appleCred: appleCred);
      return result;
    } else if (appleCred.email.isEmptyOrNull && !sharedPref.getString('appleGivenName').isEmptyOrNull && sharedPref.getString('appleEmail').isEmptyOrNull) {
      askUserForEmail(context, result, appleCred);
    } else if (appleCred.email.isEmptyOrNull && appleCred.givenName.isEmptyOrNull) {
      loginFromFirebase(result.user!, LoginTypeApple, appleCred.authorizationCode, appleCred.userIdentifier, false, context);
    }
  } catch (e) {
    debugPrint("Apple Login Error: $e");
    rethrow;
  }
}

// Future<String?> askUserForEmail(
//   BuildContext contexts,
//   UserCredential result,
//   AuthorizationCredentialAppleID appleCred,
// ) async {
//   final controller = TextEditingController();
//   GlobalKey<FormState> formKey = GlobalKey<FormState>();
//
//   return await showDialog<String>(
//     context: contexts,
//     barrierDismissible: false,
//     builder: (context) {
//       return AlertDialog(
//         backgroundColor: Colors.white,
//         title: Text("Email Required"),
//         content: Form(
//           key: formKey,
//           child: AppTextField(
//             controller: controller,
//             autoFocus: false,
//             textFieldType: TextFieldType.EMAIL,
//             keyboardType: TextInputType.emailAddress,
//             errorThisFieldRequired: language.thisFieldRequired,
//             decoration: inputDecoration(context, label: language.email),
//           ),
//         ),
//         actions: [
//           TextButton(
//             style: TextButton.styleFrom(
//               textStyle: const TextStyle(color: Colors.black),
//             ),
//             onPressed: () {
//               Navigator.pop(contexts, null);
//             },
//             child: Text("Cancel"),
//           ),
//           TextButton(
//             style: TextButton.styleFrom(
//               textStyle: const TextStyle(color: Colors.black),
//             ),
//             onPressed: () async {
//               // Navigator.pop(context, controller.text.trim());
//               if (formKey.currentState!.validate()) {
//                 formKey.currentState!.save();
//                 FocusScope.of(context).unfocus();
//                 await saveAppleDataManualEmail(result, controller.text.trim(), appleCred, contexts);
//               }
//             },
//             child: Text("Continue"),
//           ),
//         ],
//       );
//     },
//   );
// }

Future<String?> askUserForEmail(
  BuildContext contexts,
  UserCredential result,
  AuthorizationCredentialAppleID appleCred,
) async {
  final controller = TextEditingController();
  GlobalKey<FormState> formKey = GlobalKey<FormState>();

  return await showDialog<String>(
    context: contexts,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mail_outline_rounded,
                  size: 32,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 20),
              Text(
                "Email Required",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 24),
              Form(
                key: formKey,
                child: AppTextField(
                  controller: controller,
                  autoFocus: false,
                  textFieldType: TextFieldType.EMAIL,
                  keyboardType: TextInputType.emailAddress,
                  errorThisFieldRequired: language.thisFieldRequired,
                  suffix: Icon(Icons.mail_outline_rounded),
                  decoration: inputDecoration(context, label: language.email),
                ),
              ),
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(contexts, null);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        language.cancel,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (formKey.currentState!.validate()) {
                          formKey.currentState!.save();
                          FocusScope.of(context).unfocus();
                          await saveAppleDataManualEmail(result, controller.text.trim(), appleCred, contexts);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Colors.black,
                        elevation: 0,
                      ),
                      child: Text(
                        language.continueD,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> saveAppleDataManualEmail(
  UserCredential result,
  String email,
  AuthorizationCredentialAppleID appleCred,
  BuildContext context,
) async {
  await setValue('appleEmail', email);
  await setValue('appleUserId', appleCred.userIdentifier);
  if (sharedPref.getString('appleGivenName').isEmptyOrNull) {
    await setValue('appleGivenName', appleCred.givenName ?? "");
  }
  await setValue('appleFamilyName', appleCred.familyName ?? "");

  loginFromFirebase(result.user!, LoginTypeApple, appleCred.authorizationCode, appleCred.userIdentifier, true, context);
}

Future<void> saveAppleData(
  UserCredential result,
  BuildContext context, {
  required AuthorizationCredentialAppleID appleCred,
}) async {
  final email = appleCred.email!;
  final firstName = appleCred.givenName ?? '';
  final lastName = appleCred.familyName ?? '';

  // STORE VALUES FOR FUTURE LOGINS
  await setValue('appleEmail', email);
  await setValue('appleGivenName', firstName);
  await setValue('appleFamilyName', lastName);
  await setValue('appleUserId', appleCred.userIdentifier);

  loginFromFirebase(result.user!, LoginTypeApple, appleCred.authorizationCode, appleCred.userIdentifier, false, context);
}

Future<void> loginFromFirebase(User currentUser, String loginType, String? accessToken, String? userIdentifier, bool isFromPopup, BuildContext context) async {
  String firstName = '';
  String lastName = '';
  if (loginType == LoginTypeGoogle) {
    if (currentUser.displayName != null && currentUser.displayName!.trim().isNotEmpty) {
      String displayName = currentUser.displayName!.trim();
      List<String> nameParts = displayName.split(' ');

      if (nameParts.length == 1) {
        firstName = nameParts[0];
        lastName = '';
      } else if (nameParts.length >= 2) {
        firstName = nameParts.first;
        lastName = nameParts.sublist(1).join(' ');
      }
    } else {
      firstName = "Rider";
      lastName = "Anonymous";
    }
  } else {
    firstName = sharedPref.getString('appleGivenName').validate();
    lastName = sharedPref.getString('appleFamilyName').validate();
  }
  Map req = {
    "email": loginType == LoginTypeApple ? sharedPref.getString('appleEmail').validate() : currentUser.email,
    "login_type": loginType,
    "user_type": RIDER,
    "first_name": firstName,
    "last_name": lastName,
    "username": loginType == LoginTypeApple ? sharedPref.getString('appleEmail').validate() : currentUser.email,
    "uid": currentUser.uid,
    'accessToken': accessToken,
    "player_id": sharedPref.getString(PLAYER_ID).validate(),
    if (loginType == LoginTypeApple) 'apple_user_identifier': userIdentifier,
    if (!currentUser.phoneNumber.isEmptyOrNull) 'contact_number': currentUser.phoneNumber.validate(),
  };

  await logInApi(req, isSocialLogin: true).then((value) async {
    if (value.status != null && value.status!) {
      if (isFromPopup) {
        Navigator.pop(context);
      }
      AuthServices authService = AuthServices();
      authService.loginFromFirebaseUser(currentUser, loginDetail: value, fullName: (firstName + lastName).toLowerCase()).then((value) {});
      Navigator.pop(getContext);
      sharedPref.setString(UID, currentUser.uid);
      await appStore.setUserProfile(currentUser.photoURL.toString());
      await sharedPref.setString(USER_PROFILE_PHOTO, currentUser.photoURL.toString());
      if (value.data!.contactNumber.isEmptyOrNull) {
        launchScreen(getContext, EditProfileScreen(isGoogle: true), isNewTask: true, pageRouteAnimation: PageRouteAnimation.Slide);
      } else {
        if (value.data!.uid.isEmptyOrNull) {
          File? imgFile;
          try {
            Directory tempDir = await getTemporaryDirectory();
            String filePath = '${tempDir.path}/downloaded_image.jpg';
            var response = await http.get(Uri.parse(currentUser.photoURL.toString()));
            if (response.statusCode == 200) {
              imgFile = File(filePath);
              await imgFile.writeAsBytes(response.bodyBytes);
              return imgFile;
            } else {
              imgFile = null;
            }
          } catch (e) {
            imgFile = null;
          }
          await updateProfile(
            uid: sharedPref.getString(UID).toString(),
            userEmail: currentUser.email.validate(),
            file: imgFile != null ? imgFile : null,
          ).then((value) {
            launchScreen(getContext, DashBoardScreen(), isNewTask: true, pageRouteAnimation: PageRouteAnimation.Slide);
          }).catchError((error) {
            log(error.toString());
          });
        } else if (value.data!.playerId.isEmptyOrNull) {
          await updatePlayerId().then((value) {
            launchScreen(getContext, DashBoardScreen(), isNewTask: true, pageRouteAnimation: PageRouteAnimation.Slide);
          }).catchError((error) {
            log(error.toString());
          });
        } else {
          launchScreen(getContext, DashBoardScreen(), isNewTask: true, pageRouteAnimation: PageRouteAnimation.Slide);
        }
      }
    } else {
      toast(value.message);
      if (isFromPopup) {
        sharedPref.remove("appleEmail");
      }
    }
  }).catchError((e) {
    if (isFromPopup) {
      sharedPref.remove("appleEmail");
    }
    toast(e.toString());
    log(e.toString());
    throw e;
  });
}

// Future<bool> updateUserPassword(String newPassword) async {
//   try {
//     User? currentUser = _auth.currentUser;
//     print("change ps");
//     if (currentUser != null) {
//       await currentUser.updatePassword(newPassword);
//       print("change ps2 ${newPassword}");
//       return true;
//     } else {
//       return false;
//     }
//   } on FirebaseException catch (error) {
//     if (error.code == 'requires-recent-login') {
//       toast("Please re-authenticate to update your password");
//     } else {
//       toast(getMessageFromErrorCode(error));
//     }
//     return false;
//   } catch (e) {
//     return false;
//   }
// }

Future<bool> updateUserPassword(String oldPassword, String newPassword) async {
  try {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    print("Attempting to update Firebase password...");

    await currentUser.updatePassword(newPassword);
    print("Password updated successfully in Firebase");
    return true;
  } on FirebaseAuthException catch (error) {
    if (error.code == 'requires-recent-login') {
      print("Re-authentication required...");

      try {
        final credential = EmailAuthProvider.credential(
          email: sharedPref.getString(USER_EMAIL) ?? "",
          password: oldPassword,
        );

        await _auth.currentUser!.reauthenticateWithCredential(credential);
        print("Re-authentication successful, retrying password update...");

        await _auth.currentUser!.updatePassword(newPassword);
        print("Password updated successfully after reauth");
        return true;
      } catch (reauthError) {
        print("Re-authentication failed: $reauthError");
        toast("Please login again to change your password");
        return false;
      }
    } else {
      toast(getMessageFromErrorCode(error));
      return false;
    }
  } catch (e) {
    print("Unexpected error while changing password: $e");
    return false;
  }
}
