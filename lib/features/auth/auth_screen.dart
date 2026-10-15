import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/providers.dart';
import '../../app/widgets.dart';

/// Optional account screen. The assessment never requires signing in.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final pass = _password.text;
    if (!email.contains('@') || pass.length < 6) {
      setState(() => _error = 'أدخل بريدًا صحيحًا وكلمة مرور من 6 أحرف على الأقل.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = Supabase.instance.client.auth;
      if (_signUp) {
        final res = await auth.signUp(email: email, password: pass);
        if (res.session == null) {
          if (mounted) {
            setState(() => _error = 'تم إنشاء الحساب. قد تحتاج إلى تأكيد بريدك الإلكتروني قبل تسجيل الدخول.');
          }
          return;
        }
      } else {
        await auth.signInWithPassword(email: email, password: pass);
      }
      // Push any results that were waiting for an account.
      final ids = await ref.read(syncServiceProvider).syncResults(ref.read(historyProvider));
      await ref.read(historyProvider.notifier).markSynced(ids);
      for (final p in ref.read(plansProvider).values) {
        await ref.read(syncServiceProvider).syncPlan(p);
      }
      if (mounted) Navigator.of(context).pop();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = 'تعذر إكمال العملية: ${e.message}');
    } catch (_) {
      if (mounted) setState(() => _error = 'تحقق من اتصالك بالإنترنت وحاول مجددًا.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configured = ref.watch(cloudApiProvider).isConfigured;
    return Scaffold(
      appBar: AppBar(title: Text(_signUp ? 'إنشاء حساب' : 'تسجيل الدخول')),
      body: SafeArea(
        child: !configured
            ? const EmptyView(
                icon: Icons.cloud_off_outlined,
                message: 'المزامنة السحابية غير مفعّلة في هذه النسخة. يعمل التطبيق بالكامل دون حساب.',
              )
            : ListView(padding: const EdgeInsets.all(16), children: [
                const Text('الحساب اختياري؛ يتيح مزامنة نتائجك وخطتك بين أجهزتك. الاختبار يعمل دونه.'),
                const SizedBox(height: 16),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'البريد الإلكتروني', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(labelText: 'كلمة المرور', border: OutlineInputBorder()),
                ),
                if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_signUp ? 'إنشاء الحساب' : 'تسجيل الدخول'),
                ),
                TextButton(
                  onPressed: _busy ? null : () => setState(() => _signUp = !_signUp),
                  child: Text(_signUp ? 'لدي حساب بالفعل' : 'ليس لدي حساب'),
                ),
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('المتابعة دون حساب')),
              ]),
      ),
    );
  }
}
