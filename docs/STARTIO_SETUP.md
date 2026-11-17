# تفعيل Start.io مستقبلًا

الحزمة: `startapp_sdk ^1.0.1` (Flutter، Android وiOS، تدعم Banner وInterstitial وRewarded وNative) حسب https://pub.dev/packages/startapp_sdk.

الحالة الافتراضية الآن: **مفعّلة بوضع الاختبار** (`ADS_ENABLED=true` و`STARTIO_TEST_MODE=true` عبر متغيرات GitHub). لا يُحمَّل أي إعلان قبل موافقة المستخدم في نافذة أول تشغيل. لإيقافها كليًا اجعل المتغير `ADS_ENABLED=false`.

## ما تفعله أنت
1. أنشئ تطبيقك في بوابة Start.io وانسخ **App ID**.
2. ضعه في GitHub Secret باسم `STARTIO_APP_ID` (يحقنه `tool/patch_android.py` في `AndroidManifest.xml` كـ `com.startapp.sdk.APPLICATION_ID`). حتى تضعه يُستخدم المعرّف الافتراضي أدناه (تحذّر الخطوة «Release checklist warnings»).
3. المفاتيح تُضبط من GitHub ← Settings ← Secrets and variables ← Actions ← **Variables**: `ADS_ENABLED` و`STARTIO_TEST_MODE` (اجعله `false` فقط للإنتاج بعد التأكد من ظهور إعلانات الاختبار).
4. عند أول تشغيل تظهر نافذة موافقة (أوافق / لا أوافق)، ويمكن تغييرها لاحقًا من الإعدادات ← الإعلانات. سياسة الخصوصية محدّثة لتذكر Start.io.

## ملاحظات
- لا توجد في إضافة Flutter معرّفات وحدات إعلانية (ad unit IDs) في الكود؛ المطلوب App ID فقط وadTag اختياري. لذلك لا يوجد ملف لمعرفات الوحدات، وفصل الاختبار عن الإنتاج يتم بـ `setTestAdsEnabled`.
- المواضع: Banner في الرئيسية والنتائج، وInterstitial عند مغادرة شاشة النتائج فقط (حد أقصى 2 للجلسة وبفارق 3 دقائق). لا إعلانات أثناء الأسئلة (يفرضها `AdService` ويختبرها `test/unit/ad_service_test.dart`).
- نافذة الموافقة البسيطة موجودة، لكن منصة موافقة معتمدة (UMP/GDPR) **غير مُنفّذة**: راجعها إن استهدفت أوروبا. نماذج Google Play (Data safety وغيرها) في `docs/PLAY_STORE.md`.
- لم تُجرَّب الإعلانات على جهاز. الإعدادات الاختيارية Return/Splash ads معطلة في الـ manifest.

## App ID الحالي
`210949713` هو معرّف تطبيقك ومكتوب افتراضيًا في `tool/patch_android.py` (المعرّف ليس سريًا لأنه يظهر داخل الـ APK). يمكن تجاوزه بسر `STARTIO_APP_ID`.
التفعيل والإيقاف وبدء الإنتاج كلها عبر متغيرات GitHub (انظر أعلاه)، دون تعديل الـ workflow.
