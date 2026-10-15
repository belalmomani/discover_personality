# تفعيل Start.io مستقبلًا

الحزمة: `startapp_sdk ^1.0.1` (Flutter، Android وiOS، تدعم Banner وInterstitial وRewarded وNative) حسب https://pub.dev/packages/startapp_sdk.

الحالة الافتراضية: **معطلة** (`ADS_ENABLED=false`). لا يُنشأ أي كائن إعلان، ولا يُطلب أي تحميل.

## ما تفعله أنت
1. أنشئ تطبيقك في بوابة Start.io وانسخ **App ID**.
2. ضعه في GitHub Secret باسم `STARTIO_APP_ID` (يحقنه `tool/patch_android.py` في `AndroidManifest.xml` كـ `com.startapp.sdk.APPLICATION_ID`). حتى تضعه يُستخدم نص بديل `YOUR_STARTIO_APP_ID`.
3. للتفعيل: غيّر في الـ workflow `--dart-define=ADS_ENABLED=true`. وضع الاختبار `STARTIO_TEST_MODE=true` افتراضي؛ اجعله `false` فقط للإنتاج.
4. لن يرى المستخدم إعلانات إلا بعد تفعيله مفتاح «السماح بعرض الإعلانات» في الإعدادات (يظهر فقط حين `ADS_ENABLED=true`).

## ملاحظات
- لا توجد في إضافة Flutter معرّفات وحدات إعلانية (ad unit IDs) في الكود؛ المطلوب App ID فقط وadTag اختياري. لذلك لا يوجد ملف لمعرفات الوحدات، وفصل الاختبار عن الإنتاج يتم بـ `setTestAdsEnabled`.
- المواضع: Banner في الرئيسية والنتائج، وInterstitial عند مغادرة شاشة النتائج فقط (حد أقصى 2 للجلسة وبفارق 3 دقائق). لا إعلانات أثناء الأسئلة (يفرضها `AdService` ويختبرها `test/unit/ad_service_test.dart`).
- إدارة الموافقة الإعلانية (GDPR/UMP وغيرها) ومتطلبات Google Play (Data safety، سياسة الخصوصية) **لم تُنفذ** وعليك مراجعتها قبل التفعيل؛ عدّل سياسة الخصوصية.
- لم تُجرَّب الإعلانات على جهاز. الإعدادات الاختيارية Return/Splash ads معطلة في الـ manifest.
