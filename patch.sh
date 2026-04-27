#!/bin/bash
set -e

INPUT_APK=$1

echo "[*] Fetching apkeep to download APK..."
wget -q https://github.com/EFForg/apkeep/releases/download/0.18.0/apkeep-x86_64-unknown-linux-gnu -O apkeep
chmod +x apkeep

echo "[*] Fetching latest crimera/piko release..."
LATEST_PATCHES_API="https://api.github.com/repos/crimera/piko/releases/latest"
PATCHES_DOWNLOAD_URL=$(curl -s $LATEST_PATCHES_API | grep -oP '"browser_download_url": "\K(.*\.mpp)(?=")')
PATCHES_FILE=$(basename "$PATCHES_DOWNLOAD_URL")

echo "[*] Fetching supported version from Piko's Constants.kt..."
PIKO_CONSTANTS_URL="https://raw.githubusercontent.com/crimera/piko/main/patches/src/main/kotlin/app/crimera/patches/instagram/utils/Constants.kt"
echo "[*] Fetching supported versions from Piko's Constants.kt..."
PIKO_CONSTANTS_URL="https://raw.githubusercontent.com/crimera/piko/main/patches/src/main/kotlin/app/crimera/patches/instagram/utils/Constants.kt"
STABLE_VERSION=$(curl -s "$PIKO_CONSTANTS_URL" | grep -oP 'version = "\K([^"]+)' | head -n 1)
ALPHA_VERSION=$(curl -s "$PIKO_CONSTANTS_URL" | grep -oP 'version = "\K([^"]+)' | tail -n 1)

if [ -z "$PATCHES_DOWNLOAD_URL" ]; then
    echo "Error: Could not determine latest Piko patches download URL."
    exit 1
fi

if [ -z "$INPUT_APK" ]; then
    # Clean up any old downloads
    rm -f com.instagram.android* input.apkm

    echo "[*] Trying to download Alpha version: $ALPHA_VERSION"
    ./apkeep -d apk-pure -a "com.instagram.android@$ALPHA_VERSION" .
    DOWNLOADED_FILE=$(ls com.instagram.android* 2>/dev/null | grep -E '\.(apk|xapk|apkm)$' | head -n 1 || true)
    
    if [ -z "$DOWNLOADED_FILE" ]; then
        echo "[!] Alpha version not found on apk-pure. Falling back to Stable version: $STABLE_VERSION"
        ./apkeep -d apk-pure -a "com.instagram.android@$STABLE_VERSION" .
        DOWNLOADED_FILE=$(ls com.instagram.android* 2>/dev/null | grep -E '\.(apk|xapk|apkm)$' | head -n 1 || true)
    fi

    if [ -z "$DOWNLOADED_FILE" ]; then
        echo "Error: Failed to download APK."
        exit 1
    fi
    
    # Rename the file to .apkm so the patcher knows to treat it as a bundle
    INPUT_APK="input.apkm"
    mv "$DOWNLOADED_FILE" "$INPUT_APK"
    echo "[*] Renamed downloaded bundle to $INPUT_APK for patching."
fi

if [ ! -f "$INPUT_APK" ]; then
    echo "Error: Input APK file not found: $INPUT_APK"
    exit 1
fi

echo "[*] Downloading Piko patches bundle: $PATCHES_FILE"
curl -sL "$PATCHES_DOWNLOAD_URL" -o "$PATCHES_FILE"

echo "[*] Fetching latest MorpheApp/morphe-cli release..."
LATEST_CLI_API="https://api.github.com/repos/MorpheApp/morphe-cli/releases/latest"
CLI_DOWNLOAD_URL=$(curl -s $LATEST_CLI_API | grep -oP '"browser_download_url": "\K(.*\.jar)(?=")')
CLI_FILE="morphe-cli.jar"

if [ -z "$CLI_DOWNLOAD_URL" ]; then
    echo "Error: Could not determine latest morphe-cli download URL."
    exit 1
fi

echo "[*] Downloading morphe-cli: $CLI_DOWNLOAD_URL"
curl -sL "$CLI_DOWNLOAD_URL" -o "$CLI_FILE"

OUTPUT_APK="instagram-patched.apk"

echo "[*] Patching APK with all Piko patches (except 'Improve image viewing')..."
java -jar "$CLI_FILE" patch \
    --patches "$PATCHES_FILE" \
    --disable "Improve image viewing" \
    --out "$OUTPUT_APK" \
    "$INPUT_APK"

echo "[+] Patching complete! Output file: $OUTPUT_APK"
