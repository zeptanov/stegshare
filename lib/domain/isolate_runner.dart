import 'dart:async';
import 'dart:isolate';

import '../core/errors.dart';
import '../core/util/cancellation.dart';

typedef JobBody<A, R> = Future<R> Function(A arg, ProgressFn onProgress, CancellationToken token);

class _Msg {
  final SendPort port;
  final Object? arg;
  final Function body;
  const _Msg(this.port, this.arg, this.body);
}

class _Progress {
  final double f;
  final String s;
  const _Progress(this.f, this.s);
}

class _Done {
  final Object? result;
  const _Done(this.result);
}

class _Failed {
  final Object error;
  final String stack;
  const _Failed(this.error, this.stack);
}

/// Runs heavy work off the UI isolate with progress and hard cancellation.
class IsolateRunner {
  static Future<void> _entry(_Msg m) async {
    try {
      final token = CancellationToken();
      final r = await (m.body as dynamic)(m.arg, (double f, String s) => m.port.send(_Progress(f, s)), token);
      m.port.send(_Done(r));
    } catch (e, st) {
      final err = e is StegShareException ? e : StegShareException(e.toString());
      m.port.send(_Failed(err, st.toString()));
    }
  }

  static Future<R> run<A, R>(
    JobBody<A, R> body,
    A arg, {
    ProgressFn? onProgress,
    CancellationToken? token,
  }) async {
    final port = ReceivePort();
    final completer = Completer<R>();
    final isolate = await Isolate.spawn(_entry, _Msg(port.sendPort, arg, body),
        debugName: 'stegshare-worker');
    final sub = port.listen((msg) {
      if (completer.isCompleted) return;
      if (msg is _Progress) {
        onProgress?.call(msg.f, msg.s);
      } else if (msg is _Done) {
        completer.complete(msg.result as R);
      } else if (msg is _Failed) {
        completer.completeError(msg.error, StackTrace.fromString(msg.stack));
      }
    });
    StreamSubscription? cancelSub;
    if (token != null) {
      if (token.isCancelled) {
        isolate.kill(priority: Isolate.immediate);
        port.close();
        throw const CancelledException();
      }
      cancelSub = token.onCancel.listen((_) {
        isolate.kill(priority: Isolate.immediate);
        if (!completer.isCompleted) completer.completeError(const CancelledException());
      });
    }
    try {
      return await completer.future;
    } finally {
      await cancelSub?.cancel();
      await sub.cancel();
      port.close();
      isolate.kill(priority: Isolate.immediate);
    }
  }
}