#!/bin/bash
set -e

INPUT_APK=$1

echo "[*] Fetching apkeep to download APK..."
wget -q https://github.com/EFForg/apkeep/releases/download/0.18.0/apkeep-x86_64-unknown-linux-gnu -O apkeep
chmod +x apkeep

echo "[*] Fetching latest brosssh/morphe-patches release..."
LATEST_PATCHES_API="https://api.github.com/repos/brosssh/morphe-patches/releases/latest"
PATCHES_DOWNLOAD_URL=$(curl -s $LATEST_PATCHES_API | grep -oP '"browser_download_url": "\K(.*\.mpp)(?=")')
PATCHES_FILE=$(basename "$PATCHES_DOWNLOAD_URL")

SUPPORTED_VERSION=$(curl -s $LATEST_PATCHES_API | grep -i 'Instagram' | grep -oP '\d+\.\d+\.\d+\.\d+\.\d+' | head -n 1)

if [ -z "$PATCHES_DOWNLOAD_URL" ]; then
    echo "Error: Could not determine latest patches download URL."
    exit 1
fi

if [ -z "$SUPPORTED_VERSION" ]; then
    echo "Warning: Could not determine supported Instagram version from release notes. apkeep will attempt to download the latest version."
    TARGET_APP="com.instagram.android"
else
    echo "[*] Supported Instagram version found: $SUPPORTED_VERSION"
    TARGET_APP="com.instagram.android@$SUPPORTED_VERSION"
fi

if [ -z "$INPUT_APK" ]; then
    echo "[*] No input APK provided. Downloading $TARGET_APP from apk-pure using apkeep..."
    ./apkeep -d apk-pure -a "$TARGET_APP" .
    DOWNLOADED_FILE=$(ls com.instagram.android* | grep -E '\.(apk|xapk)$' | head -n 1)
    if [ -z "$DOWNLOADED_FILE" ]; then
        echo "Error: Failed to download APK."
        exit 1
    fi
    
    if [[ "$DOWNLOADED_FILE" == *.xapk ]]; then
        echo "[*] Extracting base APK from XAPK..."
        unzip -q "$DOWNLOADED_FILE" "com.instagram.android.apk" -d .
        INPUT_APK="com.instagram.android.apk"
    else
        INPUT_APK="$DOWNLOADED_FILE"
    fi
fi

if [ ! -f "$INPUT_APK" ]; then
    echo "Error: Input APK file not found: $INPUT_APK"
    exit 1
fi

echo "[*] Downloading patches bundle: $PATCHES_FILE"
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

echo "[*] Patching APK with default patches (includes Hide ads, Hide suggested content, etc.)..."
java -jar "$CLI_FILE" patch \
    --patches "$PATCHES_FILE" \
    --out "$OUTPUT_APK" \
    "$INPUT_APK"

echo "[+] Patching complete! Output file: $OUTPUT_APK"
