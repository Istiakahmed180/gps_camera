/// Watermark editor, watermark text on photos, settings, backup and phone
/// gallery export.
const Map<String, String> bnWatermarkSettings = {
  // Watermark drawn on photos.
  'GPS Accuracy: @value': 'GPS নির্ভুলতা: @value',
  'Facing @direction': 'দিক @direction',
  'Note: @note': 'নোট: @note',
  'Plus Code @code': 'Plus Code @code',
  'DATE': 'তারিখ',
  'TIME': 'সময়',
  'LAT': 'অক্ষাংশ',
  'LON': 'দ্রাঘিমা',
  'ACC': 'নির্ভুলতা',
  'DIR': 'দিক',
  'ADDR': 'ঠিকানা',
  'NOTE': 'নোট',
  'Good': 'ভালো',
  'Moderate': 'মাঝারি',
  'Poor': 'দুর্বল',
  '@accuracy (poor)': '@accuracy (দুর্বল)',
  'Last known location': 'সর্বশেষ জানা লোকেশন',
  'Last known location · @age before capture':
      'সর্বশেষ জানা লোকেশন · ছবি তোলার @age আগে',
  'Location unavailable': 'লোকেশন পাওয়া যায়নি',

  // Templates.
  'Map': 'ম্যাপ',
  'Map, address, coordinates and time': 'ম্যাপ, ঠিকানা, স্থানাঙ্ক ও সময়',
  'Classic': 'ক্লাসিক',
  'Compact panel with clean white text': 'সাদা লেখাসহ ছোট প্যানেল',
  'Professional': 'প্রফেশনাল',
  'Structured details for inspections and site records':
      'পরিদর্শন ও সাইট রেকর্ডের জন্য সাজানো তথ্য',
  'Minimal': 'মিনিমাল',
  'Small, unobtrusive text': 'ছোট, চোখে না লাগা লেখা',
  '@name template. @description': '@name টেমপ্লেট। @description',

  // Watermark editor.
  'Watermark': 'ওয়াটারমার্ক',
  'Photo unavailable': 'ছবি পাওয়া যাচ্ছে না',
  'Something went wrong.': 'কিছু একটা সমস্যা হয়েছে।',
  'Template': 'টেমপ্লেট',
  'No location was recorded for this photo. The watermark will say '
          '"Location unavailable" instead of coordinates.':
      'এই ছবির কোনো লোকেশন রেকর্ড হয়নি। ওয়াটারমার্কে স্থানাঙ্কের বদলে '
      '"লোকেশন পাওয়া যায়নি" লেখা থাকবে।',
  'This photo only has a last known location. The watermark labels it '
          'that way.':
      'এই ছবিতে শুধু সর্বশেষ জানা লোকেশন আছে। ওয়াটারমার্কে সেটাই লেখা থাকবে।',
  'This photo only has a last known location, from @age before capture. '
          'The watermark labels it that way.':
      'এই ছবিতে শুধু সর্বশেষ জানা লোকেশন আছে, ছবি তোলার @age আগের। '
      'ওয়াটারমার্কে সেটাই লেখা থাকবে।',
  'Choose at least one detail to show.':
      'দেখানোর জন্য অন্তত একটি তথ্য বাছাই করুন।',
  'Saved as @file. The original is unchanged.':
      '@file নামে সেভ হয়েছে। অরিজিনাল ছবি বদলায়নি।',
  'It could not be added to the phone gallery.':
      'এটি ফোনের গ্যালারিতে যোগ করা যায়নি।',
  'Saving…': 'সেভ হচ্ছে…',
  'Save watermarked copy': 'ওয়াটারমার্ক কপি সেভ করুন',
  'This is a watermarked copy. Open its original to create a new '
          'watermark.':
      'এটি একটি ওয়াটারমার্ক কপি। নতুন ওয়াটারমার্ক বানাতে এর অরিজিনাল ছবি খুলুন।',
  'This photo could not be opened.': 'ছবিটি খোলা যায়নি।',
  'The watermarked copy could not be saved.':
      'ওয়াটারমার্ক কপি সেভ করা যায়নি।',
  'This photo\'s metadata file is damaged.':
      'এই ছবির মেটাডেটা ফাইল নষ্ট হয়ে গেছে।',
  'This photo\'s metadata could not be read.': 'এই ছবির মেটাডেটা পড়া যায়নি।',
  'This photo has no metadata, so a watermark cannot be created.':
      'এই ছবির কোনো মেটাডেটা নেই, তাই ওয়াটারমার্ক বানানো যাবে না।',
  'This photo\'s metadata is not recognised.':
      'এই ছবির মেটাডেটা চেনা যাচ্ছে না।',
  'This is already a watermarked copy. Open its original instead.':
      'এটি আগে থেকেই ওয়াটারমার্ক কপি। এর বদলে অরিজিনাল ছবি খুলুন।',
  'The watermark could not be drawn.': 'ওয়াটারমার্ক আঁকা যায়নি।',

  // Watermark details panel.
  'Details': 'তথ্য',
  'Date': 'তারিখ',
  'Time': 'সময়',
  'Coordinates': 'স্থানাঙ্ক',
  'Accuracy': 'নির্ভুলতা',
  'Address': 'ঠিকানা',
  'Direction': 'দিক',
  'Note': 'নোট',
  'No address is recorded for this photo': 'এই ছবির কোনো ঠিকানা রেকর্ড হয়নি',
  'No compass direction was recorded for this photo':
      'এই ছবির কোনো কম্পাসের দিক রেকর্ড হয়নি',
  'This photo has no note': 'এই ছবিতে কোনো নোট নেই',
  'Position': 'অবস্থান',
  'Left': 'বামে',
  'Center': 'মাঝে',
  'Right': 'ডানে',
  'Text size': 'লেখার আকার',
  'Small': 'ছোট',
  'Medium': 'মাঝারি',
  'Large': 'বড়',
  'Opacity': 'অস্বচ্ছতা',

  // Branding.
  'Branding': 'ব্র্যান্ডিং',
  'Heading': 'শিরোনাম',
  'Company or app name': 'কোম্পানি বা অ্যাপের নাম',
  'Leave empty to hide it.': 'লুকাতে চাইলে খালি রাখুন।',
  'Use “@brand”': '“@brand” ব্যবহার করুন',
  'Extra line': 'অতিরিক্ত লাইন',
  'e.g. Site: Block C · Inspector: Rahim':
      'যেমন: সাইট: ব্লক C · পরিদর্শক: রহিম',
  'Shown under the heading on every photo.':
      'প্রতিটি ছবিতে শিরোনামের নিচে দেখাবে।',
  'Logo': 'লোগো',
  'PNG or JPEG. A transparent PNG looks best.':
      'PNG বা JPEG। স্বচ্ছ PNG সবচেয়ে ভালো দেখায়।',
  'Shown beside the heading (not in Minimal).':
      'শিরোনামের পাশে দেখাবে (মিনিমাল টেমপ্লেটে নয়)।',
  'Choose': 'বাছাই করুন',
  'Logo options': 'লোগোর অপশন',
  'Change': 'বদলান',
  'Show logo': 'লোগো দেখান',
  'The logo could not be saved.': 'লোগো সেভ করা যায়নি।',
  'The logo could not be removed.': 'লোগো সরানো যায়নি।',
  'The image could not be opened.': 'ছবিটি খোলা যায়নি।',
  'The image could not be read.': 'ছবিটি পড়া যায়নি।',
  'That file is not a supported image. Use a PNG or JPEG.':
      'এই ফাইলটি সমর্থিত ছবি নয়। PNG বা JPEG ব্যবহার করুন।',

  // Live watermark on the camera.
  'Auto watermark off': 'অটো ওয়াটারমার্ক বন্ধ',
  'Loading map…': 'ম্যাপ লোড হচ্ছে…',
  'Watermark. Change template': 'ওয়াটারমার্ক। টেমপ্লেট বদলান',
  'Save a watermarked copy on capture':
      'ছবি তোলার সময় ওয়াটারমার্ক কপি সেভ করুন',
  'The original photo is always kept': 'অরিজিনাল ছবি সবসময় রাখা হয়',
  'More options (details, size, position) are in the watermark editor.':
      'আরও অপশন (তথ্য, আকার, অবস্থান) ওয়াটারমার্ক এডিটরে আছে।',
  'Photo preview': 'ছবির প্রিভিউ',

  // Settings.
  'Camera': 'ক্যামেরা',
  'Time and units': 'সময় ও একক',
  'Phone gallery': 'ফোনের গ্যালারি',
  'Location details': 'লোকেশনের তথ্য',
  'Storage': 'স্টোরেজ',
  'Backup': 'ব্যাকআপ',
  'Appearance': 'চেহারা',
  'Theme': 'থিম',
  'Choose how the app looks outside the camera.':
      'ক্যামেরার বাইরে অ্যাপটি কেমন দেখাবে তা বাছাই করুন।',
  'Light': 'লাইট',
  'Dark': 'ডার্ক',
  'About': 'অ্যাপ সম্পর্কে',
  'Geo-tagged photos, albums and reports': 'লোকেশনসহ ছবি, অ্যালবাম ও রিপোর্ট',
  'Not available on this phone': 'এই ফোনে চালু নেই',
  'Saving to the phone gallery needs Android 10 or later. Use Share or '
          'Backup to keep copies outside the app.':
      'ফোনের গ্যালারিতে সেভ করতে Android 10 বা তার পরের ভার্সন লাগে। অ্যাপের '
      'বাইরে কপি রাখতে শেয়ার বা ব্যাকআপ ব্যবহার করুন।',
  'New photos are also saved to Pictures/GPS Camera, so they appear in the '
          'phone’s gallery and stay there if the app is removed.':
      'নতুন ছবি Pictures/GPS Camera-তেও সেভ হয়, তাই ফোনের গ্যালারিতে দেখা যায় '
      'এবং অ্যাপ মুছে ফেললেও থেকে যায়।',
  'Don’t save': 'সেভ করবেন না',
  'Photos stay inside the app only.': 'ছবি শুধু অ্যাপের ভেতরেই থাকবে।',
  'Watermarked photo': 'ওয়াটারমার্ক ছবি',
  'The watermarked copy, or the original if no copy was made.':
      'ওয়াটারমার্ক কপি, কপি না থাকলে অরিজিনাল ছবি।',
  'Original photo': 'অরিজিনাল ছবি',
  'The untouched original only.': 'শুধু অপরিবর্তিত অরিজিনাল ছবি।',
  'Both': 'দুটোই',
  'The original and every watermarked copy.':
      'অরিজিনাল ও প্রতিটি ওয়াটারমার্ক কপি।',
  'Copy existing photos to gallery': 'আগের ছবিগুলো গ্যালারিতে কপি করুন',
  'Uses the choice above. Photos already copied are skipped.':
      'উপরের পছন্দ অনুযায়ী হবে। আগে কপি করা ছবি বাদ যাবে।',
  'Copying @done of @total…': '@total-টির মধ্যে @doneটি কপি হচ্ছে…',
  'Photos could not be read. Try again.':
      'ছবিগুলো পড়া যায়নি। আবার চেষ্টা করুন।',
  'There are no photos to copy.': 'কপি করার মতো কোনো ছবি নেই।',
  'Copy to phone gallery?': 'ফোনের গ্যালারিতে কপি করবেন?',
  '@n photo will be copied to Pictures/GPS Camera. The photos in the app '
          'are not changed.':
      '@nটি ছবি Pictures/GPS Camera-তে কপি হবে। অ্যাপের ছবিগুলো বদলাবে না।',
  '@n photos will be copied to Pictures/GPS Camera. The photos in the app '
          'are not changed.':
      '@nটি ছবি Pictures/GPS Camera-তে কপি হবে। অ্যাপের ছবিগুলো বদলাবে না।',
  'Copy': 'কপি করুন',
  'Photos could not be copied. Try again.':
      'ছবিগুলো কপি করা যায়নি। আবার চেষ্টা করুন।',
  '@n copied': '@nটি কপি হয়েছে',
  '@n already there': '@nটি আগে থেকেই আছে',
  '@n failed': '@nটি ব্যর্থ',

  // Camera settings.
  'Photo quality': 'ছবির মান',
  'Standard': 'স্ট্যান্ডার্ড',
  'Full HD, about 2 MP · smallest files':
      'Full HD, প্রায় 2 MP · সবচেয়ে ছোট ফাইল',
  '4K, about 8 MP · recommended': '4K, প্রায় 8 MP · প্রস্তাবিত',
  'Maximum': 'সর্বোচ্চ',
  'Full camera resolution · largest files, slower to process':
      'ক্যামেরার পূর্ণ রেজোলিউশন · সবচেয়ে বড় ফাইল, প্রসেস হতে বেশি সময় লাগে',
  'Also save a copy with the location overlay for every photo. The original '
          'is always kept.':
      'প্রতিটি ছবির সাথে লোকেশনসহ একটি কপিও সেভ করুন। অরিজিনাল ছবি সবসময় রাখা হয়।',
  'Volume buttons take photos': 'ভলিউম বাটনে ছবি তুলুন',
  'While the camera is open. Volume works normally everywhere else.':
      'ক্যামেরা খোলা থাকলে। অন্য সব জায়গায় ভলিউম স্বাভাবিকভাবে কাজ করবে।',

  // Time and units.
  'Used on new watermarks, the camera screen, photo details and reports. '
          'Saved values are not changed.':
      'নতুন ওয়াটারমার্ক, ক্যামেরা স্ক্রিন, ছবির তথ্য ও রিপোর্টে ব্যবহার হবে। '
      'সেভ করা মান বদলাবে না।',
  '12-hour · 2:25 PM': '12 ঘণ্টা · 2:25 PM',
  '24-hour · 14:25': '24 ঘণ্টা · 14:25',
  'Accuracy and altitude': 'নির্ভুলতা ও উচ্চতা',
  'Metres': 'মিটার',
  'Feet': 'ফুট',

  // Location details.
  'Add missing addresses and maps': 'না থাকা ঠিকানা ও ম্যাপ যোগ করুন',
  'Checking photos…': 'ছবি দেখা হচ্ছে…',
  'Photos taken without internet get them automatically when the phone is '
          'online. Automatic watermarked copies are made again with the new '
          'details.':
      'ইন্টারনেট ছাড়া তোলা ছবিতে ফোন অনলাইন হলে এগুলো নিজে থেকেই যোগ হয়। '
      'অটো ওয়াটারমার্ক কপিগুলো নতুন তথ্য দিয়ে আবার বানানো হয়।',
  'Updated @n photo': '@nটি ছবি আপডেট হয়েছে',
  'Updated @n photos': '@nটি ছবি আপডেট হয়েছে',
  'remade @n watermarked copy': '@nটি ওয়াটারমার্ক কপি আবার বানানো হয়েছে',
  'remade @n watermarked copies': '@nটি ওয়াটারমার্ক কপি আবার বানানো হয়েছে',
  '@n still waiting': '@nটি এখনও অপেক্ষায়',
  '@n photo still need details. Check the internet connection and try '
          'again.':
      '@nটি ছবিতে এখনও তথ্য বাকি। ইন্টারনেট সংযোগ দেখে আবার চেষ্টা করুন।',
  '@n photos still need details. Check the internet connection and try '
          'again.':
      '@nটি ছবিতে এখনও তথ্য বাকি। ইন্টারনেট সংযোগ দেখে আবার চেষ্টা করুন।',
  'All photos have their address and map.': 'সব ছবিতে ঠিকানা ও ম্যাপ আছে।',

  // Storage.
  'Measuring…': 'হিসাব করা হচ্ছে…',
  'Total': 'মোট',
  'Original photos': 'অরিজিনাল ছবি',
  '@n photo': '@nটি ছবি',
  '@n photos': '@nটি ছবি',
  'Watermarked copies': 'ওয়াটারমার্ক কপি',
  '@n copy': '@nটি কপি',
  '@n copies': '@nটি কপি',
  'Maps saved with photos': 'ছবির সাথে সেভ করা ম্যাপ',
  'Reports': 'রিপোর্ট',
  '@n PDF': '@nটি PDF',
  '@n PDFs': '@nটি PDF',
  'Map cache': 'ম্যাপ ক্যাশ',
  '@n map kept so places you visit again need no download. Clearing it '
          'never affects your photos.':
      '@nটি ম্যাপ রাখা আছে, তাই একই জায়গায় আবার গেলে ডাউনলোড লাগে না। '
      'এটি মুছলে আপনার ছবির কোনো ক্ষতি হয় না।',
  '@n maps kept so places you visit again need no download. Clearing it '
          'never affects your photos.':
      '@nটি ম্যাপ রাখা আছে, তাই একই জায়গায় আবার গেলে ডাউনলোড লাগে না। '
      'এটি মুছলে আপনার ছবির কোনো ক্ষতি হয় না।',
  'Map cache cleared': 'ম্যাপ ক্যাশ মুছে ফেলা হয়েছে',
  'Clear @size': '@size মুছুন',

  // Backup.
  'Create backup': 'ব্যাকআপ বানান',
  'One ZIP file with all photos, watermarked copies, maps, reports, '
          'projects and watermark settings. Save it to Files, Google Drive or '
          'a computer.':
      'সব ছবি, ওয়াটারমার্ক কপি, ম্যাপ, রিপোর্ট, প্রজেক্ট ও ওয়াটারমার্ক সেটিংস '
      'নিয়ে একটি ZIP ফাইল। এটি Files, Google Drive বা কম্পিউটারে সেভ করুন।',
  'Restore from backup': 'ব্যাকআপ থেকে রিস্টোর করুন',
  'Adds what is missing from a backup. Nothing on this phone is replaced or '
          'deleted.':
      'ব্যাকআপ থেকে যা নেই তা যোগ করে। এই ফোনের কিছুই বদলানো বা মুছে ফেলা হয় না।',
  'Creating backup': 'ব্যাকআপ বানানো হচ্ছে',
  'Adding file @done of @total': '@total-টির মধ্যে @doneটি ফাইল যোগ হচ্ছে',
  'Backup saved: @n photo, @files files':
      'ব্যাকআপ সেভ হয়েছে: @nটি ছবি, @filesটি ফাইল',
  'Backup saved: @n photos, @files files':
      'ব্যাকআপ সেভ হয়েছে: @nটি ছবি, @filesটি ফাইল',
  'Backup not saved': 'ব্যাকআপ সেভ হয়নি',
  'No app can save files on this phone.':
      'এই ফোনে ফাইল সেভ করার মতো কোনো অ্যাপ নেই।',
  'The backup could not be saved there. Try another location.':
      'ব্যাকআপ সেখানে সেভ করা যায়নি। অন্য কোনো জায়গা বেছে নিন।',
  'Restore this backup?': 'এই ব্যাকআপ রিস্টোর করবেন?',
  'You chose this backup just before Android restarted the app.': 'Android অ্যাপটি আবার চালু করার ঠিক আগে আপনি এই ব্যাকআপটি বেছে নিয়েছিলেন।',
  'Photos, watermarked copies, maps, reports and projects that are not on '
          'this phone yet will be added. Files and projects already here stay '
          'exactly as they are.':
      'যেসব ছবি, ওয়াটারমার্ক কপি, ম্যাপ, রিপোর্ট ও প্রজেক্ট এই ফোনে এখনও নেই, '
      'সেগুলো যোগ হবে। যা আগে থেকে আছে তা যেমন আছে তেমনই থাকবে।',
  'Restore': 'রিস্টোর',
  'Restoring backup': 'ব্যাকআপ রিস্টোর হচ্ছে',
  'Checking file @done of @total': '@total-টির মধ্যে @doneটি ফাইল দেখা হচ্ছে',
  'Keep the app open until this finishes.':
      'শেষ না হওয়া পর্যন্ত অ্যাপটি খোলা রাখুন।',
  'Already up to date': 'সবকিছু আগে থেকেই আছে',
  'Backup restored': 'ব্যাকআপ রিস্টোর হয়েছে',
  'Everything in this backup is already on this phone.':
      'এই ব্যাকআপের সবকিছু আগে থেকেই এই ফোনে আছে।',
  '@n file': '@nটি ফাইল',
  '@n files': '@nটি ফাইল',
  'Added @n photo (@files in total).': '@nটি ছবি যোগ হয়েছে (মোট @files)।',
  'Added @n photos (@files in total).': '@nটি ছবি যোগ হয়েছে (মোট @files)।',
  'Added @n project.': '@nটি প্রজেক্ট যোগ হয়েছে।',
  'Added @n projects.': '@nটি প্রজেক্ট যোগ হয়েছে।',
  '@n photo put back in their projects.':
      '@nটি ছবি আবার তাদের প্রজেক্টে রাখা হয়েছে।',
  '@n photos put back in their projects.':
      '@nটি ছবি আবার তাদের প্রজেক্টে রাখা হয়েছে।',
  'Watermark settings restored.': 'ওয়াটারমার্ক সেটিংস রিস্টোর হয়েছে।',
  '@n file skipped because they already exist.':
      '@nটি ফাইল আগে থেকেই আছে বলে বাদ দেওয়া হয়েছে।',
  '@n files skipped because they already exist.':
      '@nটি ফাইল আগে থেকেই আছে বলে বাদ দেওয়া হয়েছে।',
  'The backup could not be created. Check that the phone has free space and '
          'try again.':
      'ব্যাকআপ বানানো যায়নি। ফোনে জায়গা খালি আছে কি না দেখে আবার চেষ্টা করুন।',
  'The file could not be read.': 'ফাইলটি পড়া যায়নি।',
  'The backup could not be read. It may be damaged or incomplete.':
      'ব্যাকআপ পড়া যায়নি। ফাইলটি নষ্ট বা অসম্পূর্ণ হতে পারে।',
  'A backup is already in progress.': 'একটি ব্যাকআপ এখন চলছে।',
  'This file is not a GPS Camera backup.':
      'এই ফাইলটি GPS Camera-এর ব্যাকআপ নয়।',
  'This backup was made by a newer version of the app. Update the app and '
          'try again.':
      'এই ব্যাকআপ অ্যাপের নতুন ভার্সনে বানানো। অ্যাপ আপডেট করে আবার চেষ্টা করুন।',
};
