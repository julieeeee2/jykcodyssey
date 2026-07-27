#!/bin/bash

# Codyssey loaner-Mac quick setup
# 1) Enable macOS built-in Korean 2-Set input source
# 2) Disable the Command-Space Spotlight shortcut
# No administrator password is required.

set -u

KOREAN_PARENT_ID="com.apple.inputmethod.Korean"
KOREAN_MODE_ID="com.apple.inputmethod.Korean.2SetKorean"
HITOOLBOX_DOMAIN="com.apple.HIToolbox"
HOTKEY_DOMAIN="com.apple.symbolichotkeys"

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

printf "\n코디세이 맥 초기 설정을 적용합니다. (macOS %s)\n\n" "$(sw_vers -productVersion 2>/dev/null || echo unknown)"

# Back up the two preference domains before changing them.
TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
BACKUP_DIR="$HOME/Library/Application Support/CodysseyMacSetup/backups/$TIMESTAMP"
mkdir -p "$BACKUP_DIR"
defaults export "$HITOOLBOX_DOMAIN" "$BACKUP_DIR/com.apple.HIToolbox.plist" >/dev/null 2>&1 || true
defaults export "$HOTKEY_DOMAIN" "$BACKUP_DIR/com.apple.symbolichotkeys.plist" >/dev/null 2>&1 || true

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
# The helper is compiled locally only when Command Line Tools are available.
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

  parent_xml='<dict><key>Bundle ID</key><string>com.apple.inputmethod.Korean</string><key>InputSourceKind</key><string>Keyboard Input Method</string></dict>'
  mode_xml='<dict><key>Bundle ID</key><string>com.apple.inputmethod.Korean</string><key>Input Mode</key><string>com.apple.inputmethod.Korean.2SetKorean</string><key>InputSourceKind</key><string>Input Mode</string></dict>'

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

# Shortcut ID 64 is “Show Spotlight search” (Command-Space by default).
SPOTLIGHT_DISABLED_XML='<dict><key>enabled</key><false/><key>value</key><dict><key>type</key><string>standard</string><key>parameters</key><array><integer>32</integer><integer>49</integer><integer>1048576</integer></array></dict></dict>'

if defaults write "$HOTKEY_DOMAIN" AppleSymbolicHotKeys -dict-add 64 "$SPOTLIGHT_DISABLED_XML" >/dev/null 2>&1; then
  ok "Spotlight의 Command-Space 단축키를 해제했습니다."
else
  fail "Spotlight 단축키 해제에 실패했습니다."
fi

# Reload menu-bar input sources and keyboard shortcuts.
killall cfprefsd >/dev/null 2>&1 || true
killall TextInputMenuAgent >/dev/null 2>&1 || true
killall SystemUIServer >/dev/null 2>&1 || true

ACTIVATE_SETTINGS="/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings"
if [ -x "$ACTIVATE_SETTINGS" ]; then
  "$ACTIVATE_SETTINGS" -u >/dev/null 2>&1 || true
fi

sleep 1

FINAL_SOURCES="$(defaults read "$HITOOLBOX_DOMAIN" AppleEnabledInputSources 2>/dev/null || true)"
if printf '%s' "$FINAL_SOURCES" | grep -Fq "$KOREAN_MODE_ID"; then
  ok "설정 확인: 한글 입력기 항목이 저장되어 있습니다."
else
  warn "한글 입력기는 API로 활성화했지만 설정 목록 반영이 늦을 수 있습니다. 한 번 로그아웃 후 로그인하면 반영됩니다."
fi

printf "\n완료했습니다. 한/영 전환은 Control-Space 또는 지구본(Fn) 키로 확인하세요.\n"
printf "백업 위치: %s\n\n" "$BACKUP_DIR"
