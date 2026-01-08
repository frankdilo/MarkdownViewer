# Repository Guidelines

## Project Structure & Module Organization
- `Package.swift` defines the Swift Package Manager app target and the `swift-markdown` dependency.
- `MarkdownViewer/` contains the app source code (SwiftUI + WebKit) and `MarkdownViewer/Info.plist`.
- `AppIcon.icns` and `AppIcon.iconset` hold the app icon assets; `generate_icon.swift` is the icon generator.
- `build.sh` produces a release build and assembles `Markdown Viewer.app` at the repo root.
- `Package.resolved` is the pinned dependency lockfile and should change only when dependencies change.

## Build, Test, and Development Commands
- `swift build` builds a debug binary using Swift Package Manager.
- `swift run MarkdownViewer` runs the app from source for local development.
- `./build.sh` builds a release binary and creates a signed-ready `.app` bundle in the repo root.
- `swift build -c release` is the underlying release build used by `build.sh`.

## Coding Style & Naming Conventions
- Follow Swift API Design Guidelines and mirror existing code style in `MarkdownViewer/MarkdownViewerApp.swift`.
- Use 4-space indentation and spaces (no tabs).
- Types and views use `UpperCamelCase`; functions/vars use `lowerCamelCase`.
- Prefer one primary type per file and name files after the primary type.

## Testing Guidelines
- No test target exists yet. If you add tests, use XCTest under `Tests/MarkdownViewerTests/`.
- Use `swift test` to run the suite; name test files `*Tests.swift`.

## Commit & Pull Request Guidelines
- Commit messages are short, imperative, and capitalized (e.g., "Add native tabbed windows").
- PRs should include: a concise summary, testing steps, and screenshots for UI changes.
- Link related issues when available.

## Release & Packaging Notes
- `build.sh` assembles the `.app` bundle and copies `Info.plist` and `AppIcon.icns`.
- When touching app metadata, update `MarkdownViewer/Info.plist` and verify bundle ID/version values.
