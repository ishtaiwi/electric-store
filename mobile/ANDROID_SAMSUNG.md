# تشغيل التطبيق على سامسونج (Android)

المشروع جاهز في مجلد `mobile/`. تحتاج أولاً **Android Studio** لأن الجهاز حالياً بدون Android SDK.

## 1) تثبيت Android Studio على الكمبيوتر

1. حمّل من: https://developer.android.com/studio  
2. ثبّت واختر أثناء التثبيت:
   - Android SDK
   - Android SDK Platform
   - Android Virtual Device (اختياري)
3. افتح Android Studio → **More Actions → SDK Manager**
4. تبويب **SDK Platforms**: فعّل أحدث Android (مثلاً 35) + API 34
5. تبويب **SDK Tools**: فعّل
   - Android SDK Build-Tools
   - Android SDK Platform-Tools
   - Android SDK Command-line Tools
6. Apply / OK

تحقق:

```powershell
flutter doctor
```

لازم يصير بند Android toolchain بلون أخضر (أو يقبل التراخيص):

```powershell
flutter doctor --android-licenses
```

(اضغط `y` لكل سؤال)

## 2) تجهيز جوال سامسونج

1. **الإعدادات → حول الهاتف → معلومات البرنامج**
2. اضغط **رقم البناء** 7 مرات حتى تظهر "أصبحت مطوراً"
3. ارجع **الإعدادات → خيارات المطوّر**
4. فعّل:
   - **USB debugging** (تصحيح أخطاء USB)
   - **Install via USB** إن وُجد
5. وصّل الجوال بالكمبيوتر بكابل USB
6. على الجوال اختر وضع USB: **نقل ملفات (MTP)** أو **USB for file transfer**
7. اقبل رسالة **Allow USB debugging?** (ضع علامة Always allow)

اختياري لسامسونج: ثبّت [Samsung USB Driver](https://developer.samsung.com/android-usb-driver) إن الجهاز ما ظهر.

## 3) تشغيل التطبيق

```powershell
cd c:\Users\osama\Desktop\electricalStore\mobile
flutter devices
```

لازم يظهر جهاز مثل `SM-A...` أو اسم سامسونج.

ثم:

```powershell
flutter run
```

أو حدد الجهاز صراحة:

```powershell
flutter run -d <device_id>
```

سجّل دخول بنفس مستخدم الديسكتوب (مثلاً `admin`).

## 4) تثبيت بدون كابل (APK)

بعد ما يشتغل `flutter doctor` صح:

```powershell
cd c:\Users\osama\Desktop\electricalStore\mobile
flutter build apk --release
```

الملف يظهر هنا:

```text
mobile\build\app\outputs\flutter-apk\app-release.apk
```

انقله للجوال وثبّته (فعّل "مصادر غير معروفة" إن طلب منك).

## مشاكل شائعة

| المشكلة | الحل |
|---------|------|
| الجهاز ما يظهر | بدّل كابل/منفذ USB، فعّل USB debugging، ثبّت Samsung USB Driver |
| `unauthorized` | افصل/وصّل واقبل نافذة السماح على الجوال |
| فشل البناء أول مرة | انتظر تنزيل Gradle (طويل أول مرة)، تأكد من الإنترنت |
| لا إنترنت في التطبيق | تحقق أن الجوال على Wi‑Fi وأن Supabase يشتغل |
