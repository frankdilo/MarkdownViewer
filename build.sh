#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "Building MarkdownViewer..."

# Build in release mode
swift build -c release

# Create the app bundle structure
APP_NAME="Markdown Viewer"
APP_BUNDLE="$APP_NAME.app"
BUILD_DIR=".build/release"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy the executable
cp "$BUILD_DIR/MarkdownViewer" "$APP_BUNDLE/Contents/MacOS/MarkdownViewer"

# Copy Info.plist
cp "MarkdownViewer/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Copy icon
cp "AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# Copy SwiftPM resources bundle if present
RESOURCE_BUNDLE="$BUILD_DIR/MarkdownViewer_MarkdownViewer.bundle"
if [[ -d "$RESOURCE_BUNDLE" ]]; then
    cp -R "$RESOURCE_BUNDLE" "$APP_BUNDLE/Contents/Resources/"
fi

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo ""
echo "Build complete!"
echo ""
echo "App bundle created at: $(pwd)/$APP_BUNDLE"
echo ""
echo "To install to Applications folder:"
echo "  cp -r \"$APP_BUNDLE\" /Applications/"
echo ""
echo "To open a file from command line:"
echo "  open -a \"Markdown Viewer\" /path/to/file.md"
echo ""
echo "To set as default app for .md files:"
echo "  1. Right-click any .md file in Finder"
echo "  2. Select 'Get Info'"
echo "  3. Under 'Open with', select 'Markdown Viewer'"
echo "  4. Click 'Change All...'"
echo ""
echo "Or use duti (install with: brew install duti):"
echo "  duti -s com.frankdilo.MarkdownViewer .md all"
