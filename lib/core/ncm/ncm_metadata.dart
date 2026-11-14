import 'dart:convert';
import 'dart:typed_data';

/// Parsed metadata from NCM JSON envelope.
class NcmMetadata {
  final String? musicId;
  final String musicName;
  final List<String> artists;
  final String album;
  final String? albumPicUrl;
  final String format;
  final int? bitrate;
  final int? duration;
  final Map<String, dynamic> raw;

  const NcmMetadata({
    this.musicId,
    required this.musicName,
    required this.artists,
    required this.album,
    this.albumPicUrl,
    required this.format,
    this.bitrate,
    this.duration,
    this.raw = const {},
  });

  String get artistDisplay => artists.isEmpty ? '' : artists.join(' / ');

  static NcmMetadata? fromJsonString(String jsonStr) {
    try {
      final decoded = json.decode(jsonStr);
      if (decoded is! Map<String, dynamic>) return null;

      final name = decoded['musicName']?.toString() ?? '';
      final album = decoded['album']?.toString() ?? '';
      final format = decoded['format']?.toString().toLowerCase() ?? 'mp3';
      final picUrl = decoded['albumPic']?.toString();
      final id = decoded['musicId']?.toString();
      final bitrate = decoded['bitrate'] is num ? (decoded['bitrate'] as num).toInt() : null;
      final duration = decoded['duration'] is num ? (decoded['duration'] as num).toInt() : null;

      final artistList = <String>[];
      final rawArtists = decoded['artist'];
      if (rawArtists is List) {
        for (final item in rawArtists) {
          if (item is List && item.isNotEmpty && item.first != null) {
            final aName = item.first.toString().trim();
            if (aName.isNotEmpty) artistList.add(aName);
          } else if (item is String && item.trim().isNotEmpty) {
            artistList.add(item.trim());
          }
        }
      }

      return NcmMetadata(
        musicId: id,
        musicName: name,
        artists: artistList,
        album: album,
        albumPicUrl: picUrl,
        format: format,
        bitrate: bitrate,
        duration: duration,
        raw: decoded,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Helper for building and writing audio tags (ID3v2 for MP3, Vorbis/Picture for FLAC).
class NcmTagWriter {
  /// Builds a complete ID3v2.3 tag header and frame block.
  static Uint8List buildId3v2Tag({
    required String title,
    required String artist,
    required String album,
    Uint8List? coverBytes,
  }) {
    final frameBytes = BytesBuilder();

    // TIT2: Title
    if (title.isNotEmpty) {
      _appendId3Frame(frameBytes, 'TIT2', _encodeTextUtf8(title));
    }

    // TPE1: Artist
    if (artist.isNotEmpty) {
      _appendId3Frame(frameBytes, 'TPE1', _encodeTextUtf8(artist));
    }

    // TALB: Album
    if (album.isNotEmpty) {
      _appendId3Frame(frameBytes, 'TALB', _encodeTextUtf8(album));
    }

    // APIC: Attached Picture (Cover)
    if (coverBytes != null && coverBytes.isNotEmpty) {
      final isPng = coverBytes.length > 8 &&
          coverBytes[0] == 0x89 &&
          coverBytes[1] == 0x50 &&
          coverBytes[2] == 0x4E &&
          coverBytes[3] == 0x47;
      final mime = isPng ? 'image/png' : 'image/jpeg';
      final mimeBytes = latin1.encode(mime);

      final apicBuilder = BytesBuilder();
      apicBuilder.addByte(0x00); // Text encoding: ISO-8859-1
      apicBuilder.add(mimeBytes);
      apicBuilder.addByte(0x00); // Null terminator for MIME
      apicBuilder.addByte(0x03); // Picture type: Cover (front)
      apicBuilder.addByte(0x00); // Description (empty string null terminator)
      apicBuilder.add(coverBytes);

      _appendId3Frame(frameBytes, 'APIC', apicBuilder.toBytes());
    }

    final payload = frameBytes.toBytes();
    final header = Uint8List(10);
    // "ID3"
    header[0] = 0x49;
    header[1] = 0x44;
    header[2] = 0x33;
    // Version 2.3.0
    header[3] = 0x03;
    header[4] = 0x00;
    // Flags
    header[5] = 0x00;
    // Syncsafe size (7-bit per byte)
    final size = payload.length;
    header[6] = (size >> 21) & 0x7F;
    header[7] = (size >> 14) & 0x7F;
    header[8] = (size >> 7) & 0x7F;
    header[9] = size & 0x7F;

    final fullTag = BytesBuilder();
    fullTag.add(header);
    fullTag.add(payload);
    return fullTag.toBytes();
  }

  static void _appendId3Frame(BytesBuilder bb, String frameId, Uint8List data) {
    if (data.isEmpty) return;
    final idBytes = ascii.encode(frameId);
    bb.add(idBytes);

    // Frame size (32-bit big endian in ID3v2.3)
    final size = data.length;
    bb.addByte((size >> 24) & 0xFF);
    bb.addByte((size >> 16) & 0xFF);
    bb.addByte((size >> 8) & 0xFF);
    bb.addByte(size & 0xFF);

    // Flags (2 bytes)
    bb.addByte(0x00);
    bb.addByte(0x00);

    // Frame payload
    bb.add(data);
  }

  static Uint8List _encodeTextUtf8(String text) {
    final bb = BytesBuilder();
    // 0x03 = UTF-8 encoding flag in ID3v2.4 / supported by modern players in 2.3
    bb.addByte(0x03);
    bb.add(utf8.encode(text));
    return bb.toBytes();
  }

  /// Injects a PICTURE metadata block into a FLAC stream if not already present.
  static Uint8List injectFlacCover(Uint8List flacBytes, Uint8List coverBytes) {
    if (flacBytes.length < 4 ||
        flacBytes[0] != 0x66 ||
        flacBytes[1] != 0x4C ||
        flacBytes[2] != 0x61 ||
        flacBytes[3] != 0x43) {
      return flacBytes; // Not valid FLAC stream
    }

    // Build FLAC PICTURE block (type 6)
    final isPng = coverBytes.length > 8 &&
        coverBytes[0] == 0x89 &&
        coverBytes[1] == 0x50 &&
        coverBytes[2] == 0x4E &&
        coverBytes[3] == 0x47;
    final mime = isPng ? 'image/png' : 'image/jpeg';
    final mimeBytes = ascii.encode(mime);

    final picBlock = BytesBuilder();
    // 1. Picture type: 3 (Cover front) 4 bytes
    _writeUint32(picBlock, 3);
    // 2. MIME type string length + MIME bytes
    _writeUint32(picBlock, mimeBytes.length);
    picBlock.add(mimeBytes);
    // 3. Description length (0)
    _writeUint32(picBlock, 0);
    // 4. Width (0)
    _writeUint32(picBlock, 0);
    // 5. Height (0)
    _writeUint32(picBlock, 0);
    // 6. Color depth (24)
    _writeUint32(picBlock, 24);
    // 7. Indexed colors (0)
    _writeUint32(picBlock, 0);
    // 8. Picture data length + picture bytes
    _writeUint32(picBlock, coverBytes.length);
    picBlock.add(coverBytes);

    final picPayload = picBlock.toBytes();
    final picHeader = Uint8List(4);
    // Type 6, not last block (bit 7 = 0)
    picHeader[0] = 6;
    picHeader[1] = (picPayload.length >> 16) & 0xFF;
    picHeader[2] = (picPayload.length >> 8) & 0xFF;
    picHeader[3] = picPayload.length & 0xFF;

    // Scan existing FLAC metadata blocks
    int offset = 4;
    while (offset + 4 <= flacBytes.length) {
      final headerByte = flacBytes[offset];
      final isLast = (headerByte & 0x80) != 0;
      final blockType = headerByte & 0x7F;
      final blockLen = (flacBytes[offset + 1] << 16) |
          (flacBytes[offset + 2] << 8) |
          flacBytes[offset + 3];

      if (blockType == 6) {
        // Picture block already present, no injection needed
        return flacBytes;
      }

      if (isLast) {
        // Change current block to not-last (clear bit 7)
        flacBytes[offset] = headerByte & 0x7F;
        // Make our new picture block the last block
        picHeader[0] = 6 | 0x80;

        final out = BytesBuilder();
        out.add(flacBytes.sublist(0, offset + 4 + blockLen));
        out.add(picHeader);
        out.add(picPayload);
        out.add(flacBytes.sublist(offset + 4 + blockLen));
        return out.toBytes();
      }

      offset += 4 + blockLen;
    }

    return flacBytes;
  }

  static void _writeUint32(BytesBuilder bb, int value) {
    bb.addByte((value >> 24) & 0xFF);
    bb.addByte((value >> 16) & 0xFF);
    bb.addByte((value >> 8) & 0xFF);
    bb.addByte(value & 0xFF);
  }
}
