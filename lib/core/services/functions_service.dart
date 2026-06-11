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
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      throw FunctionsException(
        code: e.code,
        message: e.message ?? 'An error occurred.',
        details: e.details,
      );
    } catch (e) {
      throw FunctionsException(
        code: 'unknown',
        message: e.toString(),
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
