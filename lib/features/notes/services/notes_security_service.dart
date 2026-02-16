import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;

class NotesSecurityService {
  final LocalAuthentication auth = LocalAuthentication();

  Future<bool> authenticate() async {
    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (!canAuthenticate) {
        return false;
      }

      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Please authenticate to access this note',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow PIN/Passcode backup
        ),
      );
      
      return didAuthenticate;
    } on PlatformException catch (e) {
      if (e.code == auth_error.notAvailable) {
        // Handle not available
      } else if (e.code == auth_error.notEnrolled) {
        // Handle not enrolled
      }
      return false;
    }
  }
}
