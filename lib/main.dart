import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/config.dart';
import 'data/models/extra_test.dart';
import 'data/models/question.dart';
import 'data/repositories/question_repository.dart';
import 'data/social/social_api.dart';
import 'data/supabase/cloud_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  final QuestionBank bank;
  try {
    bank = await QuestionRepository.loadFromAsset();
  } catch (e) {
    runApp(MaterialApp(
      locale: const Locale('ar'),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: Center(child: Text('تعذر تحميل بنك الأسئلة: $e'))),
      ),
    ));
    return;
  }

  // Additional tests are optional: if the asset fails to load the profile page just hides them.
  var extraTests = <ExtraTest>[];
  try {
    extraTests = await ExtraTestRepository.loadFromAsset();
  } catch (e) {
    debugPrint('Extra tests failed to load: $e');
  }

  // Supabase is optional: any failure leaves the app fully usable offline.
  CloudApi cloud = NoCloudApi();
  if (AppConfig.supabaseConfigured) {
    try {
      await Supabase.initialize(url: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseAnonKey);
      cloud = SupabaseCloudApi();
    } catch (e) {
      debugPrint('Supabase init failed, continuing offline: $e');
    }
  }

  runApp(ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      questionBankProvider.overrideWithValue(bank),
      extraTestsProvider.overrideWithValue(extraTests),
      cloudApiProvider.overrideWithValue(cloud),
      socialApiProvider.overrideWithValue(cloud.isConfigured ? SupabaseSocialApi() : NoSocialApi()),
    ],
    child: const App(),
  ));
}
