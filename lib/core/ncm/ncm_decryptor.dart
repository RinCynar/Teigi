import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:teigi/core/ncm/aes128.dart';
import 'package:teigi/core/ncm/ncm_metadata.dart';

/// Request parameters for decrypting an NCM file.
class NcmDecryptRequest {
  final String sourcePath;
  final String outputDirectory;
  final bool overwrite;

  const NcmDecryptRequest({
    required this.sourcePath,
    required this.outputDirectory,
    this.overwrite = false,
  });
}

/// Decryption outcome for an NCM file.
class NcmDecryptionResult {
  final bool success;
  final String sourcePath;
  final String? outputPath;
  final String? musicTitle;
  final List<String> artists;
  final String? album;
  final String? format;
  final Uint8List? coverBytes;
  final String? error;

  const NcmDecryptionResult({
    required this.success,
    required this.sourcePath,
    this.outputPath,
    this.musicTitle,
    this.artists = const [],
    this.album,
    this.format,
    this.coverBytes,
    this.error,
  });

  String get artistDisplay => artists.isEmpty ? '' : artists.join(' / ');
}

/// High-performance, pure Dart NCM audio decryptor running in a background Isolate.
class NcmDecryptor {
  static const List<int> _ncmMagic = [0x43, 0x54, 0x45, 0x4E, 0x46, 0x44, 0x41, 0x4D]; // CTENFDAM
  static const int _chunkSize = 64 * 1024; // 64 KB streaming buffer

  /// Decrypts [sourcePath] asynchronously in a dedicated Isolate.
  ///
  /// Calls [onProgress] with a ratio from 0.0 to 1.0 during file processing.
  static Future<NcmDecryptionResult> decryptFile(
    NcmDecryptRequest request, {
    void Function(double progress)? onProgress,
  }) async {
    final receivePort = ReceivePort();

    try {
      await Isolate.spawn(
        _isolateEntry,
        _IsolateInitMessage(request, receivePort.sendPort),
      );

      final completer = Completer<NcmDecryptionResult>();

      receivePort.listen((message) {
        if (message is double) {
          onProgress?.call(message);
        } else if (message is NcmDecryptionResult) {
          completer.complete(message);
        } else if (message is String) {
          completer.complete(
            NcmDecryptionResult(
              success: false,
              sourcePath: request.sourcePath,
              error: message,
            ),
          );
        }
      });

      return await completer.future;
    } catch (e) {
      return NcmDecryptionResult(
        success: false,
        sourcePath: request.sourcePath,
        error: e.toString(),
      );
    } finally {
      receivePort.close();
    }
  }

