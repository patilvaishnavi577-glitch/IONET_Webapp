import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

class QrScannerPlatform {
  static Future<String?> scan() {
    final completer = Completer<String?>();

    try {
      final jsScanner = globalContext.getProperty('ionetScanner'.toJS) as JSObject?;
      if (jsScanner == null) {
        return Future.value(null);
      }

      final onSuccess = ((JSString result) {
        if (!completer.isCompleted) {
          completer.complete(result.toDart);
        }
      }).toJS;

      final onCancel = (() {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      }).toJS;

      jsScanner.callMethod('open'.toJS, onSuccess, onCancel);
    } catch (_) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }

    return completer.future;
  }
}
