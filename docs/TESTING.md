# الاختبارات

تشغيل: `flutter test`

| الملف | يغطي |
|---|---|
| unit/questions_test | 72 سؤالًا، 24/36/12، المعرفات، الأقطاب والأنماط والمحاور، العكسية |
| unit/scoring_test | معادلات MBTI/Enneagram/A-R-F-D، العكسي، التعادل والتقارب، التحقق، الحتمية |
| unit/local_store_test | حفظ/استعادة التقدم، بيانات تالفة، افتراضيات الموافقة |
| unit/assessment_notifier_test | منع النتيجة قبل الاكتمال، استعادة بعد إعادة التشغيل |
| unit/ad_service_test | التعطيل يمنع التحميل، فشل الإعلان لا يعطل، حظر الأسئلة، حدود الـ interstitial |
| unit/offline_sync_test | العمل دون إنترنت/Supabase، فشل الشبكة لا يرمي |
| unit/plan_report_test | الخطة، التقرير، عدم اختلاق التناقضات، حمولة AI بلا إجابات خام |
| widget/screens_test | RTL، الرئيسية دون طلب إعلان، تعطيل زر الحساب، شاشة السؤال |
| integration/flow_test | رحلة كاملة على مستوى الحالة (ليست اختبار جهاز) |
| supabase/tests/rls_check.sql | عزل RLS يدويًا في SQL Editor |

**لم يُشغَّل أي اختبار من المؤلف** (لا Flutter في بيئة الكتابة).
