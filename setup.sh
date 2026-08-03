#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════
#  تجهيز مستودع v3
# ═══════════════════════════════════════════════════════
#
#  الاستعمال:
#      ./setup.sh                       # يبحث عن مجلد v2 لوحده
#      ./setup.sh /path/to/v2           # أو تحدده بنفسك
#
#  السكربت يقرأ من مجلد v2 ولا يكتب فيه أبدًا.

set -euo pipefail

GREEN=$'\033[0;32m'; RED=$'\033[0;31m'; YELLOW=$'\033[0;33m'
DIM=$'\033[2m'; BOLD=$'\033[1m'; OFF=$'\033[0m'

ok()   { echo "${GREEN}  ✓${OFF} $1"; }
warn() { echo "${YELLOW}  !${OFF} $1"; }
die()  { echo "${RED}  ✗${OFF} $1" >&2; exit 1; }
step() { echo; echo "${BOLD}$1${OFF}"; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

REMOTE="https://github.com/sendoo-m/daliil-ay-khidma-v3.01.git"

echo
echo "${BOLD}تجهيز مستودع دليل أي خدمة — v3${OFF}"
echo "${DIM}$HERE${OFF}"

# ── 1. العثور على مجلد v2 ─────────────────────────────
step "١. البحث عن الإصدار الثاني"

V2="${1:-}"

# تسامح مع مدخلات ويندوز: الشرطات المقلوبة، والمسار المنتهي بـmanage.py
if [[ -n "$V2" ]]; then
  V2="${V2//\\//}"          # D:\a\b  →  D:/a/b
  V2="${V2%/}"               # شيل الشرطة الأخيرة
  V2="${V2%/manage.py}"      # لو مرّر الملف بدل المجلد
fi

if [[ -z "$V2" ]]; then
  for candidate in \
    "$HOME/Downloads/daliil-ay-khidma-v2.01" \
    "$HOME/Downloads/daliil-ay-khidma-v2.01-master" \
    "$HOME/Desktop/daliil-ay-khidma-v2.01" \
    "$HOME/daliil-ay-khidma-v2.01" \
    "../daliil-ay-khidma-v2.01" \
    "../daliil-ay-khidma-v2.01-master"
  do
    if [[ -f "$candidate/manage.py" ]]; then V2="$candidate"; break; fi
  done
fi

# آخر محاولة: بحث في مجلد التنزيلات
if [[ -z "$V2" && -d "$HOME/Downloads" ]]; then
  found="$(find "$HOME/Downloads" -maxdepth 3 -name manage.py -type f 2>/dev/null | head -1 || true)"
  [[ -n "$found" ]] && V2="$(dirname "$found")"
fi

if [[ -z "$V2" || ! -f "$V2/manage.py" ]]; then
  echo
  die "مش لاقي مجلد v2.

ابحث عن الملف اسمه ${BOLD}manage.py${OFF} على جهازك، وشغّل السكربت كده:

    ./setup.sh \"/المسار/للمجلد/اللي-فيه-manage.py\"

لو المشروع لسه مضغوط، فُكّ الضغط الأول."
fi

V2="$(cd "$V2" && pwd)"
ok "الإصدار الثاني: $V2"

[[ -d "$V2/mobile/dalil_app" ]] \
  && ok "تطبيق المستخدم موجود" \
  || warn "مش لاقي mobile/dalil_app — هتحتاج تنسخه يدويًا"

# ── 2. حفظ ملفات v3 الجديدة ───────────────────────────
step "٢. حفظ ملفات v3"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

for path in \
  backend/apps/administration \
  backend/apps/api/serializers/admin.py \
  backend/apps/api/views/admin.py
do
  if [[ -e "$path" ]]; then
    mkdir -p "$STAGE/$(dirname "$path")"
    cp -r "$path" "$STAGE/$path"
  fi
done
ok "ملفات الخادم الجديدة محفوظة مؤقتًا"

# ── 3. نسخ الخادم من v2 ───────────────────────────────
step "٣. نقل الخادم"

mkdir -p backend
for item in apps config templates static locale fixtures scripts \
            manage.py requirements.txt render.yaml
do
  [[ -e "$V2/$item" ]] && cp -r "$V2/$item" backend/ 2>/dev/null || true
done
ok "الخادم اتنقل إلى backend/"

# إرجاع ملفات v3 فوق نسخة v2
cp -r "$STAGE/backend/." backend/
ok "ملفات الإدارة الجديدة اتكتبت فوق القديمة"

# تنظيف ما لا يُرفع
find backend -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true
find backend -name '*.pyc' -delete 2>/dev/null || true
rm -f backend/db.sqlite3
rm -rf backend/logs backend/media/* 2>/dev/null || true
ok "الملفات المؤقتة اتشالت"

# ── 4. نسخ تطبيق المستخدم ─────────────────────────────
step "٤. نقل تطبيق المستخدم"

if [[ -d "$V2/mobile/dalil_app" ]]; then
  mkdir -p mobile/apps/user
  cp -r "$V2/mobile/dalil_app/." mobile/apps/user/
  rm -rf mobile/apps/user/build mobile/apps/user/.dart_tool
  rm -f mobile/apps/user/pubspec.lock
  ok "تطبيق المستخدم اتنقل إلى mobile/apps/user/"

  # ربط الحزمة المشتركة
  PUB="mobile/apps/user/pubspec.yaml"
  if [[ -f "$PUB" ]] && ! grep -q "dalil_core" "$PUB"; then
    python3 - "$PUB" << 'PYEOF'
import sys, re, pathlib
p = pathlib.Path(sys.argv[1])
text = p.read_text(encoding='utf-8')
dep = "  dalil_core:\n    path: ../../packages/dalil_core\n"
# نُدرج بعد أول سطر flutter sdk داخل dependencies
m = re.search(r'^dependencies:\s*\n(\s+flutter:\s*\n\s+sdk:\s+flutter\s*\n)', text, re.M)
if m:
    text = text[:m.end(1)] + dep + text[m.end(1):]
else:
    text = text.replace('dependencies:\n', 'dependencies:\n' + dep, 1)
p.write_text(text, encoding='utf-8')
print('linked')
PYEOF
    ok "dalil_core اترَبَط بتطبيق المستخدم"
  else
    ok "dalil_core مربوط بالفعل"
  fi
else
  warn "تطبيق المستخدم مش موجود — انسخه بنفسك لـ mobile/apps/user/"
fi

# ── 5. فحص أسرار مكشوفة ───────────────────────────────
step "٥. فحص أمني"

LEAKS=0
if [[ -f backend/config/settings/base.py ]]; then
  if grep -qE "^SECRET_KEY\s*=\s*['\"]django-insecure|^SECRET_KEY\s*=\s*['\"][a-zA-Z0-9_@#%^&*-]{20,}" \
       backend/config/settings/base.py 2>/dev/null; then
    warn "SECRET_KEY مكتوب مباشرة في settings/base.py"
    LEAKS=1
  fi
fi
if grep -rqE "(CLOUDINARY|FIREBASE|API_KEY|SECRET)[A-Z_]*\s*=\s*['\"][^'\"]{16,}" \
     backend/config/ 2>/dev/null; then
  warn "فيه مفاتيح تبدو مكتوبة مباشرة في config/"
  LEAKS=1
fi

if [[ $LEAKS -eq 1 ]]; then
  echo
  echo "${YELLOW}  انقل المفاتيح دي لمتغيرات بيئة قبل الرفع.${OFF}"
  echo "${DIM}  أي مفتاح يدخل تاريخ Git يفضل فيه حتى بعد مسحه.${OFF}"
  echo
  read -r -p "  تكمل برغم كده؟ [y/N] " answer
  [[ "$answer" =~ ^[Yy]$ ]] || die "اتوقف. صلّح المفاتيح وشغّل السكربت تاني."
else
  ok "مفيش أسرار ظاهرة"
fi

# ── 6. تجهيز Git ──────────────────────────────────────
step "٦. تجهيز Git"

if [[ -d .git ]]; then
  ok "مستودع Git موجود"
else
  git init -q
  git branch -M main
  ok "مستودع Git اتعمل"
fi

git remote remove origin 2>/dev/null || true
git remote add origin "$REMOTE"
ok "origin → $REMOTE"

git add -A
COUNT=$(git diff --cached --name-only | wc -l | tr -d ' ')
ok "$COUNT ملف جاهز للرفع"

# ── الخلاصة ───────────────────────────────────────────
echo
echo "${GREEN}${BOLD}خلص التجهيز.${OFF}"
echo
echo "${BOLD}اللي فاضل — أمرين:${OFF}"
echo
echo "    git commit -m \"feat: v3 foundation\""
echo "    git push -u origin main"
echo
echo "${DIM}هيطلب منك اسم المستخدم و token (مش كلمة السر العادية).${OFF}"
echo "${DIM}تعمل token من: GitHub ← Settings ← Developer settings${OFF}"
echo "${DIM}          ← Personal access tokens ← Fine-grained${OFF}"
echo "${DIM}صلاحية واحدة تكفي: Contents → Read and write${OFF}"
echo
echo "${BOLD}وبعد الرفع:${OFF}"
echo "    Settings ← Pages ← Source: ${BOLD}GitHub Actions${OFF}"
echo
