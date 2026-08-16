import 'package:teigi/core/models/format_definitions.dart';

const _subtitleExts = {'srt', 'ass', 'ssa', 'vtt', 'sub', 'idx'};
const _documentExts = {'pdf', 'doc', 'docx', 'txt', 'rtf'};
const _extraVideo = {
  'mpeg',
  'mpg',
  'm4v',
  'ts',
  'm2ts',
  'flv',
  'wmv',
  '3gp',
  'asf',
  'vob',
};
const _extraAudio = {
  'aiff',
  'aif',
  'ape',
  'alac',
  'ac3',
  'amr',
  'mka',
  'oga',
  'wma',
};
const _extraImage = {'jpeg', 'gif', 'tif', 'heic', 'heif', 'jxl', 'ico'};

/// Infer [MediaType] from a file extension (no ffprobe).
MediaType inferMediaType(String extension) {
  final ext = extension.toLowerCase().replaceFirst('.', '');
  if (ext.isEmpty) return MediaType.unknown;

  final builtin = findBuiltinFormat(ext);
  if (builtin != null) return builtin.type;

  if (_extraVideo.contains(ext)) return MediaType.video;
  if (_extraAudio.contains(ext)) return MediaType.audio;
  if (_extraImage.contains(ext)) return MediaType.image;
  if (_subtitleExts.contains(ext)) return MediaType.subtitle;
  if (_documentExts.contains(ext)) return MediaType.document;
  return MediaType.unknown;
}

/// Icon used when no thumbnail is available.
MediaType mediaTypeForPath(String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0 || dot == path.length - 1) return MediaType.unknown;
  return inferMediaType(path.substring(dot + 1));
}
