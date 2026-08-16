import 'package:flutter_test/flutter_test.dart';
import 'package:teigi/core/ffmpeg/ffmpeg_command_builder.dart';
import 'package:teigi/core/models/batch_options_patch.dart';
import 'package:teigi/core/models/conversion_options.dart';
import 'package:teigi/core/models/conversion_task.dart';
import 'package:teigi/core/models/format_copy.dart';
import 'package:teigi/core/models/media_file.dart';
import 'package:teigi/providers/queue_provider.dart';
import 'package:teigi/providers/selection_provider.dart';
import 'package:teigi/shared/layout/app_shell.dart';

void main() {
  group('AppShell.indexFor', () {
    test('About is a Settings child', () {
      expect(AppShell.indexFor('/settings'), 3);
      expect(AppShell.indexFor('/settings/about'), 3);
      expect(AppShell.indexFor('/convert'), 0);
      expect(AppShell.indexFor('/queue'), 1);
      expect(AppShell.indexFor('/presets'), 2);
    });
  });

  group('SelectionNotifier', () {
    test('single, ctrl, shift, select all', () {
      final s = SelectionNotifier();
      const ids = ['a', 'b', 'c', 'd'];
      s.handleClick('b', orderedIds: ids, ctrl: false, shift: false);
      expect(s.state, {'b'});
      s.handleClick('d', orderedIds: ids, ctrl: true, shift: false, anchorId: 'b');
      expect(s.state, {'b', 'd'});
      s.handleClick('d', orderedIds: ids, ctrl: false, shift: true, anchorId: 'b');
      expect(s.state, {'b', 'c', 'd'});
      s.selectAll(ids);
      expect(s.state, {'a', 'b', 'c', 'd'});
      s.clear();
      expect(s.state, isEmpty);
    });
  });

  group('BatchOptionsPatch', () {
    const base = ConversionOptions(
      videoEncoder: 'libx265',
      crf: 18,
      bitrateKbps: 320,
      resolution: '1920x1080',
    );

    test('Unchanged keeps values', () {
      const patch = BatchOptionsPatch();
      final next = patch.apply(base);
      expect(next.videoEncoder, 'libx265');
      expect(next.crf, 18);
      expect(next.bitrateKbps, 320);
    });

    test('SetValue overwrites one field', () {
      const patch = BatchOptionsPatch(crf: SetValue(20));
      final next = patch.apply(base);
      expect(next.crf, 20);
      expect(next.videoEncoder, 'libx265');
    });

    test('SetAuto clears to null', () {
      const patch = BatchOptionsPatch(bitrateKbps: SetAuto());
      final next = patch.apply(base);
      expect(next.bitrateKbps, isNull);
      expect(next.crf, 18);
    });
  });

  group('bitrate Auto vs explicit', () {
    const builder = FfmpegCommandBuilder();

    ConversionTask t(ConversionOptions o) => ConversionTask(
          id: '1',
          source: const MediaFile(path: '/in/a.mp3'),
          targetFormat: 'mp3',
          options: o,
        );

    test('default bitrate is null and does not emit -b:a', () {
      expect(const ConversionOptions().bitrateKbps, isNull);
      final args = builder.buildArgs(
        t(const ConversionOptions(outputDirectory: '/out')),
        '/out/a.mp3',
      );
      expect(args, isNot(contains('-b:a')));
    });

    test('192 emits -b:a 192k', () {
      final args = builder.buildArgs(
        t(const ConversionOptions(bitrateKbps: 192, outputDirectory: '/out')),
        '/out/a.mp3',
      );
      expect(args, containsAllInOrder(['-b:a', '192k']));
    });
  });

  group('FormatCopy.search', () {
    test('mp4 and web', () {
      expect(FormatCopy.search('mp4').map((e) => e.title), contains('MP4'));
      final web = FormatCopy.search('web').map((e) => e.title).toList();
      expect(web, containsAll(['WebM', 'WebP']));
    });

    test('custom extension stays allowed', () {
      final copy = FormatCopy.of('foo');
      expect(copy.custom, isTrue);
      expect(copy.title, 'FOO');
    });
  });

  group('QueueNotifier batch format', () {
    test('sets format on selected ids only', () {
      final n = QueueNotifier();
      n.addFiles([
        const MediaFile(path: '/a.mkv'),
        const MediaFile(path: '/b.mkv'),
        const MediaFile(path: '/c.mp4'),
      ]);
      n.setTargetFormatFor([n.state[0].id, n.state[1].id], 'mp4');
      expect(n.state[0].targetFormat, 'mp4');
      expect(n.state[1].targetFormat, 'mp4');
    });
  });
}
