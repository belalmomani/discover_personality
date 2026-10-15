/// Arabic UI strings shared by several screens. To add English later: introduce an
/// abstract `AppStrings`, implement `ArStrings`/`EnStrings`, and select by Locale
/// (the MaterialApp already declares supportedLocales/delegates). Long copy lives in
/// lib/data/report/report_content.dart and lib/features/privacy/privacy_text.dart.
class S {
  S._();
  static const appName = 'اكتشف شخصيتك';
  static const start = 'ابدأ الاختبار';
  static const cont = 'متابعة الاختبار';
  static const retest = 'إعادة الاختبار';
  static const loading = 'جارٍ التحميل...';
  static const retry = 'إعادة المحاولة';
  static const cancel = 'إلغاء';
  static const save = 'حفظ';
  static const delete = 'حذف';
  static const confirm = 'تأكيد';
  static const errorGeneric = 'حدث خطأ غير متوقع. حاول مرة أخرى.';
  static const prototypeNote = 'نسخة أولية: الاختبار لم يُتحقق من صلاحيته علميًا بعد.';
}
