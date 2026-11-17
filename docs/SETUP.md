# الإعداد من الهاتف

1. أنشئ مستودعًا جديدًا على GitHub (تطبيق GitHub أو المتصفح).
2. فك ضغط ملف ZIP وارفع كل محتوياته إلى جذر المستودع (من المتصفح: Add file ← Upload files؛ تأكد من رفع المجلد المخفي `.github`، وإن لم يظهر فأنشئ الملف `.github/workflows/android-build.yml` يدويًا بنسخ محتواه).
3. (اختياري) أضف الأسرار: Settings ← Secrets and variables ← Actions:
   الأسرار: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `AI_PROXY_URL`, `STARTIO_APP_ID`, وأسرار التوقيع. وفي تبويب **Variables**: `CONTACT_EMAIL` و`ADS_ENABLED` (افتراضي true) و`STARTIO_TEST_MODE` (افتراضي true). للنشر على Google Play اقرأ `docs/PLAY_STORE.md`.
4. تبويب Actions ← **Android build** ← Run workflow.
5. بعد النجاح افتح التشغيل ← قسم Artifacts ← نزّل `discover-personality-release` ← فك الضغط ← ثبّت `app-release.apk` (وملف `app-release.aab` هو ما يُرفع إلى Google Play) (اسمح بالتثبيت من مصدر غير معروف).

لا يحتوي المشروع على مجلد `android/`: يولّده الـ workflow آليًا (`flutter create`) ثم يعدّل `AndroidManifest.xml` عبر `tool/patch_android.py`.
