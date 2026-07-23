import 'dart:async';
import 'web_serial_service.dart';

WebSerialService getWebSerialService() => _WebSerialServiceStub();

class _WebSerialServiceStub implements WebSerialService {
  @override
  Future<bool> isSupported() async => false;

  @override
  Future<void> requestPort() async {
    throw UnsupportedError('Web Serial API is only supported on the Web.');
  }

  @override
  Stream<String> readData() {
    throw UnsupportedError('Web Serial API is only supported on the Web.');
  }

  @override
  Future<void> closePort() async {}
}
