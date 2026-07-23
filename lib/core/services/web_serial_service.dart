export 'web_serial_service_stub.dart' if (dart.library.html) 'web_serial_service_web.dart';

abstract class WebSerialService {
  Future<bool> isSupported();
  Future<void> requestPort();
  Stream<String> readData();
  Future<void> closePort();
}
