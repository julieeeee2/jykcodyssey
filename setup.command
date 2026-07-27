#!/bin/bash

# Codyssey loaner-Mac quick setup v2
# 1) Enable macOS built-in Korean 2-Set input source
# 2) Set Fn/Globe key to "Change Input Source"
# 3) Remap Caps Lock to Fn/Globe for the current login session
# 4) Keep the default Command-Space Spotlight shortcut enabled
# No administrator password or third-party app is required.

set -u

KOREAN_PARENT_ID="com.apple.inputmethod.Korean"
KOREAN_MODE_ID="com.apple.inputmethod.Korean.2SetKorean"
HITOOLBOX_DOMAIN="com.apple.HIToolbox"
HOTKEY_DOMAIN="com.apple.symbolichotkeys"

# HID usage IDs used by macOS hidutil.
CAPS_LOCK_KEY="0x700000039"
FN_GLOBE_KEY="0xFF00000003"

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

ok()   { printf "%b✓ %s%b\n" "$GREEN" "$1" "$RESET"; }
warn() { printf "%b! %s%b\n" "$YELLOW" "$1" "$RESET"; }
fail() { printf "%b✗ %s%b\n" "$RED" "$1" "$RESET"; }

if [ "$(uname -s)" != "Darwin" ]; then
  fail "이 파일은 macOS에서만 실행할 수 있습니다."
  exit 1
fi

printf "\n코디세이 맥 초기 설정 v2를 적용합니다. (macOS %s)\n\n" "$(sw_vers -productVersion 2>/dev/null || echo unknown)"

# Back up preferences and the current temporary key mapping before changing them.
TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
BACKUP_DIR="$HOME/Library/Application Support/CodysseyMacSetup/backups/$TIMESTAMP"
mkdir -p "$BACKUP_DIR"
defaults export "$HITOOLBOX_DOMAIN" "$BACKUP_DIR/com.apple.HIToolbox.plist" >/dev/null 2>&1 || true
defaults export "$HOTKEY_DOMAIN" "$BACKUP_DIR/com.apple.symbolichotkeys.plist" >/dev/null 2>&1 || true
/usr/bin/hidutil property --get "UserKeyMapping" > "$BACKUP_DIR/hidutil-UserKeyMapping.txt" 2>&1 || true

# Prevent an open settings window from writing an older cached value back.
killall "System Settings" >/dev/null 2>&1 || true
killall "System Preferences" >/dev/null 2>&1 || true

BUILD_DIR=""
cleanup() {
  if [ -n "$BUILD_DIR" ] && [ -d "$BUILD_DIR" ]; then
    rm -rf "$BUILD_DIR"
  fi
}
trap cleanup EXIT

