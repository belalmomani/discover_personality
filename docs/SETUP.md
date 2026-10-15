# الإعداد من الهاتف

1. أنشئ مستودعًا جديدًا على GitHub (تطبيق GitHub أو المتصفح).
2. فك ضغط ملف ZIP وارفع كل محتوياته إلى جذر المستودع (من المتصفح: Add file ← Upload files؛ تأكد من رفع المجلد المخفي `.github`، وإن لم يظهر فأنشئ الملف `.github/workflows/android-build.yml` يدويًا بنسخ محتواه).
3. (اختياري) أضف الأسرار: Settings ← Secrets and variables ← Actions:
   `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `AI_PROXY_URL`, `STARTIO_APP_ID`. كلها اختيارية للنسخة الأساسية.
4. تبويب Actions ← **Android build** ← Run workflow.
5. بعد النجاح افتح التشغيل ← قسم Artifacts ← نزّل `discover-personality-apk` ← فك الضغط ← ثبّت `app-release.apk` (اسمح بالتثبيت من مصدر غير معروف).

لا يحتوي المشروع على مجلد `android/`: يولّده الـ workflow آليًا (`flutter create`) ثم يعدّل `AndroidManifest.xml` عبر `tool/patch_android.py`.
