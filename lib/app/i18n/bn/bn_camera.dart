/// Camera, GPS status, onboarding and home screen text.
const Map<String, String> bnCamera = {
  // Background work
  'Your backup was saved.': 'আপনার ব্যাকআপ সেভ হয়েছে।',
  'The backup could not be saved. Create it again in Settings.':
      'ব্যাকআপ সেভ করা যায়নি। সেটিংস থেকে আবার তৈরি করুন।',

  // Note dialog
  'e.g. Crack on pillar 3, north side': 'যেমন: 3 নম্বর পিলারের উত্তর পাশে ফাটল',
  'Note for new photos': 'নতুন ছবির নোট',
  'Added to every photo you take until you change or remove it. '
          'Shown on the watermark and in reports.':
      'যতক্ষণ না বদলান বা সরান, প্রতিটি নতুন ছবিতে এটি যোগ হবে। '
      'ওয়াটারমার্ক ও রিপোর্টে দেখা যাবে।',

  // Capture feedback
  'Flash could not be changed: @error': 'ফ্ল্যাশ বদলানো যায়নি: @error',
  'Capture failed: @error': 'ছবি তোলা যায়নি: @error',
  'Photo could not be saved: @error': 'ছবি সেভ করা যায়নি: @error',
  'Something went wrong while capturing.':
      'ছবি তোলার সময় কিছু একটা সমস্যা হয়েছে।',
  'the project': 'প্রজেক্ট',
  '@base, but it could not be added to @project':
      '@base, কিন্তু @project-এ যোগ করা যায়নি',
  'Photo saved, but its location data could not be saved':
      'ছবি সেভ হয়েছে, কিন্তু লোকেশনের তথ্য সেভ করা যায়নি',
  'Photo saved · no location': 'ছবি সেভ হয়েছে · লোকেশন নেই',
  'Photo saved · last known location': 'ছবি সেভ হয়েছে · সর্বশেষ জানা লোকেশন',
  'Photo saved · poor GPS accuracy': 'ছবি সেভ হয়েছে · GPS নির্ভুলতা কম',
  'Photo saved with location': 'লোকেশনসহ ছবি সেভ হয়েছে',

  // Post-processing messages. Error messages must contain the translation
  // of 'not saved'; the lone 'Not saved to phone gallery' is not an error.
  'not saved': 'সেভ হয়নি',
  'Not saved to phone gallery': 'ফোনের গ্যালারিতে রাখা হয়নি',
  '@message · not saved to phone gallery':
      '@message · ফোনের গ্যালারিতে সেভ হয়নি',
  'Watermarked copy not saved: photo unreadable':
      'ওয়াটারমার্ক কপি সেভ হয়নি: ছবিটি পড়া যাচ্ছে না',
  'Watermarked copy saved': 'ওয়াটারমার্ক কপি সেভ হয়েছে',
  'Watermarked copy not saved: @error': 'ওয়াটারমার্ক কপি সেভ হয়নি: @error',
  'Watermarked copy not saved': 'ওয়াটারমার্ক কপি সেভ হয়নি',

  // Camera errors
  'Camera permission could not be checked on this device.':
      'এই ফোনে ক্যামেরার অনুমতি যাচাই করা যায়নি।',
  'Cameras could not be listed: @error':
      'ক্যামেরাগুলো খুঁজে পাওয়া যায়নি: @error',
  'The camera is not available on this device.':
      'এই ফোনে ক্যামেরা পাওয়া যাচ্ছে না।',
  'No camera was found on this device.': 'এই ফোনে কোনো ক্যামেরা পাওয়া যায়নি।',
  'The camera could not be started: @error': 'ক্যামেরা চালু করা যায়নি: @error',

  // Viewfinder messages
  'Starting camera…': 'ক্যামেরা চালু হচ্ছে…',
  'Camera access needed': 'ক্যামেরার অনুমতি দরকার',
  'Allow camera access to capture site photos.':
      'সাইটের ছবি তুলতে ক্যামেরার অনুমতি দিন।',
  'Allow camera': 'ক্যামেরার অনুমতি দিন',
  'Camera access is turned off': 'ক্যামেরার অনুমতি বন্ধ আছে',
  'Enable the camera permission for Locaproof in system '
          'settings, then return to the app.':
      'ফোনের সেটিংসে Locaproof-র জন্য ক্যামেরার অনুমতি চালু করুন, '
      'তারপর অ্যাপে ফিরে আসুন।',
  'Open settings': 'সেটিংস খুলুন',
  'Camera unavailable': 'ক্যামেরা পাওয়া যাচ্ছে না',

  // Camera controls
  'Close camera': 'ক্যামেরা বন্ধ করুন',
  'Flash: @mode': 'ফ্ল্যাশ: @mode',
  'Auto': 'অটো',
  'On': 'চালু',
  'Off': 'বন্ধ',
  'Switch camera': 'ক্যামেরা বদলান',
  'Hide grid': 'গ্রিড লুকান',
  'Show grid': 'গ্রিড দেখান',
  'Timer: @value': 'টাইমার: @value',
  'Timer off': 'টাইমার বন্ধ',
  '3 s': '3 সেকেন্ড',
  '10 s': '10 সেকেন্ড',
  'Edit note for new photos': 'নতুন ছবির নোট এডিট করুন',
  'Add a note': 'নোট যোগ করুন',
  'Zoom @value': 'জুম @value',
  'Add watermark': 'ওয়াটারমার্ক যোগ করুন',
  'Add watermark to last photo': 'শেষ ছবিতে ওয়াটারমার্ক যোগ করুন',
  'Capturing photo': 'ছবি তোলা হচ্ছে',
  'Cancel timer': 'টাইমার বাতিল করুন',
  'Capture photo': 'ছবি তুলুন',

  // Photo quality (labels shown in Settings)
  'Standard': 'স্ট্যান্ডার্ড',
  'Full HD, about 2 MP · smallest files':
      'Full HD, প্রায় 2 MP · সবচেয়ে ছোট ফাইল',
  '4K, about 8 MP · recommended': '4K, প্রায় 8 MP · প্রস্তাবিত',
  'Maximum': 'সর্বোচ্চ',
  'Full camera resolution · largest files, slower to process':
      'ক্যামেরার পূর্ণ রেজোলিউশন · সবচেয়ে বড় ফাইল, প্রসেস হতে বেশি সময় লাগে',

  // GPS status panel
  'GPS: @title. @detail': 'GPS: @title. @detail',
  'Updating GPS · last known location': 'GPS আপডেট হচ্ছে · সর্বশেষ জানা লোকেশন',
  'GPS signal lost · last known location':
      'GPS সিগন্যাল নেই · সর্বশেষ জানা লোকেশন',
  'GPS ready · Good accuracy': 'GPS প্রস্তুত · ভালো নির্ভুলতা',
  'GPS ready · Moderate accuracy': 'GPS প্রস্তুত · মাঝারি নির্ভুলতা',
  'Poor GPS accuracy': 'GPS নির্ভুলতা কম',
  'Acquiring GPS…': 'GPS খোঁজা হচ্ছে…',
  'Waiting for the first location fix': 'প্রথম লোকেশনের জন্য অপেক্ষা চলছে',
  'Location permission needed': 'লোকেশনের অনুমতি দরকার',
  'Photos are saved without location': 'ছবি লোকেশন ছাড়াই সেভ হবে',
  'Allow': 'অনুমতি দিন',
  'Location access is turned off': 'লোকেশনের অনুমতি বন্ধ আছে',
  'Enable it in app settings to tag photos':
      'ছবিতে লোকেশন যোগ করতে অ্যাপ সেটিংসে এটি চালু করুন',
  'Location services are off': 'লোকেশন সার্ভিস বন্ধ আছে',
  'Turn on device location to tag photos':
      'ছবিতে লোকেশন যোগ করতে ফোনের লোকেশন চালু করুন',
  'Turn on': 'চালু করুন',
  'GPS unavailable': 'GPS পাওয়া যাচ্ছে না',
  'No location fix yet. Try moving to open sky.':
      'এখনও লোকেশন পাওয়া যায়নি। খোলা আকাশের নিচে গিয়ে চেষ্টা করুন।',
  'Retry': 'আবার চেষ্টা',

  // Home
  'Gallery': 'গ্যালারি',
  'Projects': 'প্রজেক্ট',
  'Reports': 'রিপোর্ট',
  'Open camera': 'ক্যামেরা খুলুন',
  'Location access needed': 'লোকেশনের অনুমতি দরকার',
  'Tap to allow location': 'লোকেশনের অনুমতি দিতে ট্যাপ করুন',
  'Location access is off for Locaproof': 'Locaproof-এর লোকেশন অনুমতি বন্ধ',
  'Tap to open settings': 'সেটিংস খুলতে ট্যাপ করুন',
  'Phone location is off': 'ফোনের লোকেশন বন্ধ',
  'Tap to turn it on': 'চালু করতে ট্যাপ করুন',
  'Location not found yet. Tap to try again.':
      'লোকেশন এখনো পাওয়া যায়নি। আবার চেষ্টা করতে ট্যাপ করুন।',
  'Finding your location…': 'আপনার লোকেশন খোঁজা হচ্ছে…',
  'Last known location · @accuracy': 'শেষ জানা লোকেশন · @accuracy',
  'Current location · @accuracy': 'বর্তমান লোকেশন · @accuracy',
  'Home': 'হোম',
  'Capture proof': 'প্রমাণসহ ছবি তুলুন',
  'Photos and videos stamped with location, date and time.':
      'লোকেশন, তারিখ আর সময়ের স্ট্যাম্পসহ ছবি ও ভিডিও।',
  'Recent captures': 'সাম্প্রতিক ছবি',
  'See all': 'সব দেখুন',
  'Active projects': 'চলমান প্রজেক্ট',
  'No captures yet': 'এখনো কোনো ছবি নেই',
  'Your photos and videos will appear here.':
      'আপনার তোলা ছবি আর ভিডিও এখানে দেখাবে।',

  // Onboarding
  'Go to home': 'হোমে যান',
  'Welcome to Locaproof': 'Locaproof-তে স্বাগতম',
  'Photos that prove where and when they were taken.':
      'ছবি কোথায় ও কখন তোলা হয়েছে, তার প্রমাণসহ ছবি।',
  'Location stamp': 'লোকেশন স্ট্যাম্প',
  'Address, map, coordinates, time and direction on every photo. '
          'The original is always kept too.':
      'প্রতিটি ছবিতে ঠিকানা, ম্যাপ, কোঅর্ডিনেট, সময় ও দিক। '
      'অরিজিনাল ছবিটিও সবসময় রাখা হয়।',
  'Projects and reports': 'প্রজেক্ট ও রিপোর্ট',
  'Group photos by site or client and share them as a PDF report.': 'সাইট বা ক্লায়েন্ট অনুযায়ী ছবি সাজান এবং PDF রিপোর্ট হিসেবে শেয়ার করুন।',
  'Works offline': 'অফলাইনেও চলে',
  'Photos, GPS and reports work without internet. Addresses and '
          'maps are added once you are online.':
      'ইন্টারনেট ছাড়াই ছবি, GPS ও রিপোর্ট কাজ করে। অনলাইনে এলে '
      'ঠিকানা ও ম্যাপ যোগ হয়ে যায়।',
  'Two permissions': 'দুটি অনুমতি',
  'Allow these now, or later when you open the camera.':
      'এখনই অনুমতি দিন, অথবা পরে ক্যামেরা খোলার সময় দিন।',
  'Camera': 'ক্যামেরা',
  'To take photos.': 'ছবি তোলার জন্য।',
  'Location': 'লোকেশন',
  'To record where each photo was taken. Only used while '
          'the app is open. Without it, photos have no location.':
      'প্রতিটি ছবি কোথায় তোলা হয়েছে তা রাখার জন্য। শুধু অ্যাপ খোলা '
      'থাকলেই ব্যবহার হয়। অনুমতি না দিলে ছবিতে লোকেশন থাকবে না।',
  'Your photos stay on this phone. To show an address and a '
          'map, only the photo’s coordinates are sent to the '
          'address and map services.':
      'আপনার ছবি এই ফোনেই থাকে। ঠিকানা ও ম্যাপ দেখাতে শুধু ছবির '
      'কোঅর্ডিনেট ঠিকানা ও ম্যাপ সার্ভিসে পাঠানো হয়।',
  '@reason Turned off — allow it in system settings.':
      '@reason বন্ধ আছে — ফোনের সেটিংসে অনুমতি দিন।',
  '@title allowed': '@title অনুমতি দেওয়া হয়েছে',
  'You’re ready': 'আপনি প্রস্তুত',
  'A few things worth knowing:': 'কয়েকটি জরুরি কথা:',
  'Phone gallery': 'ফোনের গ্যালারি',
  'Watermarked photos are also saved to Pictures/Locaproof. '
          'Change this in Settings.':
      'ওয়াটারমার্ক করা ছবি Pictures/Locaproof-তেও সেভ হয়। '
      'সেটিংস থেকে এটি বদলাতে পারবেন।',
  'Notes and branding': 'নোট ও ব্র্যান্ডিং',
  'Add a note in the camera, and your own name or logo in the '
          'watermark editor.':
      'ক্যামেরায় নোট যোগ করুন, আর ওয়াটারমার্ক এডিটরে নিজের নাম বা লোগো দিন।',
  'Back up': 'ব্যাকআপ',
  'Settings → Backup keeps all photos and projects in one file.':
      'সেটিংস → ব্যাকআপ সব ছবি ও প্রজেক্ট একটি ফাইলে রাখে।',
  'Page @page of @count': 'পৃষ্ঠা @page / @count',
};
