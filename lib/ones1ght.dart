/// OneS1ght indoor location intelligence SDK for Flutter.
///
/// Wraps the OneS1ght iOS and Android SDKs. Start with [OneS1ght.initialize].
library;

export 'src/errors.dart' show OneS1ghtException;
export 'src/floor_session.dart' show FloorSession;
export 'src/models.dart' hide decodeList, decodeStringMap;
export 'src/ones1ght.dart' show OneS1ght;
