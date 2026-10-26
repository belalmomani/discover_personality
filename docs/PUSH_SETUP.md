# إشعارات الدردشة (Push)

الكود جاهز، لكن التشغيل الفعلي يحتاج **مشروع Firebase مجانيًا من حسابك**. دون ذلك يبقى التطبيق يعمل، ويقول مفتاح الإشعارات في الإعدادات: «غير مفعّلة في هذه النسخة».

## ما يحدث
1. المستخدم يشغّل «إشعارات الدردشة» من الإعدادات (معطلة افتراضيًا) ← يطلب التطبيق إذن الإشعارات ← يُسجَّل رمز الجهاز في جدول داخلي.
2. عند إدخال رسالة، يستدعي **Database Webhook** الدالة `push-notify` ← تتحقق من إعدادات المستلم (مفعّل الإشعارات، غير محظور/موقوف، الدردشة مفعّلة) ← ترسل عبر FCM.
3. **نص الرسالة لا يظهر أبدًا في الإشعار**: «رسالة جديدة من فلان» / «أرسل لك هدية» / «أرسل لك صورة». الضغط على الإشعار يفتح المحادثة.
4. عند وصول إشعار والتطبيق مفتوح تُعلَّم الرسائل «وصلت».

## خطواتك (من المتصفح)
1. **Firebase:** console.firebase.google.com ← Add project ← Add app ← Android بالاسم `app.discover.discover_personality` ← نزّل `google-services.json`.
2. **GitHub Secret:** حوّل الملف إلى base64 (أي موقع/تطبيق تحويل base64، أو `base64 -w0 google-services.json`) وأضفه سرًّا باسم **`GOOGLE_SERVICES_JSON_BASE64`**. الـ workflow سيحقنه ويفعّل إضافة Google Services تلقائيًا.
3. **حساب الخدمة:** Firebase ← Project settings ← Service accounts ← Generate new private key ← انسخ محتوى ملف JSON.
4. **Supabase ← Edge Functions ← Secrets:** أضف `FCM_SERVICE_ACCOUNT` (محتوى ملف JSON كاملًا) و`PUSH_WEBHOOK_SECRET` (نص عشوائي طويل من اختيارك).
5. **انشر الدالة:** Edge Functions ← Deploy a new function ← via editor ← الاسم `push-notify` ← الصق `supabase/functions/push-notify/index.ts` ← **عطّل Verify JWT** (يحميها السر) ← Deploy.
6. **Webhook:** Database ← Webhooks ← Create ← جدول `public.messages` ← حدث Insert ← النوع Supabase Edge Function ← `push-notify` ← أضف Header: `x-webhook-secret` بقيمة `PUSH_WEBHOOK_SECRET` نفسها.
7. أعد تشغيل الـ workflow ثم ثبّت النسخة الجديدة، وفعّل المفتاح من الإعدادات على الهاتفين.

## حدود
- لم تُجرَّب الدالة ولا الإشعارات على جهاز حقيقي أو خادم حقيقي.
- أندرويد فقط حاليًا. على أندرويد 13+ يظهر طلب إذن.
- مفتاح `service_role` يبقى على الخادم (متغير بيئة تلقائي للدالة) ولا يدخل التطبيق.
- إن فشل البناء بعد إضافة Firebase فأرسل لي سجل Actions: قد يلزم ضبط إصدارات الإضافات مع Kotlin/AGP.
