import 'package:cloud_functions/cloud_functions.dart';

/// Thin wrapper around Firebase Cloud Functions callable invocations.
/// All feature services go through this class — never call FirebaseFunctions directly.
class FunctionsService {
  FunctionsService._();

  static final _functions = FirebaseFunctions.instance;

  // For local emulator development — uncomment when using emulators
  // static void useEmulator() {
  //   _functions.useFunctionsEmulator('localhost', 5001);
  // }

  /// Recursively converts platform-internal Map/List types returned by
  /// Firebase callable functions into standard Dart Map<String, dynamic> / List.
  /// Without this, nested structures (e.g. Timestamps serialized as Maps,
  /// Lists of Maps) retain internal types and throw cast errors at runtime.
  static dynamic _deepConvert(dynamic value) {
    if (value is Map) {
      return value.map<String, dynamic>(
        (key, val) => MapEntry(key.toString(), _deepConvert(val)),
      );
    } else if (value is List) {
      return value.map((item) => _deepConvert(item)).toList();
    }
    return value;
  }

  static Future<Map<String, dynamic>> call(
    String functionName,
    Map<String, dynamic> data,
  ) async {
    try {
      final fn = _functions.httpsCallable(
        functionName,
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );
      final result = await fn.call(data);
      return _deepConvert(result.data) as Map<String, dynamic>;
    } on FirebaseFunctionsException catch (e) {
      String msg = e.message ?? 'An error occurred.';
      if (e.code == 'internal' || msg.toLowerCase().contains('internal')) {
        msg =
            'Unable to connect to the backend server. Please check your connection or ensure backend services are running.';
      } else if (e.code == 'unavailable') {
        msg = 'The service is temporarily unavailable. Please try again later.';
      }
      throw FunctionsException(
        code: e.code,
        message: msg,
        details: e.details,
      );
    } catch (e) {
      throw const FunctionsException(
        code: 'unknown',
        message: 'An unexpected network error occurred.',
      );
    }
  }
}

class FunctionsException implements Exception {
  final String code;
  final String message;
  final dynamic details;

  const FunctionsException({
    required this.code,
    required this.message,
    this.details,
  });

  @override
  String toString() => 'FunctionsException[$code]: $message';
}