# Preferred method: use Apple's Text Input Source Services API.
# The helper is compiled locally only when Command Line Tools are already available.
enable_korean_with_tis() {
  if ! command -v xcrun >/dev/null 2>&1; then
    return 1
  fi
  if ! xcrun --find clang >/dev/null 2>&1; then
    return 1
  fi

  BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/codyssey-input.XXXXXX")" || return 1

  cat > "$BUILD_DIR/enable_korean.c" <<'C_EOF'
#include <Carbon/Carbon.h>
#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>

static OSStatus enable_source(CFStringRef source_id, int required) {
    const void *keys[] = { kTISPropertyInputSourceID };
    const void *values[] = { source_id };

    CFDictionaryRef filter = CFDictionaryCreate(
        kCFAllocatorDefault,
        keys,
        values,
        1,
        &kCFTypeDictionaryKeyCallBacks,
        &kCFTypeDictionaryValueCallBacks
    );

    if (filter == NULL) {
        return required ? paramErr : noErr;
    }

    CFArrayRef sources = TISCreateInputSourceList(filter, true);
    CFRelease(filter);

    if (sources == NULL || CFArrayGetCount(sources) == 0) {
        if (sources != NULL) CFRelease(sources);
        return required ? fnfErr : noErr;
    }

    TISInputSourceRef source = (TISInputSourceRef)CFArrayGetValueAtIndex(sources, 0);
    OSStatus status = TISEnableInputSource(source);

    if (status == noErr) {
        CFBooleanRef enabled = (CFBooleanRef)TISGetInputSourceProperty(
            source,
            kTISPropertyInputSourceIsEnabled
        );
        if (enabled != kCFBooleanTrue) status = paramErr;
    }

    CFRelease(sources);
    return status;
}

int main(void) {
    /* An input mode may require its parent input method to be enabled first. */
    (void)enable_source(CFSTR("com.apple.inputmethod.Korean"), 0);

    OSStatus status = enable_source(
        CFSTR("com.apple.inputmethod.Korean.2SetKorean"),
        1
    );

    if (status != noErr) {
        fprintf(stderr, "TISEnableInputSource failed: %d\n", (int)status);
        return 1;
    }
    return 0;
}
C_EOF

  if ! xcrun clang \
      -framework Carbon \
      -framework CoreFoundation \
      "$BUILD_DIR/enable_korean.c" \
      -o "$BUILD_DIR/enable_korean" >/dev/null 2>&1; then
    return 1
  fi

  "$BUILD_DIR/enable_korean" >/dev/null 2>&1
}

# Fallback for Macs without Command Line Tools.
enable_korean_with_defaults() {
  local current_sources
  local parent_xml
  local mode_xml

  # OpenStep-style property-list dictionaries are parsed by the defaults tool
  # as dictionaries rather than plain strings.
  parent_xml='{ "Bundle ID" = "com.apple.inputmethod.Korean"; InputSourceKind = "Keyboard Input Method"; }'
  mode_xml='{ "Bundle ID" = "com.apple.inputmethod.Korean"; "Input Mode" = "com.apple.inputmethod.Korean.2SetKorean"; InputSourceKind = "Input Mode"; }'

  current_sources="$(defaults read "$HITOOLBOX_DOMAIN" AppleEnabledInputSources 2>/dev/null || true)"

  if ! printf '%s' "$current_sources" | grep -Fq "$KOREAN_PARENT_ID"; then
    defaults write "$HITOOLBOX_DOMAIN" AppleEnabledInputSources -array-add "$parent_xml" >/dev/null 2>&1 || return 1
  fi

  current_sources="$(defaults read "$HITOOLBOX_DOMAIN" AppleEnabledInputSources 2>/dev/null || true)"
  if ! printf '%s' "$current_sources" | grep -Fq "$KOREAN_MODE_ID"; then
    defaults write "$HITOOLBOX_DOMAIN" AppleEnabledInputSources -array-add "$mode_xml" >/dev/null 2>&1 || return 1
  fi

  return 0
}

CURRENT_SOURCES="$(defaults read "$HITOOLBOX_DOMAIN" AppleEnabledInputSources 2>/dev/null || true)"
if printf '%s' "$CURRENT_SOURCES" | grep -Fq "$KOREAN_MODE_ID"; then
  ok "한글 두벌식 입력기가 이미 등록되어 있습니다."
else
  if enable_korean_with_tis; then
    ok "한글 두벌식 입력기를 등록했습니다."
  elif enable_korean_with_defaults; then
    ok "한글 두벌식 입력기를 등록했습니다. (설정 파일 방식)"
  else
    fail "한글 입력기 등록에 실패했습니다. 기관 관리 정책이 설정을 막았을 수 있습니다."
  fi
fi

# Keyboard > "Press fn/Globe key to" > "Change Input Source"
if defaults write "$HITOOLBOX_DOMAIN" AppleFnUsageType -int 1 >/dev/null 2>&1; then
  ok "fn/지구본 키 동작을 '입력 소스 변경'으로 설정했습니다."
else
  fail "fn/지구본 키 설정에 실패했습니다."
