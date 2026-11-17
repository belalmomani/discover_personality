#!/usr/bin/env python3
"""Generates the privacy policy in all three places from ONE source so they never drift apart:
  - lib/features/privacy/privacy_text.dart   (in-app screen)
  - PRIVACY.md                               (repo)
  - docs/discover-personality-privacy.html + docs/discover-personality-delete-account.html (upload to the GitHubPages repo)
Usage: python3 tool/gen_privacy.py you@example.com
Public pages are named so they can sit next to other apps pages in one GitHub Pages repo.
"""
import html, sys

EMAIL = sys.argv[1] if len(sys.argv) > 1 else "ADD_CONTACT_EMAIL_BEFORE_PUBLISHING"
UPDATED = "17 نوفمبر 2026"
APP = "اكتشف شخصيتك"

SECTIONS = [
 ("1) من نحن", [
  f"تطبيق «{APP}» تطبيق عربي لاستكشاف التفضيلات الشخصية (MBTI وEnneagram ورمز A-R-F-D وعدة اختبارات إضافية). مالك التطبيق والمسؤول عن بياناتك هو المطوّر، ويمكن التواصل معه على: {EMAIL}",
 ]),
 ("2) البيانات التي يجمعها التطبيق", [
  "• إجاباتك عن أسئلة الاختبار ونتائجك المحسوبة وخطة التطوير وإعداداتك (الوضع الفاتح/الداكن وخيارات الموافقة). تُحفظ على جهازك.",
  "• صفحة «ملفي الشخصي»: تاريخ الميلاد والدولة وإجاباتك في الاختبارات الإضافية (بما فيها السمات المظلمة وأنماط التعلّق). تبقى على جهازك فقط ولا تُرفع ولا تُرسل لأي جهة.",
  "• تقييمات أشخاص يعرفونك (اختيارية): صلة المقيِّم وإجاباته العشر بلا اسم، على جهازك فقط.",
  "• الحساب (اختياري): البريد الإلكتروني ومعرّف حسابك، ونسخة من نتائجك وخطتك للمزامنة بين أجهزتك.",
  "• «يشبهونك» والدردشة (اختيارية، لمن عمره 18 سنة فأكثر): اسم مستعار وصورة رمزية و8 أرقام مجمّعة من نتائجك للمطابقة، والرسائل والهدايا والصور التي ترسلها، وآخر ظهور (يمكنك إخفاؤه)، والبلاغات وقوائم الحظر.",
  "• الإشعارات (اختيارية): رمز الجهاز (FCM token) لإرسال إشعار برسالة جديدة، دون نص الرسالة.",
  "• الإعلانات (اختيارية ولا تعمل إلا بموافقتك): قد تجمع شبكة Start.io معرّف الإعلان (Advertising ID) ومعلومات الجهاز والتطبيق وعنوان IP لعرض الإعلانات وقياس أدائها، بحسب سياستها المنشورة على موقعها start.io.",
 ]),
 ("3) لماذا نستخدم البيانات", [
  "لحساب نتائجك وعرض التقرير وحفظ تقدمك، ولمزامنتها بين أجهزتك إن سجّلت الدخول، ولتشغيل «يشبهونك» والدردشة والإشعارات إن فعّلتها، ولعرض الإعلانات التي تدعم بقاء التطبيق مجانيًا إن وافقت عليها، ولحماية المستخدمين من الإساءة.",
 ]),
 ("4) أين تُخزَّن وكيف تُحمى", [
  "• افتراضيًا على جهازك فقط، ويعمل التطبيق دون حساب ودون إنترنت.",
  "• عند تسجيل الدخول أو تفعيل «يشبهونك»: تُخزَّن في قاعدة بيانات Supabase الخاصة بمالك التطبيق مع عزل على مستوى الصفوف (لا يستطيع مستخدم قراءة بيانات مستخدم آخر) واتصال مشفّر. صور الدردشة في حاوية خاصة ولا تُعرض إلا بروابط مؤقتة لطرفي المحادثة.",
  "• نبذل جهدًا معقولًا لحماية البيانات، لكن لا توجد وسيلة نقل أو تخزين آمنة بنسبة 100%.",
 ]),
 ("5) مع من نشارك البيانات", [
  "لا نبيع بياناتك. نستعين بمزوّدي خدمة يعالجون البيانات لحسابنا أو بموافقتك: Supabase (الاستضافة والحساب)، وStart.io (الإعلانات، بموافقتك فقط)، وGoogle Firebase (الإشعارات، إن فعّلتها)، وخادم وسيط للذكاء الاصطناعي (اختياري ومعطّل افتراضيًا، ويستقبل درجاتك الملخصة فقط دون الإجابات الخام ودون بيانات شخصية، وبموافقتك). قد نكشف بيانات عند وجود التزام قانوني أو لحماية سلامة المستخدمين.",
 ]),
 ("6) الإعلانات وموافقتك", [
  "يعرض التطبيق إعلانات من Start.io (شريط إعلاني في الرئيسية والنتائج، وإعلان بيني عند مغادرة صفحة النتائج). لا تظهر إعلانات أثناء الاختبار. لا يُحمَّل أي إعلان إلا بعد موافقتك الصريحة عند أول تشغيل، ويمكنك سحب الموافقة في أي وقت من الإعدادات ← الإعلانات. يمكنك أيضًا إعادة ضبط معرّف الإعلان أو إيقاف التخصيص من إعدادات جهازك.",
 ]),
 ("7) الاحتفاظ بالبيانات وحذفها", [
  "• بيانات الجهاز: من الإعدادات ← حذف بيانات الجهاز.",
  "• الحساب والبيانات السحابية (بما فيها الرسائل والملف المشترك): من الإعدادات ← حذف الحساب، فتُحذف بياناتك السحابية.",
  f"• إن لم يعد التطبيق مثبتًا لديك، راسلنا على {EMAIL} من بريد حسابك مع عنوان «حذف حساب» وسنحذف الحساب وبياناته. تفاصيل أكثر في صفحة طلب حذف الحساب.",
 ]),
 ("8) الأطفال والفئة العمرية", [
  "التطبيق غير موجّه للأطفال دون 13 سنة. ميزتا «يشبهونك» والدردشة لمن عمره 18 سنة فأكثر، ويُطلب تأكيد ذلك قبل التفعيل. إن علمنا بوجود حساب لقاصر في هذه الميزات فسنحذفه.",
 ]),
 ("9) السلامة والإشراف", [
  "تتيح الدردشة الإبلاغ عن المستخدمين والرسائل وحظرهم، وتُرشَّح الكلمات الممنوعة والروابط على الخادم، وقد تراجع الإدارة البلاغات (وصور الدردشة المبلَّغ عنها) وتتخذ إجراءً يصل إلى إيقاف الحساب.",
 ]),
 ("10) تنبيه مهم", [
  "نتائج الاختبارات وصف أولي للتأمل الذاتي، وليست تشخيصًا نفسيًا أو طبيًا ولا بديلًا عن مختص. الأسئلة أصلية ولم يُتحقق من ثباتها وصدقها علميًا.",
 ]),
 ("11) التعديلات", [
  f"قد نحدّث هذه السياسة، وسنغيّر تاريخ آخر تحديث أدناه (آخر تحديث: {UPDATED}). الاستمرار في الاستخدام بعد التحديث يعني قبوله.",
 ]),
 ("12) التواصل", [
  f"لأي سؤال أو طلب يخص بياناتك: {EMAIL}",
 ]),
]

