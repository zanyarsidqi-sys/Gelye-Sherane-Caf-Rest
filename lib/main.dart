import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/cafe_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  const expectedProjectRef = String.fromEnvironment('SUPABASE_EXPECTED_PROJECT_REF');

  // Fail closed if the build URL does not match its explicitly approved project.
  // Configure an independent expected project ref for each application build.
  final parsedUrl = Uri.tryParse(supabaseUrl);
  final refIsValid = RegExp(r'^[a-z0-9]{20}$').hasMatch(expectedProjectRef);
  final endpointIsValid = parsedUrl != null &&
      parsedUrl.scheme == 'https' &&
      parsedUrl.userInfo.isEmpty &&
      parsedUrl.port == 443 &&
      parsedUrl.host == '$expectedProjectRef.supabase.co' &&
      (parsedUrl.path.isEmpty || parsedUrl.path == '/') &&
      parsedUrl.query.isEmpty &&
      parsedUrl.fragment.isEmpty;

  if (supabaseKey.isEmpty || !refIsValid || !endpointIsValid) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Supabase configuration invalid.\n'
              'Check this app’s approved project identity and public key.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
    return;
  }

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseKey,
    );
  } catch (_) {
    // Never start the management UI if authentication initialization fails.
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Secure connection initialization failed. Management access is locked.'),
          ),
        ),
      ),
    );
    return;
  }

  runApp(const CafeApp());
}
