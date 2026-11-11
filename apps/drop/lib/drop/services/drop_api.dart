import 'package:mighty_core/core_mighty/mighty_core.dart';
import 'package:mighty_core/utils/core_enum.dart';
import 'package:mighty_core/utils/core_network_utils.dart';

/// Calls a DROP Worker endpoint and returns its JSON as a map. For the newer, cleaner endpoints
/// that have no dedicated model class.
Future<Map<String, dynamic>> dropApi(String path, {HttpMethods method = HttpMethods.GET, Map? request}) {
  return parseModel(
    apiCall: request == null ? executeRequest(path, method: method) : executeRequest(path, method: method, request: request),
    fromJson: (json) => Map<String, dynamic>.from(json as Map),
  );
}
