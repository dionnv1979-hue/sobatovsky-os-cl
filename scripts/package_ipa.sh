#!/usr/bin/env bash
# Упаковывает собранный .app в настоящий IPA (Payload/<App>.app → zip) и проверяет результат.
set -euo pipefail

APP_NAME="SOBATOVSKY-OS"
APP_PATH="build/Build/Products/Release-iphoneos/${APP_NAME}.app"
OUT_DIR="output"
IPA="${OUT_DIR}/${APP_NAME}.ipa"
REPORT="${OUT_DIR}/IPA-CHECK.txt"

if [ ! -d "$APP_PATH" ]; then
  echo "ОШИБКА: не найден собранный ${APP_PATH}"
  ls -R build/Build/Products 2>/dev/null | head -50 || true
  exit 1
fi

rm -rf Payload "$OUT_DIR"
mkdir -p Payload "$OUT_DIR"
cp -R "$APP_PATH" "Payload/"
zip -qry "$IPA" Payload
rm -rf Payload

fail() { echo "ПРОВЕРКА НЕ ПРОЙДЕНА: $1" | tee -a "$REPORT"; exit 1; }

{
  echo "=== Проверка ${APP_NAME}.ipa ==="
  date -u
  echo
} > "$REPORT"

LIST=$(unzip -Z1 "$IPA")
echo "$LIST" | grep -q "^Payload/${APP_NAME}.app/Info.plist$" || fail "нет Info.plist в Payload"
echo "$LIST" | grep -q "^Payload/${APP_NAME}.app/${APP_NAME}$" || fail "нет исполняемого файла приложения"
echo "$LIST" | grep -q "Assets.car$" || fail "нет скомпилированных ресурсов (Assets.car)"
if echo "$LIST" | grep -qE '\.swift$'; then fail "в IPA попали исходники .swift"; fi

TMP=$(mktemp -d)
unzip -q "$IPA" -d "$TMP"
BIN="$TMP/Payload/${APP_NAME}.app/${APP_NAME}"
PLIST="$TMP/Payload/${APP_NAME}.app/Info.plist"

{
  echo "Размер IPA: $(du -h "$IPA" | cut -f1)"
  echo "Размер бинарника: $(wc -c < "$BIN") байт"
  echo "Тип бинарника: $(file "$BIN")"
  echo "Архитектуры: $(lipo -info "$BIN" 2>&1)"
  echo "Bundle ID: $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST")"
  echo "Название: $(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$PLIST")"
  echo "Версия: $(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST") (сборка $(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST"))"
  echo "Минимальная iOS: $(/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$PLIST")"
  echo "Подпись (ожидается отсутствие/ad-hoc):"
  codesign -dv "$TMP/Payload/${APP_NAME}.app" 2>&1 | sed 's/^/  /' || true
  echo
  echo "Содержимое верхнего уровня Payload:"
  unzip -l "$IPA" | head -30
} >> "$REPORT"

file "$BIN" | grep -q "Mach-O" || fail "бинарник не Mach-O"
lipo -archs "$BIN" 2>/dev/null | grep -qw "arm64" || fail "в бинарнике нет архитектуры arm64"
[ "$(wc -c < "$BIN")" -gt 100000 ] || fail "бинарник подозрительно мал"
[ "$(wc -c < "$IPA")" -gt 200000 ] || fail "IPA подозрительно мал"

echo >> "$REPORT"
echo "ВСЕ ПРОВЕРКИ ПРОЙДЕНЫ: IPA содержит собранное приложение (не исходники)." | tee -a "$REPORT"
cat "$REPORT"
rm -rf "$TMP"
