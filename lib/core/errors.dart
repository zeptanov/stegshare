/// Base class for all STEGSHARE domain errors. All subclasses are plain data
/// (String fields only) so they can cross isolate boundaries.
class StegShareException implements Exception {
  final String message;
  const StegShareException(this.message);
  @override
  String toString() => '$runtimeType: $message';
}

class ContainerFormatException extends StegShareException {
  const ContainerFormatException(super.message);
}

class DecryptionException extends StegShareException {
  const DecryptionException(super.message);
}

class PasswordRequiredException extends StegShareException {
  const PasswordRequiredException() : super('This container is password protected.');
}

class PrivateKeyRequiredException extends StegShareException {
  const PrivateKeyRequiredException()
      : super('This container is encrypted for a public key; a private key is required.');
}

class NotForThisRecipientException extends StegShareException {
  const NotForThisRecipientException()
      : super('This container was not encrypted for your key.');
}

class CapacityException extends StegShareException {
  const CapacityException(super.message);
}

class NoContainerFoundException extends StegShareException {
  const NoContainerFoundException()
      : super('No STEGSHARE container found in this image (or wrong scatter key).');
}

class UnsafeInputException extends StegShareException {
  const UnsafeInputException(super.message);
}

class CancelledException extends StegShareException {
  const CancelledException() : super('Operation cancelled.');
}