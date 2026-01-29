# Markdown Viewer

A native macOS Markdown viewer built with SwiftUI and WebKit.

![Screenshot](screenshot.png)

## Features

- Native macOS app built with SwiftUI and WebKit.
- Tabbed windows with keyboard shortcuts.
- File change detection with a reload prompt.
- Mermaid diagram rendering.
- Table of contents sidebar (pinnable or hover to reveal).
- Syntax highlighting for fenced code blocks.
- Front matter preview.
- Find-in-page with next/previous navigation.
- Zoom controls (in/out/actual size).
- Open Recent menu for quick access to files.

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
