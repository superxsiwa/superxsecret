#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# SuperXSecret Production Release Keystore Generation Script
# Generates a standard PKCS12 production upload keystore for Google Play Store.
# ==============================================================================

KEYSTORE_PATH="android/app/superxsecret-upload.jks"
KEY_ALIAS="superxsecret-upload"

if [ -f "$KEYSTORE_PATH" ]; then
    echo "⚠️ Keystore already exists at $KEYSTORE_PATH"
    echo "Aborting to prevent overwriting existing release credentials."
    exit 1
fi

echo "🔐 Generating production upload keystore for SuperXSecret..."
keytool -genkey -v \
    -keystore "$KEYSTORE_PATH" \
    -storetype PKCS12 \
    -keyalg RSA \
    -keysize 4096 \
    -validity 10000 \
    -alias "$KEY_ALIAS"

echo "✅ Keystore created at $KEYSTORE_PATH"
echo ""
echo "Next steps:"
echo "1. Copy android/key.properties.example to android/key.properties"
echo "2. Fill in the storePassword, keyPassword, and storeFile path"
echo "3. Run: flutter build appbundle --release"
echo "⚠️ IMPORTANT: Backup $KEYSTORE_PATH in a secure offline physical drive!"