DELETE_STEPS = [
 "داخل التطبيق (الأسهل): افتح الإعدادات ← «حذف الحساب» ← أكّد. تُحذف بياناتك السحابية (الحساب، النتائج المتزامنة، الملف المشترك، الرسائل والهدايا والصور).",
 "حذف بيانات الجهاز فقط: الإعدادات ← «حذف بيانات الجهاز».",
 f"إن لم يعد التطبيق لديك: أرسل رسالة إلى {EMAIL} من البريد المسجّل به حسابك، بعنوان «حذف حساب»، وسنحذف الحساب وبياناته المرتبطة.",
]
DELETE_NOTE = "ما يُحذف: البريد الإلكتروني ومعرّف الحساب والنتائج والخطط المزامنة والاسم المستعار والأرقام المجمّعة والرسائل والصور والهدايا. بيانات الاختبار المحلية تبقى على جهازك حتى تحذفها من الإعدادات أو تزيل التطبيق."

# ---- Dart (plain text; no dollar signs or backslashes allowed)
txt = f"سياسة الخصوصية\nآخر تحديث: {UPDATED}\n\n"
for h, ps in SECTIONS:
    txt += h + "\n" + "\n".join(ps) + "\n\n"
assert "$" not in txt and "\\" not in txt and "'''" not in txt
dart = ("/// In-app privacy policy (Arabic). GENERATED by tool/gen_privacy.py: edit the generator, not this file.\n"
        "/// Not legal advice: review before publishing.\n"
        "const String privacyPolicyAr = '''\n" + txt.rstrip() + "\n''';\n")
