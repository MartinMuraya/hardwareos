import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';
import 'web_serial_service.dart';

WebSerialService getWebSerialService() => _WebSerialServiceWeb();

class _WebSerialServiceWeb implements WebSerialService {
  dynamic _port;
  dynamic _reader;
  bool _isReading = false;

  @override
  Future<bool> isSupported() async {
    final navigator = html.window.navigator;
    return js_util.hasProperty(navigator, 'serial');
  }

  @override
  Future<void> requestPort() async {
    final navigator = html.window.navigator;
    if (!js_util.hasProperty(navigator, 'serial')) {
      throw Exception('Web Serial API not supported in this browser.');
    }
    
    final serial = js_util.getProperty(navigator, 'serial');
    
    _port = await js_util.promiseToFuture(
      js_util.callMethod(serial, 'requestPort', [])
    );
    
    final options = js_util.newObject();
    js_util.setProperty(options, 'baudRate', 9600);
    await js_util.promiseToFuture(
      js_util.callMethod(_port, 'open', [options])
    );
  }

  @override
  Stream<String> readData() {
    if (_port == null) throw Exception('Port not opened');
    
    late StreamController<String> controller;
    
    controller = StreamController<String>(
      onListen: () async {
        _isReading = true;
        try {
          while (_isReading && js_util.getProperty(_port, 'readable') != null) {
            _reader = js_util.callMethod(js_util.getProperty(_port, 'readable'), 'getReader', []);
            try {
              while (_isReading) {
                final result = await js_util.promiseToFuture(js_util.callMethod(_reader, 'read', []));
                final done = js_util.getProperty(result, 'done');
                if (done) {
                  break;
                }
                final value = js_util.getProperty(result, 'value');
                if (value != null) {
                  final bytes = value as Uint8List;
                  final str = String.fromCharCodes(bytes);
                  controller.add(str);
                }
              }
            } finally {
              js_util.callMethod(_reader, 'releaseLock', []);
            }
          }
        } catch (e) {
          controller.addError(e);
        }
      },
      onCancel: () {
        _isReading = false;
        closePort();
      }
    );
    
    return controller.stream;
  }

  @override
  Future<void> closePort() async {
    _isReading = false;
    if (_reader != null) {
      try {
        await js_util.promiseToFuture(js_util.callMethod(_reader, 'cancel', []));
      } catch (_) {}
    }
    if (_port != null) {
      try {
        await js_util.promiseToFuture(js_util.callMethod(_port, 'close', []));
      } catch (_) {}
      _port = null;
    }
  }
}
