# بناء APK سحابيًا

الـ workflow: `.github/workflows/android-build.yml` (Java 17، Flutter 3.27.4 مثبّت، ويرفع patch_android.py إصدار AGP إلى 8.7.3 وGradle إلى 8.9 وcompileSdk إلى 36 وminSdk إلى 23 وNDK إلى 27.0.12077973 وKotlin Gradle plugin إلى 2.3.0 لأن Start.io SDK 5.4.0 يتطلب ذلك): scaffold ← patch ← `pub get` ← format check ← analyze ← test ← `flutter build apk --release` ← رفع `build/app/outputs/flutter-apk/app-release.apk`.

ملاحظات صريحة:
- **لم يُنفَّذ البناء من قبل المؤلف** (بيئة بلا Flutter وبلا إنترنت). قد يحتاج التشغيل الأول إلى إصلاحات صغيرة؛ أرسل سجل الخطأ.
- خطوة `dart format` غير مانعة لأن الكود كُتب دون تشغيل المنسّق. شغّل `dart format .` محليًا أو اجعل الخطوة مانعة بحذف `continue-on-error`.
- `flutter analyze --no-fatal-infos`: التحذيرات تُفشل البناء، والملاحظات (info) لا.
- APK موقّع بمفتاح debug الافتراضي: يصلح للتجربة فقط. للنشر في Google Play أنشئ keystore وخزّنه في Secrets وابنِ AAB.
- خطر معروف: إن فشل Gradle بخطأ `Namespace not specified` من `startapp_sdk` (إصدار 1.0.1 صدر مايو 2024)، أضف namespace للمكتبة أو حدّث الحزمة، أو أزل الحزمة مؤقتًا مع `lib/data/ads/startio_backend.dart` ودالة المصنع في `providers.dart`.

## التوقيع (Release signing)
- الـ workflow يوقّع بمفتاح الإصدار إن وُجد السران `ANDROID_KEYSTORE_BASE64` و`ANDROID_KEYSTORE_PASSWORD` في GitHub Secrets، وإلا يستخدم مفتاح debug.
- alias المفتاح: `upload`، وكلمة مرور المخزن والمفتاح واحدة.
- **احتفظ بنسخة احتياطية من ملف .jks وكلمة المرور في مكان آمن، ولا ترفعهما إلى GitHub.** فقدانهما يمنع تحديث التطبيق بنفس التوقيع.
- الـ package name: `app.discover.discover_personality`.

## تنزيل APK مباشرة (بدون ZIP)
بعد كل بناء ناجح يُنشأ **Release** باسم `Build N` في تبويب Releases يحتوي ملف `app-release.apk` مباشرة. هذا أسهل من ZIP الخاص بـ Artifacts على الهاتف.
