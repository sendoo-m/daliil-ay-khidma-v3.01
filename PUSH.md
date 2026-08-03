# رفع المشروع على GitHub

## ويندوز — CMD

افتح CMD، وادخل المجلد اللي فيه `setup.bat`، وشغّله ومعاه مسار الإصدار الثاني:

```
cd /d "D:\2025\daliil-ay-khidma-v3\v3"

setup.bat "D:\2025\daliil-ay-khidma-v3\daliil-ay-khidma-v2.01-master"
```

**المسار لازم يكون المجلد، مش ملف `manage.py` جواه.**

لو `setup.bat` مش موجود في المجلد، يبقى عندك نسخة قديمة من المشروع — نزّل الأحدث.

بعد ما يخلص:

```
git commit -m "feat: v3 foundation"
git push -u origin main
```

---

## ماك / لينكس / Git Bash

```bash
cd "/path/to/v3"
./setup.sh "/path/to/daliil-ay-khidma-v2.01-master"

git commit -m "feat: v3 foundation"
git push -u origin main
```

السكربت بيقبل مسارات ويندوز بالشرطات المقلوبة، وبيقبل كمان لو انتهى بـ`manage.py`.

---

## عند الرفع

Git هيطلب اسم المستخدم و**token** — مش كلمة السر العادية. GitHub وقف قبول كلمات السر في الرفع من ٢٠٢١.

تعمل token من: **GitHub ← Settings ← Developer settings ← Personal access tokens ← Fine-grained**

خليها على الريبو ده وحده، وبصلاحية واحدة: **Contents → Read and write**.

بعد الرفع: **Settings ← Pages ← Source: GitHub Actions**

---

## 1. أنشئ المستودع

من متصفحك: <https://github.com/new>

| الحقل | القيمة |
|---|---|
| Repository name | `daliil-ay-khidma-v3.01` |
| Visibility | Public (مطلوب لـGitHub Pages على الحساب المجاني) |
| Initialize | **لا تختر** README ولا .gitignore ولا license |

المستودع لازم يكون فاضي، لأن أول دفعة ستحمل كل شيء.

---

## 2. ادفع الملفات

من مجلد المشروع بعد فك الضغط:

```bash
cd daliil-ay-khidma-v3

git init
git add .
git commit -m "chore: v3 foundation — RBAC, audit log, shared core, admin app"
git branch -M main
git remote add origin https://github.com/sendoo-m/daliil-ay-khidma-v3.01.git
git push -u origin main
```

لو طلب منك اسم مستخدم وكلمة سر عند الدفع، اكتب اسم المستخدم واستعمل **personal access token** مكان كلمة السر. تنشئه من: Settings ← Developer settings ← Personal access tokens ← Fine-grained tokens، بصلاحية `Contents: Read and write` على هذا المستودع وحده.

أسهل بديل: [GitHub CLI](https://cli.github.com) — `gh auth login` مرة واحدة ثم `gh repo create` وينتهي الأمر.

---

## 3. فعّل GitHub Pages

في المستودع: **Settings ← Pages ← Build and deployment**

اختر **Source: GitHub Actions**. لا تختر "Deploy from a branch" — الـworkflow يتولى النشر.

بعد أول دفعة، تابع التقدم من تبويب **Actions**. البناء يأخذ خمس إلى ثماني دقائق (يبني تطبيقين).

---

## 4. الرابطان

بعد نجاح الـworkflow:

```
تطبيق المستخدم   https://sendoo-m.github.io/daliil-ay-khidma-v3.01/
لوحة الإدارة    https://sendoo-m.github.io/daliil-ay-khidma-v3.01/admin/
```

---

## قبل الدفعة الأولى — ثلاث نواقص

**١. تطبيق المستخدم غير منسوخ.** انسخه من v2:

```bash
cp -r ../daliil-ay-khidma-v2.01/mobile/dalil_app/* mobile/apps/user/
```

ثم في `mobile/apps/user/pubspec.yaml` أضف الحزمة المشتركة:

```yaml
dependencies:
  dalil_core:
    path: ../../packages/dalil_core
```

بدون هذه الخطوة، خطوة "Build user app" في الـworkflow هتفشل.

**٢. الخادم غير منسوخ.** انسخ محتوى v2 إلى `backend/`، ثم ادمج ملفات `apps/administration` و`apps/api` الجديدة فوقه.

**٣. `API_BASE_URL`.** في `.github/workflows/pages.yml` عدّل قيمة `API_BASE_URL` لعنوان خادمك الفعلي، وتأكد أن `CORS_ALLOWED_ORIGINS` في Django يسمح بـ`https://sendoo-m.github.io`. بدونه التطبيقان هيحمّلا لكن كل طلب هيفشل.

---

## ملاحظة أمان

`.gitignore` يستبعد `.env` و`db.sqlite3`. تأكد قبل أول `git add .` أن `SECRET_KEY` ومفاتيح Cloudinary وFirebase مش مكتوبة في `settings/base.py` مباشرة — لو كانت، انقلها لمتغيرات بيئة أولًا. أي مفتاح يدخل تاريخ Git يفضل فيه حتى بعد حذفه.
