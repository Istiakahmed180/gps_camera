# Google Drive ব্যাকআপ সেটআপ

Locaproof-এর Google Drive ব্যাকআপ চালু করতে Google Cloud-এ একবার এই সেটআপ করতে হবে। এটা ছাড়া অ্যাপ আগের মতোই চলবে, শুধু Settings-এ লেখা থাকবে "Google Drive backup is not set up in this version of the app."

অ্যাপ শুধু `drive.file` অনুমতি চায়। এতে Locaproof শুধু নিজের বানানো "Locaproof Backup" ফোল্ডার আর তার ফাইলগুলো দেখতে পায়, ব্যবহারকারীর Drive-এর আর কিছু না। এটা Google-এর "non-sensitive" scope, তাই Google-এর আলাদা নিরাপত্তা যাচাই (security assessment) লাগে না।

## ১. Google Cloud প্রজেক্ট

1. <https://console.cloud.google.com/> খুলুন, উপরের প্রজেক্ট তালিকা থেকে **New Project**। নাম দিন যেমন `Locaproof`।
2. **APIs & Services → Library** থেকে **Google Drive API** খুঁজে **Enable** করুন।

## ২. OAuth consent screen (Google Auth Platform)

1. **APIs & Services → OAuth consent screen** (নতুন নাম **Google Auth Platform → Branding**)।
2. App name: `Locaproof`, support email আর developer contact email দিন।
3. Audience: **External**।
4. **Data Access → Add or remove scopes** থেকে শুধু `.../auth/drive.file` যোগ করুন।
5. পরীক্ষার সময় অ্যাপ "Testing" অবস্থায় থাকে; **Test users**-এ যে Google অ্যাকাউন্ট দিয়ে পরীক্ষা করবেন সেটা যোগ করুন। Play Store-এ ছাড়ার আগে **Publish app** চাপুন।

## ৩. OAuth client: দুটো লাগবে

**Credentials → Create credentials → OAuth client ID**

### ক) Android client

- Application type: **Android**
- Package name: `com.locaproof.app`
- SHA-1 certificate fingerprint: যে key দিয়ে অ্যাপ সই হয় তার SHA-1।
  - এখনকার বিল্ড (debug key দিয়ে সই, release-ও):
    `07:F2:B7:D7:CE:02:25:04:60:F8:7B:C7:8B:F1:10:66:14:7D:8D:67`
  - পরে নিজস্ব release keystore বানালে তার SHA-1 দিয়ে আরেকটা Android client বানাবেন:
    ```bash
    keytool -list -v -keystore upload-keystore.jks -alias upload
    ```
  - Play Store-এ "Play App Signing" চালু থাকলে Play Console → **App integrity** থেকে **App signing key**-এর SHA-1 দিয়েও একটা Android client বানাতে হবে, না হলে Play Store থেকে নামানো অ্যাপে সাইন-ইন কাজ করবে না।

### খ) Web client

- Application type: **Web application**, নাম যেমন `Locaproof server`। কোনো URL লাগবে না।
- তৈরি হলে যে **Client ID** দেখায় (`…apps.googleusercontent.com`), সেটাই অ্যাপে দিতে হবে। এটা গোপন কিছু না, কিন্তু **Client secret** কোথাও দেবেন না।

## ৪. অ্যাপে Client ID

"Locaproof server" Web client-এর ID অ্যাপে বসানো আছে (`lib/core/config/google_config.dart`), তাই সাধারণ বিল্ডেই Drive ব্যাকআপ চালু:

```bash
flutter build apk --release
```

অন্য Google Cloud প্রজেক্ট ব্যবহার করতে চাইলে বিল্ডের সময় অন্য ID দেওয়া যায়:

```bash
flutter build apk --release --dart-define=GOOGLE_SERVER_CLIENT_ID=123456789-abc.apps.googleusercontent.com
```

## ৫. কীভাবে কাজ করে

- Settings → Backup → **Sign in with Google**। সাইন ইনের পরেই প্রথম ব্যাকআপ শুরু হয়।
- Drive-এ "Locaproof Backup" ফোল্ডারে অ্যাপের মতোই ফোল্ডার: `Photos`, `Watermarked`, `Maps`, `Reports`, `Branding`, আর প্রজেক্ট ও সেটিংসের জন্য `backup.json`।
- শুধু নতুন বা বদলানো ফাইল যায়। ফোন থেকে কোনো ছবি মুছলেও Drive-এ থেকে যায়।
- নিজে থেকে ব্যাকআপ হয় অ্যাপ খুললে, অ্যাপে ফিরলে আর ক্যামেরা বন্ধ করার পরে (প্রতি ১৫ মিনিটে সর্বোচ্চ একবার, ক্যামেরার পরে সঙ্গে সঙ্গে)। ডিফল্টে শুধু Wi-Fi-তে; "Back up now" যেকোনো সংযোগে চলে।
- অ্যাপ পুরো বন্ধ থাকলে ব্যাকআপ চলে না।
- **Restore**: নতুন ফোনে বা আবার ইনস্টলের পরে একই অ্যাকাউন্টে সাইন ইন করে Restore চাপলে যা নেই তা ফিরে আসে। ফোনে থাকা কিছুই বদলায় না।

## সমস্যা হলে

- "Google sign-in failed": package name বা SHA-1 Android client-এর সাথে মিলছে না, অথবা Web client ID ভুল।
- সাইন-ইন স্ক্রিনে অ্যাকাউন্ট বাছার পর কিছু না হয়ে বন্ধ হয়ে যায়: সাধারণত SHA-1 মেলেনি, অথবা অ্যাপ "Testing"-এ আছে আর অ্যাকাউন্টটা Test users-এ নেই।
