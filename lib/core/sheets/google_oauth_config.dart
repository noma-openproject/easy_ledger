import 'dart:io';

class GoogleOAuthConfig {
  static const macosClientId =
      '174856304443-bv95hceudjf26td145c0sf0nia0j2umj.apps.googleusercontent.com';
  static const androidClientId =
      '174856304443-pleivot5l2oo3c1sf3s13583n8i6q2f4.apps.googleusercontent.com';
  static const windowsClientId =
      '174856304443-6n6vtguc0dv9rt38c13gf693j696li77.apps.googleusercontent.com';
  static const macosReversedClientId =
      'com.googleusercontent.apps.174856304443-bv95hceudjf26td145c0sf0nia0j2umj';

  static String? get clientId {
    if (Platform.isMacOS) return macosClientId;
    if (Platform.isAndroid) return androidClientId;
    if (Platform.isWindows) return windowsClientId;
    return null;
  }
}
