class AppConstants {
  // App info
  static const String appName = 'Dayflower';
  static const String appVersion = '1.0.0 · MVP';
  static const String tagline = 'Connecting hearts, one flower at a time.';

  // Pair invite
  static const int pairCodeLength = 6;
  static const int pairCodeExpiryHours = 48;

  // Streak
  static const int streakGracePeriodHours = 26; // slight buffer past midnight

  // Tulip
  static const int maxNoteLength = 200;

  // Storage buckets
  static const String bucketTulips    = 'tulips';
  static const String bucketBooth     = 'booth';
  static const String bucketAvatars   = 'avatars';
  static const String bucketCommunity = 'community';

  /// Public bucket holding the sideload APKs and their `latest.json`
  /// manifest. See lib/features/updates/ and tool/publish_update.dart.
  static const String bucketBuilds    = 'app-builds';

  // Realtime channels
  static const String channelHeartbeat = 'heartbeats';
  static const String channelTulip     = 'tulips';
}