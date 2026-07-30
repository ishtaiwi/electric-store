# دليل تشغيل قاعدة بيانات Supabase — Electrical Store

هذا الدليل يشرح **خطوة بخطوة** كيف تنقل بيانات `d.db` إلى Supabase وتشغّل المزامنة الهجينة (SQLite محلي + سحابة).

---

## الفكرة باختصار

| الطبقة | الدور |
|--------|--------|
| **SQLite (`d.db`)** | القاعدة الأساسية للعمل اليومي — التطبيق يشتغل بدون إنترنت |
| **Supabase (PostgreSQL)** | نسخة سحابية للنسخ الاحتياطي والعمل من أكثر من جهاز |
| **المزامنة** | من شاشة الإعدادات: رفع / تنزيل / مزامنة كاملة |

تسجيل الدخول يبقى كما هو عبر جدول `users` (نفس المستخدمين وكلمات المرور).

---

## المتطلبات

1. حساب على [https://supabase.com](https://supabase.com)
2. Python 3.10+ (لسُكربت النقل) — عندك موجود
3. Flutter SDK لمشروع التطبيق
4. ملف `d.db` في مجلد المشروع

---

## الخطوة 1: إنشاء مشروع Supabase

1. ادخل لوحة [Supabase Dashboard](https://supabase.com/dashboard)
2. اضغط **New project**
3. اختر Organization، اسم المشروع (مثلاً `electrical-store`)، وقاعدة بيانات بكلمة مرور قوية
4. اختر أقرب منطقة (Region) ثم **Create project**
5. انتظر حتى يصبح المشروع جاهزاً (دقيقة أو دقيقتين)

---

## الخطوة 2: نسخ مفاتيح الاتصال

1. من المشروع: **Project Settings** (أيقونة الترس) → **API**
2. انسخ واحفظ عندك:

| الاسم | أين تجده | الاستخدام |
|--------|-----------|------------|
| **Project URL** | `https://xxxxx.supabase.co` | في التطبيق + سكربت النقل |
| **anon public** | `eyJ...` | في التطبيق (الإعدادات) |
| **service_role** | `eyJ...` (سري جداً) | **فقط** لسكربت النقل الأولي — لا تضعه في التطبيق |

> لا تشارك `service_role` مع أحد ولا ترفعه على Git.

---

## الخطوة 3: إنشاء الجداول (Schema)

1. من القائمة: **SQL Editor** → **New query**
2. افتح الملف من جهازك:

```
supabase/schema.sql
```

3. انسخ **كامل** محتوى الملف والصقه في المحرر
4. اضغط **Run**
5. يجب أن تظهر رسالة مشابهة لـ:

```text
Electrical Store schema created successfully
```

هذا ينشئ كل الجداول (~20 جدول)، الفهارس، وتهيئة **Row Level Security** للسماح للتطبيق بالوصول عبر مفتاح `anon`.

---

## الخطوة 4: نقل بيانات `d.db` إلى Supabase

من مجلد المشروع في Terminal / PowerShell:

### أ) تثبيت مكتبات بايثون (مرة واحدة)

```powershell
cd c:\Users\osama\Desktop\electricalStore\supabase
pip install -r requirements.txt
```

### ب) الخيار الموصى به: تصدير ملف SQL ثم تشغيله في Supabase

```powershell
python migrate_from_sqlite.py --db ..\d.db --out data_export.sql
```

ثم:

1. افتح `supabase/data_export.sql`
2. في Supabase → **SQL Editor** → الصق المحتوى → **Run**

> ملاحظة: ملف التصدير قد يكون كبيراً؛ إذا فشل المحرر بسبب الحجم استخدم خيار الرفع المباشر أدناه.

### ج) خيار الرفع المباشر عبر API (مع service_role)

```powershell
python migrate_from_sqlite.py --db ..\d.db --upload --clear `
  --url "https://xxxxx.supabase.co" `
  --key "YOUR_SERVICE_ROLE_KEY"
```

`--clear` يمسح الجداول السحابية قبل الرفع (مناسب لأول مرة).

### د) التحقق بعد النقل

في SQL Editor:

```sql
SELECT 'users' AS t, COUNT(*) FROM users
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'customers', COUNT(*) FROM customers
UNION ALL SELECT 'invoices', COUNT(*) FROM invoices
UNION ALL SELECT 'sales', COUNT(*) FROM sales;
```

تأكد أن الأرقام منطقية مقارنة بـ `d.db`.

---

## الخطوة 5: تجهيز التطبيق (Flutter)

```powershell
cd c:\Users\osama\Desktop\electricalStore
flutter pub get
flutter run -d windows
```

---

## الخطوة 6: ربط التطبيق بـ Supabase

1. سجّل دخول كـ **admin**
2. افتح **الإعدادات (Settings)**
3. انزل لقسم **مزامنة سحابة Supabase**
4. الصق:
   - **Project URL**
   - **Anon Key** (وليس service_role)
5. فعّل **تفعيل المزامنة السحابية**
6. (اختياري) فعّل **مزامنة تلقائية عند التشغيل**
7. اضغط **حفظ إعدادات السحابة**
8. اضغط **اختبار الاتصال** — يجب أن تظهر رسالة نجاح
9. اضغط **مزامنة الآن** (رفع + تنزيل)

أزرار مفيدة:

| الزر | المعنى |
|------|--------|
| مزامنة الآن | رفع المحلي ثم تنزيل السحابة |
| رفع فقط | يرسل `d.db` المحلي → Supabase |
| تنزيل فقط | يجلب Supabase → يستبدل بيانات الجداول المحلية |

> بيانات مفاتيح Supabase تُحفظ محلياً ولا تُستبدل عند التنزيل.

---

## الخطوة 7: العمل اليومي (Hybrid)

1. **بدون نت:** التطبيق يعمل بشكل طبيعي على SQLite
2. **مع نت:** اضغط مزامنة، أو فعّل المزامنة التلقائية عند التشغيل
3. على جهاز ثاني:
   - ثبّت التطبيق
   - أدخل نفس URL و Anon Key
   - اضغط **تنزيل فقط** أو **مزامنة الآن**

---

## الأمان (مهم)

- الـ policies الحالية تسمح لدور `anon` بالقراءة/الكتابة على كل الجداول — مناسب لبرنامج محل داخلي.
- **لا تنشر** رابط المشروع + مفتاح anon على الإنترنت العام.
- احفظ `service_role` خارج المشروع ولا تضعه في الكود.
- اختياري لاحقاً: قيّد الوصول من **Network Restrictions** في إعدادات Supabase، أو انتقل لـ Supabase Auth.

---

## استكشاف الأخطاء

| المشكلة | الحل |
|---------|------|
| فشل الاتصال | تأكد من URL بدون `/` زائد في النهاية، وأن anon key صحيح |
| جداول فارغة بعد Schema | لم تشغّل سكربت النقل أو `data_export.sql` |
| خطأ Foreign Key عند الاستيراد | شغّل `schema.sql` أولاً دائماً |
| المزامنة فشلت جزئياً | راجع رسائل الأخطاء في Snackbar؛ غالباً جدول واحد ناقص أعمدة — أعد تشغيل `schema.sql` |
| أجهزة متعارضة | قرّر أي جهاز «مصدر الحقيقة» وارفع منه أولاً (`رفع فقط`) ثم نزّل على الباقي |

---

## هيكل الملفات المضافة

```text
supabase/
  schema.sql                 ← أنشئ الجداول في Supabase
  migrate_from_sqlite.py     ← نقل البيانات من d.db
  requirements.txt
  data_export.sql            ← يُنشأ بعد تشغيل السكربت
  SETUP_GUIDE_AR.md          ← هذا الدليل

lib/core/supabase/
  supabase_config.dart
  supabase_client_service.dart
lib/core/services/sync_service.dart
```

---

## ملخص سريع (Checklist)

- [ ] إنشاء مشروع Supabase
- [ ] نسخ Project URL + anon key + service_role
- [ ] تشغيل `supabase/schema.sql` في SQL Editor
- [ ] تشغيل `migrate_from_sqlite.py` ونقل البيانات
- [ ] التحقق بعدّ الجداول
- [ ] `flutter pub get` وتشغيل التطبيق
- [ ] إدخال المفاتيح في الإعدادات
- [ ] اختبار الاتصال ثم المزامنة

بعد إكمال القائمة، قاعدتك السحابية جاهزة والتطبيق يعمل هجيناً (محلي + Supabase).
