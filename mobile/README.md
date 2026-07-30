# Electrical Store — Mobile App

تطبيق موبايل (Android + iOS) يعتمد على **Supabase**.

## الإعداد المحلي (مهم)

المفاتيح **لا تُرفع على GitHub**. ضعها في ملف `.env` بجذر المشروع ثم ولّد ملف الأسرار:

```powershell
cd ..
# عدّل .env (من .env.example)
python supabase/generate_secrets.py
cd mobile
flutter pub get
flutter run
```

هذا ينشئ `lib/core/config/supabase_secrets.dart` (gitignored).

## المحتويات

- تسجيل دخول
- المنتجات
- العملاء + كشف حساب
