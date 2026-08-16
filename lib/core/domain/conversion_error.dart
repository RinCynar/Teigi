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
}
