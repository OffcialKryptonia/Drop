import '../manage_imports.dart';

class NotificationService {
  Future<void> sendPushNotifications(String title, String content,
      {String? id, String? image, String? receiverPlayerId}) async {
    log('####$receiverPlayerId!');
    Map req = {
      'headings': {
        'en': title,
      },
      'contents': {
        'en': content,
      },
      'data': {
        'id': 'CHAT_${sharedPref.getInt(USER_ID)}',
      },
      'big_picture': image.validate().isNotEmpty ? image.validate() : '',
      'large_icon': image.validate().isNotEmpty ? image.validate() : '',
      //   'small_icon': mAppIconUrl,
      'app_id': mOneSignalAppIdDriver,
      'android_channel_id': mOneSignalDriverChannelID,
      'include_player_ids': [receiverPlayerId],
      'android_group': mAppName,
      // 'sound': 'ride_get_sound',
    };
    var header = {
      HttpHeaders.authorizationHeader: 'Basic $mOneSignalRestKeyDriver',
      HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
    };

    Response res = await post(
      Uri.parse('https://onesignal.com/api/v1/notifications'),
      body: jsonEncode(req),
      headers: header,
    );

    log(res.body);

    if (res.statusCode.isEven) {
    } else {
      throw 'Something Went Wrong';
    }
  }
}
