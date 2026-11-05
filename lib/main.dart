import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:attendance_app/ui/attendance_design.dart';
import 'package:attendance_app/ui/navigation_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Android reads its Firebase configuration from google-services.json.
  // A Firebase web app must be registered separately and configured with
  // FirebaseOptions; this project does not have those web options yet.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await Firebase.initializeApp();
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
