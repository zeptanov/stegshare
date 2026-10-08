import 'dart:typed_data';

import '../core/util/cancellation.dart';
import 'isolate_runner.dart';
import 'models.dart';
import 'steg_pipeline.dart';

/// Facade used by the UI layer. All CPU-heavy work goes through isolates.
class StegShareService {
  Future<ImageInspection> inspectImage(Uint8List bytes) =>
      IsolateRunner.run(StegPipeline.inspect, bytes);

  Future<Uint8List> hide(HideJob job, {ProgressFn? onProgress, CancellationToken? token}) =>
      IsolateRunner.run(StegPipeline.hide, job, onProgress: onProgress, token: token);

  Future<ExtractResult> extract(ExtractJob job, {ProgressFn? onProgress, CancellationToken? token}) =>
      IsolateRunner.run(StegPipeline.extract, job, onProgress: onProgress, token: token);
}