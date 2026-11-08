import '../manage_imports.dart';

class AppServerConfig {
  static String get baseUrl {
    if (kReleaseMode) {
      return 'ADD_YOUR_BACKEND_URL_HERE'; // Don't add slash at the end of the url
    } else if (kProfileMode) {
      return 'ADD_YOUR_BACKEND_URL_HERE'; // Don't add slash at the end of the url
    } else {
      return 'ADD_YOUR_BACKEND_URL_HERE'; // Don't add slash at the end of the url
    }
  }
}