open("lib/features/privacy/privacy_text.dart", "w", encoding="utf-8").write(dart)

# ---- Markdown
md = f"# سياسة الخصوصية: {APP}\n\n_آخر تحديث: {UPDATED}_\n\n> مولَّد من `tool/gen_privacy.py` ومطابق لما في التطبيق وصفحة `docs/discover-personality-privacy.html`. ليس استشارة قانونية.\n\n"
for h, ps in SECTIONS:
    md += f"## {h}\n" + "\n".join(("- " + p[2:] if p.startswith("• ") else p) + ("" if p.startswith("• ") else "\n") for p in ps) + "\n\n"
open("PRIVACY.md", "w", encoding="utf-8").write(md.rstrip() + "\n")

# ---- HTML pages
CSS = """:root{--bg:#fff;--fg:#1d1d1f;--mut:#555;--card:#f4f5f7;--ac:#2f5bd8}
@media (prefers-color-scheme:dark){:root{--bg:#121316;--fg:#ececf0;--mut:#a5a8b0;--card:#1c1e23;--ac:#8ab0ff}}
body{margin:0;background:var(--bg);color:var(--fg);font:16px/1.9 system-ui,-apple-system,"Segoe UI",Tahoma,sans-serif}
main{max-width:760px;margin:0 auto;padding:20px 18px 60px}h1{font-size:1.5rem}h2{font-size:1.1rem;margin-top:1.8rem;color:var(--ac)}
p,li{margin:.4rem 0}.card{background:var(--card);border-radius:12px;padding:12px 16px}a{color:var(--ac)}.mut{color:var(--mut);font-size:.9rem}"""
def page(title, body):
    return (f'<!doctype html>\n<html lang="ar" dir="rtl"><head><meta charset="utf-8">'
            f'<meta name="viewport" content="width=device-width, initial-scale=1"><title>{html.escape(title)}</title>'
            f'<style>{CSS}</style></head><body><main>{body}</main></body></html>\n')
def linkify(t):
    t = html.escape(t)
    return t.replace(html.escape(EMAIL), f'<a href="mailto:{html.escape(EMAIL)}">{html.escape(EMAIL)}</a>')
b = f'<h1>سياسة الخصوصية: {APP}</h1><p class="mut">آخر تحديث: {UPDATED} · <a href="discover-personality-delete-account.html">طلب حذف الحساب</a></p>'
for h, ps in SECTIONS:
    b += f"<h2>{html.escape(h)}</h2>"
    items = [p[2:] for p in ps if p.startswith("• ")]
    others = [p for p in ps if not p.startswith("• ")]
    for o in others: b += f"<p>{linkify(o)}</p>"
    if items: b += "<ul>" + "".join(f"<li>{linkify(i)}</li>" for i in items) + "</ul>"
open("docs/discover-personality-privacy.html", "w", encoding="utf-8").write(page(f"سياسة الخصوصية: {APP}", b))
d = f'<h1>طلب حذف الحساب: {APP}</h1><p class="mut"><a href="discover-personality-privacy.html">سياسة الخصوصية</a></p><ol>' + "".join(f"<li>{linkify(s)}</li>" for s in DELETE_STEPS) + f'</ol><div class="card">{linkify(DELETE_NOTE)}</div>'
open("docs/discover-personality-delete-account.html", "w", encoding="utf-8").write(page(f"حذف الحساب: {APP}", d))
print("generated with contact:", EMAIL)
