# بناء APK سحابيًا

الـ workflow: `.github/workflows/android-build.yml` (Java 17، Flutter 3.27.4 مثبّت): scaffold ← patch ← `pub get` ← format check ← analyze ← test ← `flutter build apk --release` ← رفع `build/app/outputs/flutter-apk/app-release.apk`.

ملاحظات صريحة:
- **لم يُنفَّذ البناء من قبل المؤلف** (بيئة بلا Flutter وبلا إنترنت). قد يحتاج التشغيل الأول إلى إصلاحات صغيرة؛ أرسل سجل الخطأ.
- خطوة `dart format` غير مانعة لأن الكود كُتب دون تشغيل المنسّق. شغّل `dart format .` محليًا أو اجعل الخطوة مانعة بحذف `continue-on-error`.
- `flutter analyze --no-fatal-infos`: التحذيرات تُفشل البناء، والملاحظات (info) لا.
- APK موقّع بمفتاح debug الافتراضي: يصلح للتجربة فقط. للنشر في Google Play أنشئ keystore وخزّنه في Secrets وابنِ AAB.
- خطر معروف: إن فشل Gradle بخطأ `Namespace not specified` من `startapp_sdk` (إصدار 1.0.1 صدر مايو 2024)، أضف namespace للمكتبة أو حدّث الحزمة، أو أزل الحزمة مؤقتًا مع `lib/data/ads/startio_backend.dart` ودالة المصنع في `providers.dart`.