  /// Synchronous core decryption logic designed to run inside an Isolate.
  static NcmDecryptionResult decryptSynchronous(
    NcmDecryptRequest request, {
    void Function(double progress)? onProgress,
  }) {
    final file = File(request.sourcePath);
    if (!file.existsSync()) {
      return NcmDecryptionResult(
        success: false,
        sourcePath: request.sourcePath,
        error: 'File does not exist: ${request.sourcePath}',
      );
    }

    RandomAccessFile? raf;
    RandomAccessFile? outRaf;
    File? tempOutputFile;

    try {
      raf = file.openSync(mode: FileMode.read);
      final totalFileSize = raf.lengthSync();

      // 1. Verify Magic Header
      final magic = raf.readSync(8);
      if (magic.length != 8 || !_matchesMagic(magic)) {
        return NcmDecryptionResult(
          success: false,
          sourcePath: request.sourcePath,
          error: 'Invalid NCM format: magic header mismatch',
        );
      }

      // 2. Skip 2-byte gap
      raf.setPositionSync(raf.positionSync() + 2);

      // 3. Key Block
      final keyLenBytes = raf.readSync(4);
      if (keyLenBytes.length < 4) {
        return NcmDecryptionResult(
          success: false,
          sourcePath: request.sourcePath,
          error: 'Corrupt file: unexpected EOF reading key length',
        );
      }
      final keyLength = _readUint32Le(keyLenBytes);
      if (keyLength <= 0 || keyLength > 10 * 1024 * 1024) {
        return NcmDecryptionResult(
          success: false,
          sourcePath: request.sourcePath,
          error: 'Invalid key length: $keyLength',
        );
      }

      final rawKeyData = raf.readSync(keyLength);
      for (int i = 0; i < rawKeyData.length; i++) {
        rawKeyData[i] ^= 0x64;
      }

      final coreCipher = Aes128Ecb(Aes128Ecb.ncmCoreKey);
      final decryptedKeyBlock = coreCipher.decrypt(rawKeyData);

      // Strip "neteasecloudmusic" prefix (17 bytes)
      Uint8List rc4Key;
      const keyPrefix = 'neteasecloudmusic';
      final keyPrefixBytes = ascii.encode(keyPrefix);
      if (decryptedKeyBlock.length >= 17 &&
          _listStartsWith(decryptedKeyBlock, keyPrefixBytes)) {
        rc4Key = Uint8List.sublistView(decryptedKeyBlock, 17);
      } else {
        rc4Key = decryptedKeyBlock;
      }

      // 4. Metadata Block
      final metaLenBytes = raf.readSync(4);
      NcmMetadata? metadata;
      if (metaLenBytes.length == 4) {
        final metaLen = _readUint32Le(metaLenBytes);
        if (metaLen > 0) {
          final rawMeta = raf.readSync(metaLen);
          for (int i = 0; i < rawMeta.length; i++) {
            rawMeta[i] ^= 0x63;
          }

          try {
            // Strip "163 key(Don't modify):" prefix (22 bytes)
            const metaPrefix = "163 key(Don't modify):";
            final metaPrefixBytes = ascii.encode(metaPrefix);

            Uint8List b64Input;
            if (_listStartsWith(rawMeta, metaPrefixBytes)) {
              b64Input = Uint8List.sublistView(rawMeta, metaPrefixBytes.length);
            } else {
              b64Input = rawMeta;
            }

            final b64Str = ascii.decode(b64Input, allowInvalid: true).trim();
            final metaEncrypted = base64.decode(b64Str);

            final metaCipher = Aes128Ecb(Aes128Ecb.ncmMetaKey);
            final decryptedMeta = metaCipher.decrypt(Uint8List.fromList(metaEncrypted));

            // Strip "music:" prefix (6 bytes)
            const musicPrefix = 'music:';
            final musicPrefixBytes = ascii.encode(musicPrefix);
            Uint8List jsonBytes;
            if (_listStartsWith(decryptedMeta, musicPrefixBytes)) {
              jsonBytes = Uint8List.sublistView(decryptedMeta, musicPrefixBytes.length);
            } else {
              jsonBytes = decryptedMeta;
            }

            final jsonStr = utf8.decode(jsonBytes, allowMalformed: true);
            metadata = NcmMetadata.fromJsonString(jsonStr);
          } catch (_) {
            // Non-critical metadata failure: continue audio extraction
          }
        }
      }

      // 5. CRC & Album Art Frame
      raf.setPositionSync(raf.positionSync() + 5); // 4-byte CRC + 1-byte flag

      Uint8List? coverBytes;
      final coverFrameLenBytes = raf.readSync(4);
      final imageLenBytes = raf.readSync(4);
      if (coverFrameLenBytes.length == 4 && imageLenBytes.length == 4) {
        final coverFrameLen = _readUint32Le(coverFrameLenBytes);
        final imageLen = _readUint32Le(imageLenBytes);

        if (imageLen > 0 && imageLen <= coverFrameLen && imageLen <= 20 * 1024 * 1024) {
          coverBytes = raf.readSync(imageLen);
          final padding = coverFrameLen - imageLen;
          if (padding > 0) {
            raf.setPositionSync(raf.positionSync() + padding);
          }
        } else if (coverFrameLen > 0) {
          raf.setPositionSync(raf.positionSync() + coverFrameLen);
        }
      }

      // 6. Build S-Box and 256-byte cyclic XOR mask table
      final box = Uint8List(256);
      for (int i = 0; i < 256; i++) {
        box[i] = i;
      }
      int boxJ = 0;
      final kLen = rc4Key.length;
      for (int i = 0; i < 256; i++) {
        boxJ = (boxJ + box[i] + rc4Key[i % kLen]) & 0xFF;
        final t = box[i];
        box[i] = box[boxJ];
        box[boxJ] = t;
      }

      final maskTable = Uint8List(256);
      for (int i = 0; i < 256; i++) {
        final j = (i + 1) & 0xFF;
        maskTable[i] = box[(box[j] + box[(box[j] + j) & 0xFF]) & 0xFF];
      }

      // 7. Peek first audio chunk to detect format
      final audioStartPos = raf.positionSync();
      final totalAudioBytes = totalFileSize - audioStartPos;
      if (totalAudioBytes <= 0) {
        return NcmDecryptionResult(
          success: false,
          sourcePath: request.sourcePath,
          error: 'No audio data found in file',
        );
      }

      final peekChunk = raf.readSync(4096);
      for (int i = 0; i < peekChunk.length; i++) {
        peekChunk[i] ^= maskTable[i & 0xFF];
      }

      // Detect FLAC vs MP3
      String detectedFormat;
      if (peekChunk.length >= 4 &&
          peekChunk[0] == 0x66 &&
          peekChunk[1] == 0x4C &&
          peekChunk[2] == 0x61 &&
          peekChunk[3] == 0x43) {
        detectedFormat = 'flac';
      } else if (metadata != null && metadata.format.toLowerCase() == 'flac') {
        detectedFormat = 'flac';
      } else {
        detectedFormat = 'mp3';
      }

      // 8. Prepare target output path
      final outDir = Directory(request.outputDirectory);
      if (!outDir.existsSync()) {
        outDir.createSync(recursive: true);
      }

      String baseName;
      if (metadata != null && metadata.musicName.isNotEmpty) {
        if (metadata.artistDisplay.isNotEmpty) {
          baseName = '${metadata.artistDisplay} - ${metadata.musicName}';
        } else {
          baseName = metadata.musicName;
        }
      } else {
        baseName = p.basenameWithoutExtension(request.sourcePath);
      }
      baseName = _sanitizeFileName(baseName);

      String targetPath = p.join(request.outputDirectory, '$baseName.$detectedFormat');
      if (!request.overwrite && File(targetPath).existsSync()) {
        int counter = 1;
        while (File(p.join(request.outputDirectory, '$baseName ($counter).$detectedFormat')).existsSync()) {
          counter++;
        }
        targetPath = p.join(request.outputDirectory, '$baseName ($counter).$detectedFormat');
      }

      final tempPath = '$targetPath.tmp_${DateTime.now().millisecondsSinceEpoch}';
      tempOutputFile = File(tempPath);
      outRaf = tempOutputFile.openSync(mode: FileMode.write);

      // Reset stream position to audio start
      raf.setPositionSync(audioStartPos);

      // 9. Streaming Decryption Loop
      int streamOffset = 0;

      // Handle MP3 ID3 header or FLAC cover injection
      if (detectedFormat == 'mp3' && metadata != null) {
        final id3Tag = NcmTagWriter.buildId3v2Tag(
          title: metadata.musicName,
          artist: metadata.artistDisplay,
          album: metadata.album,
          coverBytes: coverBytes,
        );

        // Check if stream already has an ID3 tag
        if (peekChunk.length >= 10 &&
            peekChunk[0] == 0x49 &&
            peekChunk[1] == 0x44 &&
            peekChunk[2] == 0x33) {
          // Existing ID3 tag size in stream
          final existingTagSize = (peekChunk[6] << 21) |
              (peekChunk[7] << 14) |
              (peekChunk[8] << 7) |
              peekChunk[9];
          final totalSkip = 10 + existingTagSize;
          raf.setPositionSync(audioStartPos + totalSkip);
          streamOffset = totalSkip;
        }

        outRaf.writeFromSync(id3Tag);
      }

      while (true) {
        final chunk = raf.readSync(_chunkSize);
        if (chunk.isEmpty) break;

        for (int i = 0; i < chunk.length; i++) {
          chunk[i] ^= maskTable[(streamOffset + i) & 0xFF];
        }

        outRaf.writeFromSync(chunk);
        streamOffset += chunk.length;

        if (onProgress != null && totalAudioBytes > 0) {
          final progress = (streamOffset / totalAudioBytes).clamp(0.0, 1.0);
          onProgress(progress);
        }
      }

      outRaf.closeSync();
      outRaf = null;

      // For FLAC with cover art: inject cover into FLAC header if possible
      if (detectedFormat == 'flac' && coverBytes != null && coverBytes.isNotEmpty) {
        try {
          final flacRaw = tempOutputFile.readAsBytesSync();
          final updated = NcmTagWriter.injectFlacCover(flacRaw, coverBytes);
          if (updated.length != flacRaw.length) {
            tempOutputFile.writeAsBytesSync(updated, flush: true);
          }
        } catch (_) {
          // Keep raw decrypted FLAC if injection encountered format anomaly
        }
      }

      // Rename temp to final output
      if (File(targetPath).existsSync()) {
        File(targetPath).deleteSync();
      }
      tempOutputFile.renameSync(targetPath);

      return NcmDecryptionResult(
        success: true,
        sourcePath: request.sourcePath,
        outputPath: targetPath,
        musicTitle: metadata?.musicName,
        artists: metadata?.artists ?? const [],
        album: metadata?.album,
        format: detectedFormat,
        coverBytes: coverBytes,
      );
    } catch (e) {
      if (tempOutputFile != null && tempOutputFile.existsSync()) {
        try {
          tempOutputFile.deleteSync();
        } catch (_) {}
      }
      return NcmDecryptionResult(
        success: false,
        sourcePath: request.sourcePath,
        error: e.toString(),
      );
    } finally {
      outRaf?.closeSync();
      raf?.closeSync();
    }
  }

  static bool _matchesMagic(List<int> bytes) {
    if (bytes.length < 8) return false;
    for (int i = 0; i < 8; i++) {
      if (bytes[i] != _ncmMagic[i]) return false;
    }
    return true;
  }

  static int _readUint32Le(List<int> bytes) {
    return (bytes[0] & 0xFF) |
        ((bytes[1] & 0xFF) << 8) |
        ((bytes[2] & 0xFF) << 16) |
        ((bytes[3] & 0xFF) << 24);
  }

  static bool _listStartsWith(List<int> list, List<int> prefix) {
    if (list.length < prefix.length) return false;
    for (int i = 0; i < prefix.length; i++) {
      if (list[i] != prefix[i]) return false;
    }
    return true;
  }

  static String _sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class _IsolateInitMessage {
  final NcmDecryptRequest request;
  final SendPort sendPort;

  const _IsolateInitMessage(this.request, this.sendPort);
}

void _isolateEntry(_IsolateInitMessage init) {
  try {
    final result = NcmDecryptor.decryptSynchronous(
      init.request,
      onProgress: (progress) => init.sendPort.send(progress),
    );
    init.sendPort.send(result);
  } catch (e) {
    init.sendPort.send(e.toString());
  }
}
