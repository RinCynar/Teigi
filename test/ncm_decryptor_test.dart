import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:teigi/core/ncm/aes128.dart';
import 'package:teigi/core/ncm/ncm_decryptor.dart';
import 'package:teigi/core/ncm/ncm_metadata.dart';

void main() {
  group('NcmMetadata', () {
    test('parses standard NetEase JSON structure', () {
      const jsonStr = '''
      {
        "musicId": 123456,
        "musicName": "晴天",
        "artist": [["周杰伦", 6452], ["Jay Chou", 6452]],
        "album": "叶惠美",
        "albumPic": "https://example.com/cover.jpg",
        "format": "flac",
        "bitrate": 999000,
        "duration": 269000
      }
      ''';

      final meta = NcmMetadata.fromJsonString(jsonStr);
      expect(meta, isNotNull);
      expect(meta!.musicName, '晴天');
      expect(meta.artists, ['周杰伦', 'Jay Chou']);
      expect(meta.artistDisplay, '周杰伦 / Jay Chou');
      expect(meta.album, '叶惠美');
      expect(meta.format, 'flac');
    });

    test('handles empty or malformed JSON gracefully', () {
      expect(NcmMetadata.fromJsonString(''), isNull);
      expect(NcmMetadata.fromJsonString('{invalid'), isNull);
      expect(NcmMetadata.fromJsonString('[]'), isNull);
    });
  });

  group('NcmTagWriter', () {
    test('builds valid ID3v2.3 tag with header and frames', () {
      final dummyCover = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]); // JPEG magic
      final tag = NcmTagWriter.buildId3v2Tag(
        title: 'Song Title',
        artist: 'Artist Name',
        album: 'Album Title',
        coverBytes: dummyCover,
      );

      // Verify ID3v2 header
      expect(tag.length, greaterThan(10));
      expect(tag[0], 0x49); // 'I'
      expect(tag[1], 0x44); // 'D'
      expect(tag[2], 0x33); // '3'
      expect(tag[3], 0x03); // v2.3
      expect(tag[4], 0x00);
    });

    test('injects PICTURE block into FLAC header', () {
      // Minimal dummy FLAC header: "fLaC" + STREAMINFO block (34 bytes, marked as last block: 0x80 | 0)
      final flac = Uint8List(4 + 4 + 34);
      flac[0] = 0x66; // 'f'
      flac[1] = 0x4C; // 'L'
      flac[2] = 0x61; // 'a'
      flac[3] = 0x43; // 'C'
      flac[4] = 0x80; // is_last = 1, type = 0 (STREAMINFO)
      flac[7] = 34; // block length = 34

      final cover = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]);
      final withCover = NcmTagWriter.injectFlacCover(flac, cover);

      expect(withCover.length, greaterThan(flac.length));
      // First block should now have is_last = 0
      expect(withCover[4] & 0x80, 0);
    });
  });

  group('NcmDecryptor', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('teigi_ncm_test_');
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('rejects non-existent file', () async {
      final res = await NcmDecryptor.decryptFile(
        NcmDecryptRequest(
          sourcePath: '${tempDir.path}/non_existent.ncm',
          outputDirectory: tempDir.path,
        ),
      );
      expect(res.success, isFalse);
      expect(res.error, contains('File does not exist'));
    });

    test('rejects invalid magic header', () async {
      final badFile = File('${tempDir.path}/bad.ncm');
      badFile.writeAsBytesSync([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07]);

      final res = await NcmDecryptor.decryptFile(
        NcmDecryptRequest(
          sourcePath: badFile.path,
          outputDirectory: tempDir.path,
        ),
      );
      expect(res.success, isFalse);
      expect(res.error, contains('magic header mismatch'));
    });

    test('decrypts complete synthetic NCM file end-to-end', () async {
      // 1. Create realistic audio payload (starts with MP3 frame sync)
      final rawAudio = Uint8List(1024);
      rawAudio[0] = 0xFF;
      rawAudio[1] = 0xFB;
      for (int i = 2; i < rawAudio.length; i++) {
        rawAudio[i] = (i * 31) & 0xFF;
      }

      final dummyCover = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x11, 0x22]);

      final ncmBytes = _createSyntheticNcm(
        musicName: '测试歌曲',
        artist: '测试歌手',
        album: '测试专辑',
        format: 'mp3',
        rawAudioPayload: rawAudio,
        coverBytes: dummyCover,
      );

      final ncmFile = File('${tempDir.path}/sample.ncm');
      ncmFile.writeAsBytesSync(ncmBytes);

      double lastProgress = 0.0;
      final res = await NcmDecryptor.decryptFile(
        NcmDecryptRequest(
          sourcePath: ncmFile.path,
          outputDirectory: tempDir.path,
        ),
        onProgress: (p) => lastProgress = p,
      );

      expect(res.error, isNull);
      expect(res.success, isTrue);
      expect(res.musicTitle, '测试歌曲');
      expect(res.artistDisplay, '测试歌手');
      expect(res.album, '测试专辑');
      expect(res.format, 'mp3');
      expect(res.outputPath, isNotNull);
      expect(File(res.outputPath!).existsSync(), isTrue);
      expect(lastProgress, equals(1.0));

      final decryptedBytes = File(res.outputPath!).readAsBytesSync();
      // Should have ID3 header
      expect(decryptedBytes.length, greaterThan(rawAudio.length));
      expect(decryptedBytes[0], 0x49); // 'I'
      expect(decryptedBytes[1], 0x44); // 'D'
      expect(decryptedBytes[2], 0x33); // '3'
    });
  });
}

