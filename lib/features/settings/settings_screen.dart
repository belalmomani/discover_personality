import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/providers.dart';
import '../../app/widgets.dart';
import '../../core/config.dart';
import '../auth/auth_screen.dart';
import '../help/help_screen.dart';
import '../privacy/privacy_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<bool> _confirm(BuildContext context, String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('تأكيد')),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final cloud = ref.watch(cloudApiProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات والخصوصية')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          SectionCard(
            title: 'المظهر',
            icon: Icons.brightness_6_outlined,
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('النظام')),
                ButtonSegment(value: ThemeMode.light, label: Text('فاتح')),
                ButtonSegment(value: ThemeMode.dark, label: Text('داكن')),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) => notifier.setTheme(s.first),
            ),
          ),
          SectionCard(
            title: 'الحساب والمزامنة (اختياري)',
            icon: Icons.cloud_outlined,
            child: !cloud.isConfigured
                ? const Text('المزامنة السحابية غير مُعدّة في هذه النسخة. بياناتك محفوظة على جهازك فقط.')
                : StreamBuilder<AuthState>(
                    stream: Supabase.instance.client.auth.onAuthStateChange,
                    builder: (context, _) {
                      final user = Supabase.instance.client.auth.currentUser;
                      if (user == null) {
                        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('غير مسجّل الدخول. نتائجك على جهازك فقط.'),
                          const SizedBox(height: 8),
                          FilledButton(onPressed: () => pushScreen(context, const AuthScreen()), child: const Text('تسجيل الدخول / إنشاء حساب')),
                        ]);
                      }
                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('مسجّل الدخول: ${user.email ?? ""}'),
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, children: [
                          OutlinedButton(
                            onPressed: () async {
                              final ids = await ref.read(syncServiceProvider).syncResults(ref.read(historyProvider));
                              await ref.read(historyProvider.notifier).markSynced(ids);
                              if (context.mounted) showMessage(context, ids.isEmpty ? 'لا توجد عناصر جديدة للمزامنة أو تعذرت المزامنة.' : 'تمت مزامنة ${ids.length} نتيجة.');
                            },
                            child: const Text('مزامنة الآن'),
                          ),
                          OutlinedButton(onPressed: () => Supabase.instance.client.auth.signOut(), child: const Text('تسجيل الخروج')),
                          TextButton(
                            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                            onPressed: () async {
                              if (!await _confirm(context, 'حذف الحساب؟', 'سيُحذف حسابك وكل بياناتك السحابية نهائيًا. تبقى بياناتك المحلية على الجهاز حتى تحذفها.')) return;
                              try {
                                await cloud.deleteAccount();
                                if (context.mounted) showMessage(context, 'تم حذف الحساب وبياناته السحابية.');
                              } catch (_) {
                                if (context.mounted) showMessage(context, 'تعذر حذف الحساب. تحقق من الاتصال وأنك نفّذت ملف SQL كاملًا.');
                              }
                            },
                            child: const Text('حذف الحساب وبياناته'),
                          ),
                        ]),
                      ]);
                    },
                  ),
          ),
          if (AppConfig.aiConfigured)
            SectionCard(
              title: 'الذكاء الاصطناعي (اختياري)',
              icon: Icons.smart_toy_outlined,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('السماح بإرسال ملخص الدرجات لتفسير إضافي'),
                subtitle: const Text('لا تُرسل الإجابات الخام ولا بيانات شخصية.'),
                value: settings.aiConsent,
                onChanged: notifier.setAiConsent,
              ),
            ),
          if (AppConfig.adsEnabled)
            SectionCard(
              title: 'الإعلانات',
              icon: Icons.campaign_outlined,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('السماح بعرض الإعلانات'),
                subtitle: const Text('لا تظهر إعلانات أثناء الاختبار، ولا تمنع الوصول إلى نتائجك.'),
                value: settings.adsConsent,
                onChanged: notifier.setAdsConsent,
              ),
            ),
          SectionCard(
            title: 'بياناتك',
            icon: Icons.delete_outline,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('حذف كل إجابات الاختبار والنتائج والخطط والاختبارات الإضافية وتاريخ الميلاد من هذا الجهاز.'),
              const SizedBox(height: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                onPressed: () async {
                  if (!await _confirm(context, 'حذف بيانات الجهاز؟', 'لا يمكن التراجع. لن يتأثر حسابك السحابي إن وُجد.')) return;
                  await ref.read(assessmentProvider.notifier).restart();
                  await ref.read(historyProvider.notifier).clear();
                  await ref.read(plansProvider.notifier).clear();
                  await ref.read(extraResultsProvider.notifier).clear();
                  await ref.read(profileProvider.notifier).clear();
                  await ref.read(observersProvider.notifier).clear();
                  if (context.mounted) showMessage(context, 'تم حذف بيانات الجهاز.');
                },
                child: const Text('حذف بيانات الاختبار من الجهاز'),
              ),
            ]),
          ),
          Card(child: ListTile(leading: const Icon(Icons.privacy_tip_outlined), title: const Text('سياسة الخصوصية'), onTap: () => pushScreen(context, const PrivacyScreen()))),
          Card(child: ListTile(leading: const Icon(Icons.help_outline), title: const Text('المساعدة وإخلاء المسؤولية'), onTap: () => pushScreen(context, const HelpScreen()))),
        ]),
      ),
    );
  }
}
