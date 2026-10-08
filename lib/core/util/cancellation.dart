import 'dart:async';

import '../errors.dart';

typedef ProgressFn = void Function(double fraction, String stage);

class CancellationToken {
  bool _cancelled = false;
  final _controller = StreamController<void>.broadcast();

  bool get isCancelled => _cancelled;
  Stream<void> get onCancel => _controller.stream;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _controller.add(null);
  }

  void throwIfCancelled() {
    if (_cancelled) throw const CancelledException();
  }

  void dispose() => _controller.close();
}