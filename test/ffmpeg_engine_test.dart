import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:teigi/core/ffmpeg/engine/desktop_ffmpeg_engine.dart';
import 'package:teigi/core/ffmpeg/engine/ffmpeg_engine.dart';
import 'package:teigi/core/ffmpeg/ffmpeg_command.dart';
import 'package:teigi/core/ffmpeg/ffmpeg_detector.dart';

void main() {
  test('DesktopFfmpegEngine exposes desktop capabilities', () {
    final capabilities = DesktopFfmpegEngine().capabilities;

    expect(capabilities.supportsCustomExecutablePath, isTrue);
    expect(capabilities.supportsHardwareAccelProbe, isFalse);
    expect(capabilities.supportsConcurrentSessions, isTrue);
  });

  test('DesktopFfmpegEngine runs a command through its task handle', () async {
    final executable = Platform.isWindows
        ? (Platform.environment['ComSpec'] ?? 'cmd.exe')
        : '/bin/sh';
    final args = Platform.isWindows ? ['/c', 'exit', '0'] : ['-c', 'true'];
    final engine = DesktopFfmpegEngine(
      detector: _FakeDetector(
        FfmpegEngineStatus(
          isReady: true,
          version: 'test',
          resolvedExecutablePath: executable,
        ),
      ),
    );

    final status = await engine.detect(customExecutablePath: executable);
    expect(status.resolvedExecutablePath, executable);

    final handle = engine.run(FfmpegCommand(args: args, outputPath: 'unused'));
    final result = await handle.result;

    expect(result.isSuccess, isTrue);
    expect(result.state, FfmpegTaskState.completed);
    expect(result.outputPath, 'unused');
  });

  test('cancel terminates a running process on the host platform', () async {
    final executable = Platform.isWindows
        ? (Platform.environment['ComSpec'] ?? 'cmd.exe')
        : '/bin/sleep';
    final args = Platform.isWindows
        ? <String>['/c', 'ping', '-n', '30', '127.0.0.1']
        : <String>['30'];
    final engine = DesktopFfmpegEngine(
      detector: _FakeDetector(
        FfmpegEngineStatus(
          isReady: true,
          version: 'test',
          resolvedExecutablePath: executable,
        ),
      ),
    );

    final status = await engine.detect(customExecutablePath: executable);
    expect(status.resolvedExecutablePath, executable);

    final states = <FfmpegTaskState>[];
    final handle = engine.run(
      FfmpegCommand(args: args, outputPath: 'unused'),
    );
    final subscription = handle.states.listen(states.add);

    await Future<void>.delayed(const Duration(milliseconds: 200));
    await handle.cancel();
    final result = await handle.result;
    await subscription.cancel();

    expect(result.isCancelled, isTrue);
    expect(states, contains(FfmpegTaskState.running));
  });

  test('FfmpegDetector prioritizes custom, bundled, then PATH', () async {
    final probed = <String>[];
    final detector = FfmpegDetector(
      bundledPathResolver: () async => 'bundled-ffmpeg',
      pathResolver: () async => 'path-ffmpeg',
      probe: (path) async {
        probed.add(path);
        return FfmpegEngineStatus(
          isReady: true,
          version: path,
          resolvedExecutablePath: path,
        );
      },
    );

    final custom = await detector.detect(customPath: 'custom-ffmpeg');
    expect(custom.resolvedExecutablePath, 'custom-ffmpeg');
    expect(custom.source, FfmpegEngineSource.custom);

    final bundled = await detector.detect();
    expect(bundled.resolvedExecutablePath, 'bundled-ffmpeg');
    expect(bundled.source, FfmpegEngineSource.bundled);

    expect(probed, ['custom-ffmpeg', 'bundled-ffmpeg']);

    final pathDetector = FfmpegDetector(
      bundledPathResolver: () async => null,
      pathResolver: () async => 'path-ffmpeg',
      probe: (path) async => FfmpegEngineStatus(
        isReady: true,
        version: path,
        resolvedExecutablePath: path,
      ),
    );
    final path = await pathDetector.detect();
    expect(path.resolvedExecutablePath, 'path-ffmpeg');
    expect(path.source, FfmpegEngineSource.systemPath);
  });

  test(
    'FfmpegDetector marks custom fallback without silent source switching',
    () async {
      final detector = FfmpegDetector(
        bundledPathResolver: () async => 'bundled-ffmpeg',
        pathResolver: () async => 'path-ffmpeg',
        probe: (path) async {
          if (path == 'missing-custom') {
            return const FfmpegEngineStatus(
              isReady: false,
              errorMessage: 'missing',
            );
          }
          return FfmpegEngineStatus(
            isReady: true,
            version: path,
            resolvedExecutablePath: path,
          );
        },
      );

      final status = await detector.detect(customPath: 'missing-custom');

      expect(status.isReady, isTrue);
      expect(status.source, FfmpegEngineSource.bundled);
      expect(status.isFallback, isTrue);
      expect(status.requestedSource, FfmpegEngineSource.custom);
      expect(status.requestedExecutablePath, 'missing-custom');
    },
  );

  test(
    'FfmpegDetector reports a missing custom path when no fallback exists',
    () async {
      final detector = FfmpegDetector(
        bundledPathResolver: () async => null,
        pathResolver: () async => null,
      );

      final status = await detector.detect(customPath: 'missing-ffmpeg');

      expect(status.isReady, isFalse);
      expect(status.source, FfmpegEngineSource.custom);
      expect(status.errorMessage, contains('文件不存在'));
    },
  );
}

class _FakeDetector extends FfmpegDetector {
  _FakeDetector(this.status);

  final FfmpegEngineStatus status;

  @override
  Future<FfmpegEngineStatus> detect({String? customPath}) async => status;
}
