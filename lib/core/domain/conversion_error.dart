/// Classified conversion failure. UI should show [message], not raw stderr.
enum ConversionErrorKind {
  ffmpegNotFound,
  invalidInput,
  unsupportedCodec,
  unsupportedFormat,
  permissionDenied,
  outputExists,
  diskFull,
  processCrashed,
  cancelled,
  missingTargetFormat,
  unknown,
}

class ConversionError {
  final ConversionErrorKind kind;
  final String message;
  final String? details;

  const ConversionError({
    required this.kind,
    required this.message,
    this.details,
  });

  factory ConversionError.missingTargetFormat() {
    return const ConversionError(
      kind: ConversionErrorKind.missingTargetFormat,
      message: 'No target format',
    );
  }

  factory ConversionError.fromExitCode(int code, {String? details}) {
    return ConversionError(
      kind: ConversionErrorKind.processCrashed,
      message: 'Conversion failed',
      details: details ?? 'ffmpeg exit code $code',
    );
  }

  factory ConversionError.unknown(Object error) {
    return ConversionError(
      kind: ConversionErrorKind.unknown,
      message: 'Conversion failed',
      details: error.toString(),
    );
  }

  factory ConversionError.fromFfmpeg({
    required int exitCode,
    required bool cancelled,
    String? error,
    String? stderr,
  }) {
    if (cancelled) {
      return ConversionError(
        kind: ConversionErrorKind.cancelled,
        message: 'Conversion cancelled',
        details: stderr ?? error,
      );
    }

    final combined = '${error ?? ''}\n${stderr ?? ''}'.toLowerCase();
    final kind = _classifyFfmpeg(combined);
    final details = (stderr != null && stderr.trim().isNotEmpty)
        ? stderr
        : (error ?? 'ffmpeg exit code $exitCode');
    return ConversionError(
      kind: kind,
      message: _messageFor(kind),
      details: details,
    );
  }

  static ConversionErrorKind _classifyFfmpeg(String text) {
    if (text.contains('no such file or directory') ||
        text.contains('invalid data found') ||
        text.contains('error opening input') ||
        text.contains('immediate exit requested')) {
      return ConversionErrorKind.invalidInput;
    }
    if (text.contains('permission denied') || text.contains('access denied')) {
      return ConversionErrorKind.permissionDenied;
    }
    if (text.contains('no space left on device') ||
        text.contains('disk full')) {
      return ConversionErrorKind.diskFull;
    }
    if (text.contains('unknown encoder') ||
        text.contains('could not find encoder') ||
        text.contains('invalid encoder type')) {
      return ConversionErrorKind.unsupportedCodec;
    }
    if (text.contains('unable to find a suitable output format') ||
        text.contains('requested output format') ||
        text.contains('extension not supported')) {
      return ConversionErrorKind.unsupportedFormat;
    }
    if (text.contains('already exists')) {
      return ConversionErrorKind.outputExists;
    }
    if (text.contains('ffmpeg 未就绪') || text.contains('ffmpeg not ready')) {
      return ConversionErrorKind.ffmpegNotFound;
    }
    return ConversionErrorKind.processCrashed;
  }

  static String _messageFor(ConversionErrorKind kind) {
    return switch (kind) {
      ConversionErrorKind.ffmpegNotFound => 'FFmpeg is not available',
      ConversionErrorKind.invalidInput => 'Input file could not be read',
      ConversionErrorKind.unsupportedCodec => 'Unsupported encoder or codec',
      ConversionErrorKind.unsupportedFormat => 'Unsupported output format',
      ConversionErrorKind.permissionDenied => 'Permission denied',
      ConversionErrorKind.outputExists => 'Output file already exists',
      ConversionErrorKind.diskFull => 'Not enough disk space',
      ConversionErrorKind.processCrashed => 'FFmpeg exited unexpectedly',
      ConversionErrorKind.cancelled => 'Conversion cancelled',
      ConversionErrorKind.missingTargetFormat => 'No target format',
      ConversionErrorKind.unknown => 'Conversion failed',
    };
  }
}