fi

# Keep/restore the default Spotlight shortcut instead of disabling it.
# Symbolic hotkey ID 64 is "Show Spotlight search"; 49 is the Space key.
SPOTLIGHT_ENABLED_XML='{ enabled = 1; value = { type = standard; parameters = (32, 49, 1048576); }; }'
if defaults write "$HOTKEY_DOMAIN" AppleSymbolicHotKeys -dict-add 64 "$SPOTLIGHT_ENABLED_XML" >/dev/null 2>&1; then
  ok "Spotlight의 Command-Space 단축키를 유지했습니다."
else
  warn "Spotlight 단축키 확인에 실패했습니다. 다른 키보드 설정에는 영향이 없습니다."
fi

# Reload preference consumers before applying the live Caps Lock mapping.
killall cfprefsd >/dev/null 2>&1 || true
killall TextInputMenuAgent >/dev/null 2>&1 || true
killall TextInputSwitcher >/dev/null 2>&1 || true
killall SystemUIServer >/dev/null 2>&1 || true

ACTIVATE_SETTINGS="/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings"
if [ -x "$ACTIVATE_SETTINGS" ]; then
  "$ACTIVATE_SETTINGS" -u >/dev/null 2>&1 || true
fi

sleep 1

# Keyboard Shortcuts > Modifier Keys > Caps Lock key > fn Function.
# This live mapping lasts until restart or until the keyboard service is removed.
# That matches the intended use on a loaner Mac that is reset between sessions.
CAPS_TO_FN_MAPPING="{\"UserKeyMapping\":[{\"HIDKeyboardModifierMappingSrc\":$CAPS_LOCK_KEY,\"HIDKeyboardModifierMappingDst\":$FN_GLOBE_KEY}]}"
if /usr/bin/hidutil property --set "$CAPS_TO_FN_MAPPING" >/dev/null 2>&1; then
  ok "Caps Lock 키를 fn/지구본 키로 바꿨습니다."
else
  fail "Caps Lock 키 변환에 실패했습니다."
fi

sleep 1

FINAL_SOURCES="$(defaults read "$HITOOLBOX_DOMAIN" AppleEnabledInputSources 2>/dev/null || true)"
FINAL_FN_USAGE="$(defaults read "$HITOOLBOX_DOMAIN" AppleFnUsageType 2>/dev/null || true)"
FINAL_MAPPING="$(/usr/bin/hidutil property --get "UserKeyMapping" 2>/dev/null || true)"

if printf '%s' "$FINAL_SOURCES" | grep -Fq "$KOREAN_MODE_ID"; then
  ok "확인: 한글 입력기 항목이 저장되어 있습니다."
else
  warn "한글 입력기 목록 반영이 늦을 수 있습니다. 한 번 로그아웃 후 로그인하면 반영됩니다."
fi

if [ "$FINAL_FN_USAGE" = "1" ]; then
  ok "확인: fn/지구본 키가 입력 소스 변경으로 저장되어 있습니다."
else
  warn "fn/지구본 키 설정 반영이 늦을 수 있습니다. 한 번 로그아웃 후 로그인하세요."
fi

if printf '%s' "$FINAL_MAPPING" | grep -Eq '1095216660483|0x[Ff][Ff]00000003'; then
  ok "확인: Caps Lock → fn/지구본 키 변환이 활성화되어 있습니다."
else
  warn "Caps Lock 변환 상태를 확인하지 못했습니다. 스크립트를 한 번 더 실행해보세요."
fi

printf "\n완료했습니다. Caps Lock을 짧게 눌러 한/영 전환을 확인하세요.\n"
printf "Spotlight는 Command-Space로 계속 열립니다.\n"
printf "Caps Lock 본래 기능 대신 대문자는 Shift 키로 입력하세요.\n"
printf "백업 위치: %s\n\n" "$BACKUP_DIR"
