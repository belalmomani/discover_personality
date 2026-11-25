# اكتشف شخصيتك (Discover Your Personality)

تطبيق Flutter عربي (RTL) لاستكشاف التفضيلات الشخصية بثلاثة أنظمة: **MBTI** و**Enneagram** ورمز **A-R-F-D** الخاص بالتطبيق.

> النتائج وصف أولي للتأمل الذاتي، وليست تشخيصًا نفسيًا ولا حقيقة علمية. الاختبار نسخة أولية لم يُتحقق من صلاحيتها علميًا.

## الميزات
- 72 سؤالًا ثابتًا (24 + 36 + 12) في `assets/data/questions_ar.json` منفصلة عن الواجهات.
- محرك تقييم حتمي بلا ذكاء اصطناعي: `lib/data/scoring/`.
- يعمل دون حساب ودون إنترنت؛ تقدم الاختبار يُحفظ تلقائيًا.
- تقرير عربي محلي + خطة 30 يومًا قابلة للتعديل + سجل ومقارنة.
- Supabase اختياري (مصادقة + مزامنة + حذف حساب) مع RLS.
- Start.io: بنية جاهزة **معطلة افتراضيًا** (`ADS_ENABLED=false`).
- ذكاء اصطناعي اختياري عبر خادم وسيط فقط (معطل افتراضيًا).

## البدء السريع (من الهاتف)
اقرأ `docs/SETUP.md` ثم `docs/BUILD_APK.md`. باختصار: ارفع المجلد إلى GitHub ← تبويب Actions ← Android build ← Run workflow ← نزّل APK من Artifacts.

## الأدلة
`docs/SETUP.md` • `docs/BUILD_APK.md` • `docs/SUPABASE_SETUP.md` • `docs/STARTIO_SETUP.md` • `docs/TESTING.md` • `docs/STATUS.md` (ما نُفذ وما لم يُتحقق منه) • `PRIVACY.md`

## الترخيص
لم يُحدد ترخيص بعد (انظر `LICENSE`).