Uint8List _createSyntheticNcm({
  required String musicName,
  required String artist,
  required String album,
  required String format,
  required Uint8List rawAudioPayload,
  Uint8List? coverBytes,
}) {
  final bb = BytesBuilder();
  // 1. Magic
  bb.add([0x43, 0x54, 0x45, 0x4E, 0x46, 0x44, 0x41, 0x4D]);
  // 2. Gap
  bb.add([0x01, 0x70]);

  // 3. Key Box
  final rc4Key = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]);
  final keyPlain = BytesBuilder();
  keyPlain.add(ascii.encode('neteasecloudmusic'));
  keyPlain.add(rc4Key);
  final coreAes = Aes128Ecb(Aes128Ecb.ncmCoreKey);
  final encryptedKey = coreAes.encrypt(keyPlain.toBytes());
  for (int i = 0; i < encryptedKey.length; i++) {
    encryptedKey[i] ^= 0x64;
  }
  _writeUint32Le(bb, encryptedKey.length);
  bb.add(encryptedKey);

  // 4. Metadata
  final metaJson = json.encode({
    'musicName': musicName,
    'artist': [[artist, 100]],
    'album': album,
    'format': format,
  });
  final metaPlain = BytesBuilder();
  metaPlain.add(ascii.encode('music:'));
  metaPlain.add(utf8.encode(metaJson));
  final metaAes = Aes128Ecb(Aes128Ecb.ncmMetaKey);
  final encryptedMeta = metaAes.encrypt(metaPlain.toBytes());
  final b64Str = base64.encode(encryptedMeta);
  final metaWithPrefix = BytesBuilder();
  metaWithPrefix.add(ascii.encode("163 key(Don't modify):"));
  metaWithPrefix.add(ascii.encode(b64Str));
  final metaBytes = metaWithPrefix.toBytes();
  for (int i = 0; i < metaBytes.length; i++) {
    metaBytes[i] ^= 0x63;
  }
  _writeUint32Le(bb, metaBytes.length);
  bb.add(metaBytes);

  // 5. CRC & Cover
  bb.add([0x00, 0x00, 0x00, 0x00, 0x00]);
  final image = coverBytes ?? Uint8List(0);
  _writeUint32Le(bb, image.length);
  _writeUint32Le(bb, image.length);
  if (image.isNotEmpty) {
    bb.add(image);
  }

  // 6. Audio payload
  final box = Uint8List(256);
  for (int i = 0; i < 256; i++) {
    box[i] = i;
  }
  int j = 0;
  for (int i = 0; i < 256; i++) {
    j = (j + box[i] + rc4Key[i % rc4Key.length]) & 0xFF;
    final t = box[i];
    box[i] = box[j];
    box[j] = t;
  }
  final maskTable = Uint8List(256);
  for (int i = 0; i < 256; i++) {
    final idx = (i + 1) & 0xFF;
    maskTable[i] = box[(box[idx] + box[(box[idx] + idx) & 0xFF]) & 0xFF];
  }

  final encryptedAudio = Uint8List.fromList(rawAudioPayload);
  for (int i = 0; i < encryptedAudio.length; i++) {
    encryptedAudio[i] ^= maskTable[i & 0xFF];
  }
  bb.add(encryptedAudio);

  return bb.toBytes();
}

void _writeUint32Le(BytesBuilder bb, int value) {
  bb.addByte(value & 0xFF);
  bb.addByte((value >> 8) & 0xFF);
  bb.addByte((value >> 16) & 0xFF);
  bb.addByte((value >> 24) & 0xFF);
}
