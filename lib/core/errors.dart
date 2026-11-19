// Error hierarchy. THIS FILE IS A SHARED CONTRACT.
//
// Every user-visible failure is a [KatibException] whose [messageAr] can be
// shown directly in the UI. [debugDetails] is for logs only.

class KatibException implements Exception {
  const KatibException(this.messageAr, {this.debugDetails, this.cause});

  /// Arabic, user-facing message.
  final String messageAr;
  final String? debugDetails;
  final Object? cause;

  @override
  String toString() =>
      '$runtimeType: $messageAr${debugDetails == null ? '' : ' ($debugDetails)'}';
}

/// Microphone permission denied or capture device unavailable.
class AudioCaptureException extends KatibException {
  const AudioCaptureException(super.messageAr, {super.debugDetails, super.cause});
}

/// A required on-device model is missing, corrupt, or failed to download.
class ModelException extends KatibException {
  const ModelException(super.messageAr, {super.debugDetails, super.cause});
}

/// Speech recognition failed (on-device or cloud).
class AsrException extends KatibException {
  const AsrException(super.messageAr, {super.debugDetails, super.cause});
}

/// Missing or invalid API key for a cloud service.
class MissingApiKeyException extends KatibException {
  const MissingApiKeyException(super.messageAr, {super.debugDetails, super.cause});
}

/// Claude API / network failure while generating minutes.
class MinutesGenerationException extends KatibException {
  const MinutesGenerationException(super.messageAr,
      {super.debugDetails, super.cause, this.retryable = false});

  /// True for transient failures (429, 5xx, network) worth retrying.
  final bool retryable;
}
