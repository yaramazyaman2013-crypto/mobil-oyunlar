#!/usr/bin/env bash
# Android APK ve Windows sürümünü dışa aktarır.
# Gerekenler: godot (4.3), export şablonları, Android SDK + JDK 17 (editör ayarlarında yolları),
# imza anahtarı için ortam değişkenleri:
#   GODOT_ANDROID_KEYSTORE_RELEASE_PATH, GODOT_ANDROID_KEYSTORE_RELEASE_USER, GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/android build/windows
touch build/.gdignore
godot --headless --editor --quit >/dev/null 2>&1 || true
godot --headless --export-release "Android" build/android/HiperYaris.apk
godot --headless --export-release "Windows" build/windows/HiperYaris.exe
rm -f build/HiperYaris-Windows.zip
(cd build/windows && zip -q -9 ../HiperYaris-Windows.zip HiperYaris.exe godot-jolt_windows-x64.dll)
ls -la build/android/HiperYaris.apk build/HiperYaris-Windows.zip
