import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class BarcodeListener extends StatefulWidget {
  final Widget child;
  final ValueChanged<String> onBarcodeScanned;
  final Duration bufferDuration;
  final bool useKeyDownEvent;

  const BarcodeListener({
    super.key,
    required this.child,
    required this.onBarcodeScanned,
    this.bufferDuration = const Duration(milliseconds: 100),
    this.useKeyDownEvent = true,
  });

  @override
  State<BarcodeListener> createState() => _BarcodeListenerState();
}

class _BarcodeListenerState extends State<BarcodeListener> {
  final StringBuffer _buffer = StringBuffer();
  DateTime? _lastKeyPress;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    super.dispose();
  }

  bool _handleKey(KeyEvent event) {
    if (widget.useKeyDownEvent && event is! KeyDownEvent) return false;
    if (!widget.useKeyDownEvent && event is! KeyUpEvent) return false;

    // Handle Enter key as the terminator for a scan
    if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (_buffer.isNotEmpty) {
        final barcode = _buffer.toString();
        _buffer.clear();
        _lastKeyPress = null;
        
        // If it was typed very fast (e.g., > 3 chars and recent), treat as barcode
        if (barcode.length >= 3) {
           widget.onBarcodeScanned(barcode);
           return true; // handled
        }
      }
      return false;
    }

    final char = event.character;
    if (char != null && char.isNotEmpty) {
      final now = DateTime.now();
      if (_lastKeyPress != null && now.difference(_lastKeyPress!) > widget.bufferDuration) {
        // Too much time passed since last key press, clear buffer (probably a human typing)
        _buffer.clear();
      }
      _buffer.write(char);
      _lastKeyPress = now;
    }
    
    return false; // let the event bubble down to text fields just in case
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
