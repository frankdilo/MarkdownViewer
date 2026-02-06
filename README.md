# Markdown Viewer

A native macOS Markdown viewer built with SwiftUI and WebKit.

![Screenshot](screenshot.png)

## Features

- Native macOS app built with SwiftUI and WebKit.
- Tabbed windows with keyboard shortcuts.
- Auto-reload on file change with dismissable notification.
- Mermaid diagram rendering.
- Table of contents sidebar (pinnable or hover to reveal).
- Syntax highlighting for fenced code blocks.
- Front matter preview.
- Find-in-page with next/previous navigation.
- Zoom controls (in/out/actual size).
- Open Recent menu for quick access to files.
- Configurable external editor with customizable keyboard shortcut.
- Optional bring-to-front when a file is modified externally.

## External Editor

Open the current file in your preferred editor directly from the viewer. Configure the editor and keyboard shortcut in Settings (Cmd+,).

- **Default shortcut:** Cmd+E
- **Supported editors:** Any application that accepts file URLs (Sublime Text, VS Code, BBEdit, etc.)
- **Setup:** Settings > External Editor > Choose, then select an app from /Applications
- **Custom shortcut:** Settings > Keyboard Shortcut — click the recorder and press your desired key combination

If no editor is configured, the first use will prompt you to select one.

## Bring to Front on File Change

When enabled, the viewer window automatically comes to front whenever the monitored file is modified externally. Useful when editing in a separate application and wanting the preview to surface after each save.

- **Toggle:** View > Bring to Front on File Change
- **Default:** Off

## Build & Run

```bash
# Run from source (development)
swift run MarkdownViewer

# Build release .app bundle
./build.sh
```

The release build creates `Markdown Viewer.app` in the repo root.

## Requirements

- macOS 14+
- Xcode Command Line Tools
