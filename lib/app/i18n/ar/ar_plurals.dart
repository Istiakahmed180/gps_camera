/// Arabic count forms that a singular/plural pair cannot express.
/// Keyed by the English plural key; `two` is the dual, `few` is used for
/// 3 to 10 and `other` for 0 and 11 and up. A missing form falls back to
/// the plural text in [ar].
const Map<String, Map<String, String>> arPlurals = {
  '@n files backed up': {
    'two': 'تم نسخ ملفين',
    'few': 'تم نسخ @n ملفات',
    'other': 'تم نسخ @n ملفًا',
  },
  'Restored @n photos (@files files)': {
    'two': 'تمت استعادة صورتين (@files ملفات)',
    'few': 'تمت استعادة @n صور (@files ملفات)',
    'other': 'تمت استعادة @n صورة (@files ملفات)',
  },
  '@n photos will be copied to Pictures/Locaproof. The photos in the app are not changed.':
      {
        'two': 'سيتم نسخ صورتين إلى Pictures/Locaproof. لن تتغير الصور داخل التطبيق.',
        'other': 'سيتم نسخ @n صورة إلى Pictures/Locaproof. لن تتغير الصور داخل التطبيق.',
      },
  'Backup saved: @n photos, @files files': {
    'two': 'تم حفظ النسخة الاحتياطية: صورتان، @files ملف',
    'other': 'تم حفظ النسخة الاحتياطية: @n صورة، @files ملف',
  },
  '@n files': {'two': 'ملفان', 'other': '@n ملف'},
  'Added @n photos (@files in total).': {
    'two': 'تمت إضافة صورتين (@files إجمالًا).',
    'other': 'تمت إضافة @n صورة (@files إجمالًا).',
  },
  'Added @n projects.': {
    'two': 'تمت إضافة مشروعين.',
    'other': 'تمت إضافة @n مشروع.',
  },
  '@n photos put back in their projects.': {
    'two': 'أُعيدت صورتان إلى مشاريعهما.',
    'other': 'أُعيدت @n صورة إلى مشاريعها.',
  },
  '@n files skipped because they already exist.': {
    'two': 'تم تخطي ملفين لأنهما موجودان مسبقًا.',
    'other': 'تم تخطي @n ملف لأنها موجودة مسبقًا.',
  },
  'Updated @n photos': {'two': 'تم تحديث صورتين', 'other': 'تم تحديث @n صورة'},
  'remade @n watermarked copies': {
    'two': 'أُعيد إنشاء نسختين بعلامة مائية',
    'other': 'أُعيد إنشاء @n نسخة بعلامة مائية',
  },
  '@n photos still need details. Check the internet connection and try again.':
      {
        'two': 'لا تزال صورتان بحاجة إلى تفاصيل. تحقق من الاتصال بالإنترنت وحاول مجددًا.',
        'other': 'لا تزال @n صورة بحاجة إلى تفاصيل. تحقق من الاتصال بالإنترنت وحاول مجددًا.',
      },
  '@n photos': {'two': 'صورتان', 'other': '@n صورة'},
  '@n copies': {'two': 'نسختان', 'other': '@n نسخة'},
  '@n maps kept so places you visit again need no download. Clearing it never affects your photos.':
      {
        'two': 'تم الاحتفاظ بخريطتين حتى لا تحتاج إلى تنزيلهما عند زيارة الأماكن نفسها مجددًا. مسحهما لا يؤثر على صورك أبدًا.',
        'other': 'تم الاحتفاظ بـ @n خريطة حتى لا تحتاج إلى تنزيلها عند زيارة الأماكن نفسها مجددًا. مسحها لا يؤثر على صورك أبدًا.',
      },
  'Delete @n photos?': {'two': 'حذف صورتين؟', 'other': 'حذف @n صورة؟'},
  'Also delete watermarked copies of @n originals': {
    'two': 'حذف النسخ بعلامة مائية لصورتين أصليتين أيضًا',
    'other': 'حذف النسخ بعلامة مائية لـ @n صورة أصلية أيضًا',
  },
  'Deleted @n photos': {'two': 'تم حذف صورتين', 'other': 'تم حذف @n صورة'},
  'Deleted @removed, but @failed files could not be removed': {
    'two': 'تم حذف @removed، لكن تعذّر حذف ملفين',
    'other': 'تم حذف @removed، لكن تعذّر حذف @failed ملف',
  },
  'Map · @n photos': {'two': 'الخريطة · صورتان', 'other': 'الخريطة · @n صورة'},
  '@n photos at @place': {
    'two': 'صورتان في @place',
    'other': '@n صورة في @place',
  },
  '@n watermarked copies': {
    'two': 'نسختان بعلامة مائية',
    'other': '@n نسخة بعلامة مائية',
  },
  'Add @n photos': {'two': 'إضافة صورتين', 'other': 'إضافة @n صورة'},
  '@n originals': {
    'two': 'صورتان أصليتان',
    'few': '@n صور أصلية',
    'other': '@n صورة أصلية',
  },
  '@n photos. Original photos get their capture time and GPS location written in, so other apps can read them.':
      {
        'two': 'صورتان. تُكتب في الصور الأصلية وقت الالتقاط وموقع GPS، لتتمكن التطبيقات الأخرى من قراءتها.',
        'other': '@n صورة. تُكتب في الصور الأصلية وقت الالتقاط وموقع GPS، لتتمكن التطبيقات الأخرى من قراءتها.',
      },
  '@n pages': {'two': 'صفحتان', 'other': '@n صفحة'},
  '@n more locations are not shown on the map.': {
    'two': 'موقعان إضافيان لا يظهران على الخريطة.',
    'few': '@n مواقع إضافية لا تظهر على الخريطة.',
    'other': '@n موقعًا إضافيًا لا تظهر على الخريطة.',
  },
  '@n versions · latest @file': {
    'two': 'نسختان · الأحدث: @file',
    'few': '@n نسخ · الأحدث: @file',
    'other': '@n نسخة · الأحدث: @file',
  },
};
