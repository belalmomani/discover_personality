# إعداد Supabase

1. أنشئ مشروعًا في supabase.com.
2. SQL Editor ← الصق وشغّل `supabase/migrations/20260101000000_init.sql` ثم `supabase/seed.sql` (72 سؤالًا فقط، لا بيانات مستخدمين).
3. Project Settings ← API: انسخ **Project URL** و**anon public key**. لا تستخدم `service_role` في التطبيق أبدًا.
4. ضعهما في GitHub Secrets: `SUPABASE_URL` و`SUPABASE_ANON_KEY` (أو `--dart-define` محليًا).
5. Authentication ← Providers: فعّل Email. قرر تفعيل تأكيد البريد.
6. اختبار العزل (اختياري): شغّل `supabase/tests/rls_check.sql` ← يجب أن يعرض `RLS CHECK PASSED` ثم يتراجع عن كل شيء. **لم يُشغَّل من المؤلف.**
7. حذف الحساب يعتمد على الدالة `delete_my_account()` المضمنة في ملف الـ migration.
8. الذكاء الاصطناعي (اختياري): `supabase/functions/ai-explain` ← `supabase secrets set AI_API_KEY=... AI_MODEL=...` ← `supabase functions deploy ai-explain` ← ضع رابط الدالة في `AI_PROXY_URL`.

بدون هذه المفاتيح يعمل التطبيق كاملًا محليًا.
