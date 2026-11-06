import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:attendance_app/ui/attendance_design.dart';
import 'package:attendance_app/ui/navigation_shell.dart';
import 'package:attendance_app/services/attendance_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Android reads its Firebase configuration from google-services.json.
  // A Firebase web app must be registered separately and configured with
  // FirebaseOptions; this project does not have those web options yet.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      unawaited(AttendanceStore.syncPendingRecords());
    } catch (e, stackTrace) {
      // The app can still use its local attendance store while Firebase is
      // unavailable. Pending records will be retried on a later launch.
      debugPrint('Firebase initialization failed: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance App',
      debugShowCheckedModeBanner: false,
      theme: AttendanceTheme.light,
      home: const MainNavigationShell(),
    );
  }
}
