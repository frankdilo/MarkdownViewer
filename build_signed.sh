#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if [[ "${1:-}" == "--help" ]]; then
    cat <<'EOF'
Usage: ./build_signed.sh

Environment variables:
  ARCHES="arm64 x86_64"        Build a universal binary (default: host arch)
  SIGNING_MODE=adhoc|release   Default: adhoc
  APP_IDENTITY="Developer ID Application: Your Name (TEAMID)"
  NOTARIZE=1                   Submit and staple notarization
  NOTARY_PROFILE="profile"     Use notarytool keychain profile
  APP_STORE_CONNECT_API_KEY_P8 API key contents for notarytool
  APP_STORE_CONNECT_KEY_ID     API key ID for notarytool
  APP_STORE_CONNECT_ISSUER_ID  Issuer ID for notarytool
  CREATE_ZIP=1                 Create a distributable zip (default: 0)
EOF
    exit 0
fi

APP_NAME="Markdown Viewer"
APP_SLUG="MarkdownViewer"
APP_BUNDLE="${APP_NAME}.app"
CONF="release"

SIGNING_MODE="${SIGNING_MODE:-adhoc}"
NOTARIZE="${NOTARIZE:-0}"
CREATE_ZIP="${CREATE_ZIP:-0}"
if [[ "$NOTARIZE" == "1" ]]; then
    CREATE_ZIP=1
fi

TEMP_KEY=""
NOTARIZE_ZIP=""
cleanup() {
    if [[ -n "$TEMP_KEY" && -f "$TEMP_KEY" ]]; then
        rm -f "$TEMP_KEY"
    fi
    if [[ -n "$NOTARIZE_ZIP" && -f "$NOTARIZE_ZIP" ]]; then
        rm -f "$NOTARIZE_ZIP"
    fi
}
trap cleanup EXIT

ARCH_LIST=()
if [[ -n "${ARCHES:-}" ]]; then
    ARCH_LIST=( ${ARCHES} )
else
    HOST_ARCH="$(uname -m)"
    case "$HOST_ARCH" in
        arm64|x86_64) ARCH_LIST=("$HOST_ARCH") ;;
        *) ARCH_LIST=("$HOST_ARCH") ;;
    esac
fi

build_product_path() {
    local arch="$1"
    case "$arch" in
        arm64|x86_64) echo ".build/${arch}-apple-macosx/${CONF}/MarkdownViewer" ;;
        *) echo ".build/${CONF}/MarkdownViewer" ;;
    esac
}

resource_bundle_path() {
    local arch="$1"
    case "$arch" in
        arm64|x86_64) echo ".build/${arch}-apple-macosx/${CONF}/MarkdownViewer_MarkdownViewer.bundle" ;;
        *) echo ".build/${CONF}/MarkdownViewer_MarkdownViewer.bundle" ;;
    esac
}

