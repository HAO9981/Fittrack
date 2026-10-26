import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kDebugMode, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'src/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebaseOptions = DefaultFirebaseOptions.currentPlatform;
  developer.log(
    'Initializing Firebase for project ${firebaseOptions.projectId}.',
    name: 'FitTrack.Startup',
  );
  await Firebase.initializeApp(options: firebaseOptions);
  developer.log('Firebase initialized.', name: 'FitTrack.Startup');

  WebProvider? webProvider;
  if (kIsWeb) {
    if (kDebugMode) {
      webProvider = WebDebugProvider();
    } else {
      const siteKey = String.fromEnvironment('APP_CHECK_RECAPTCHA_V3_SITE_KEY');
      if (siteKey.isNotEmpty) webProvider = ReCaptchaV3Provider(siteKey);
    }
  }

  final nativeProviderSupported =
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
  const windowsDebugToken = String.fromEnvironment(
    'APP_CHECK_WINDOWS_DEBUG_TOKEN',
  );
  final hasWindowsDebugToken =
      defaultTargetPlatform == TargetPlatform.windows &&
      kDebugMode &&
      windowsDebugToken.isNotEmpty;

  if ((kIsWeb && webProvider != null) ||
      (!kIsWeb && nativeProviderSupported) ||
      hasWindowsDebugToken) {
    developer.log(
      'Activating Firebase App Check before starting the app.',
      name: 'FitTrack.Startup',
    );
    await FirebaseAppCheck.instance.activate(
      providerWeb: webProvider,
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
      providerWindows: hasWindowsDebugToken
          ? WindowsDebugProvider(debugToken: windowsDebugToken)
          : const WindowsDebugProvider(),
    );
    developer.log('Firebase App Check activated.', name: 'FitTrack.Startup');
  } else {
    debugPrint(
      kIsWeb
          ? 'Firebase App Check for web is not configured. '
                'Set APP_CHECK_RECAPTCHA_V3_SITE_KEY for release builds.'
          : 'Firebase App Check is not configured for this platform. '
                'Windows debug builds require APP_CHECK_WINDOWS_DEBUG_TOKEN.',
    );
  }

  runApp(const App());
}