verify_binary_arches() {
    local binary="$1"; shift
    local expected=("$@")
    local actual
    actual=$(lipo -archs "$binary")
    local actual_count expected_count
    actual_count=$(wc -w <<<"$actual" | tr -d ' ')
    expected_count=${#expected[@]}
    if [[ "$actual_count" -ne "$expected_count" ]]; then
        echo "ERROR: $binary arch mismatch (expected: ${expected[*]}, actual: ${actual})" >&2
        exit 1
    fi
    for arch in "${expected[@]}"; do
        if [[ "$actual" != *"$arch"* ]]; then
            echo "ERROR: $binary missing arch $arch (have: ${actual})" >&2
            exit 1
        fi
    done
}

echo "Building MarkdownViewer..."
for ARCH in "${ARCH_LIST[@]}"; do
    swift build -c "$CONF" --arch "$ARCH"
done

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

BINARIES=()
for ARCH in "${ARCH_LIST[@]}"; do
    SRC="$(build_product_path "$ARCH")"
    if [[ ! -f "$SRC" ]]; then
        echo "ERROR: Missing build for ${ARCH} at ${SRC}" >&2
        exit 1
    fi
    BINARIES+=("$SRC")
done

DEST_BIN="$APP_BUNDLE/Contents/MacOS/MarkdownViewer"
if [[ ${#BINARIES[@]} -gt 1 ]]; then
    lipo -create "${BINARIES[@]}" -output "$DEST_BIN"
else
    cp "${BINARIES[0]}" "$DEST_BIN"
fi
chmod +x "$DEST_BIN"
verify_binary_arches "$DEST_BIN" "${ARCH_LIST[@]}"

cp "MarkdownViewer/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
RESOURCE_BUNDLE="$(resource_bundle_path "${ARCH_LIST[0]}")"
if [[ -d "$RESOURCE_BUNDLE" ]]; then
    cp -R "$RESOURCE_BUNDLE" "$APP_BUNDLE/Contents/Resources/"
fi
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

chmod -R u+w "$APP_BUNDLE"
xattr -cr "$APP_BUNDLE"
find "$APP_BUNDLE" -name '._*' -delete

if [[ "$SIGNING_MODE" == "adhoc" ]]; then
    CODESIGN_ARGS=(--force --sign -)
else
    if [[ -z "${APP_IDENTITY:-}" ]]; then
        echo "ERROR: APP_IDENTITY is required when SIGNING_MODE is not adhoc." >&2
        exit 1
    fi
    CODESIGN_ARGS=(--force --timestamp --options runtime --sign "$APP_IDENTITY")
fi

codesign "${CODESIGN_ARGS[@]}" "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "MarkdownViewer/Info.plist")
ZIP_NAME="${APP_SLUG}-${VERSION}.zip"
DITTO_BIN=${DITTO_BIN:-/usr/bin/ditto}

if [[ "$NOTARIZE" == "1" ]]; then
    NOTARIZE_ZIP="/tmp/${APP_SLUG}Notarize.zip"
    "$DITTO_BIN" --norsrc -c -k --keepParent "$APP_BUNDLE" "$NOTARIZE_ZIP"

    if [[ -n "${NOTARY_PROFILE:-}" ]]; then
        xcrun notarytool submit "$NOTARIZE_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
    elif [[ -n "${APP_STORE_CONNECT_API_KEY_P8:-}" && -n "${APP_STORE_CONNECT_KEY_ID:-}" && -n "${APP_STORE_CONNECT_ISSUER_ID:-}" ]]; then
        TEMP_KEY="$(mktemp -t "${APP_SLUG}-notary").p8"
        echo "$APP_STORE_CONNECT_API_KEY_P8" | sed 's/\\n/\n/g' > "$TEMP_KEY"
        xcrun notarytool submit "$NOTARIZE_ZIP" \
            --key "$TEMP_KEY" \
            --key-id "$APP_STORE_CONNECT_KEY_ID" \
            --issuer "$APP_STORE_CONNECT_ISSUER_ID" \
            --wait
    else
        echo "ERROR: Set NOTARY_PROFILE or APP_STORE_CONNECT_* for notarization." >&2
        exit 1
    fi

    xcrun stapler staple "$APP_BUNDLE"
    xcrun stapler validate "$APP_BUNDLE"
    spctl -a -t exec -vv "$APP_BUNDLE"
fi

if [[ "$CREATE_ZIP" == "1" ]]; then
    "$DITTO_BIN" --norsrc -c -k --keepParent "$APP_BUNDLE" "$ZIP_NAME"
    echo "Zip created at: $(pwd)/${ZIP_NAME}"
fi

echo ""
echo "Build complete!"
echo ""
echo "App bundle created at: $(pwd)/$APP_BUNDLE"
if [[ "$CREATE_ZIP" != "1" ]]; then
    echo ""
    echo "To install to Applications folder:"
    echo "  cp -r \"$APP_BUNDLE\" /Applications/"
fi
