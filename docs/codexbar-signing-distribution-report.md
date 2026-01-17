# CodexBar macOS Signing, Updates & Distribution Report

**Research Date**: January 17, 2026
**Source Repository**: https://github.com/steipete/CodexBar
**Purpose**: Reference for implementing similar infrastructure in MarkdownViewer

---

## Executive Summary

CodexBar uses a mature, security-conscious approach to macOS app distribution:
- **Code Signing**: Developer ID with timestamps + hardened runtime
- **Notarization**: Apple's malware scanning via App Store Connect API
- **Secure Updates**: EdDSA-signed Sparkle feed
- **Multi-channel Distribution**: Direct download (Sparkle), Homebrew Cask
- **Automation**: Comprehensive shell scripts for the full release flow

---

## 1. Code Signing Configuration

### Signing Identity

- **Certificate Type**: `Developer ID Application: Peter Steinberger (Y5PE65HELJ)`
- **Override**: Via `APP_IDENTITY` environment variable
- **Location**: Hardcoded in build scripts with env var override

### Codesign Arguments

```bash
codesign --force --timestamp --options runtime --sign "$APP_IDENTITY" \
  --entitlements "$APP_ENTITLEMENTS" "$APP_BUNDLE"
```

| Flag | Purpose |
|------|---------|
| `--force` | Allow re-signing |
| `--timestamp` | Apple servers timestamp the signature (required for notarization) |
| `--options runtime` | Hardened runtime (required for notarization) |
| `--entitlements` | Apply entitlements file |

### Signing Order (Critical)

Components must be signed innermost-first:

1. **Helper binaries** (CLI tools, watchdog)
2. **Widget extensions** (`.appex` bundles with separate entitlements)
3. **Sparkle framework** (sign nested binaries: Autoupdate, Updater, XPC services, then framework root)
4. **Main app bundle** (last)

### Entitlements Files

Two entitlements XMLs are generated dynamically:

**Main App** (`CodexBar.entitlements`):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.steipete.codexbar</string>
    </array>
</dict>
</plist>
```

**Widget Extension** (`CodexBarWidget.entitlements`):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.steipete.codexbar</string>
    </array>
</dict>
</plist>
```

### Runtime Signature Verification

The app verifies it's properly Developer ID signed before enabling updates:

```swift
func isDeveloperIDSigned(bundleURL: URL) -> Bool {
    var staticCode: SecStaticCode?
    guard SecStaticCodeCreateWithPath(bundleURL as CFURL, [], &staticCode) == errSecSuccess,
          let code = staticCode else { return false }

    var info: CFDictionary?
    guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
          let dict = info as? [String: Any],
          let certs = dict[kSecCodeInfoCertificates as String] as? [SecCertificate],
          let cert = certs.first,
          let summary = SecCertificateCopySubjectSummary(cert) as String? else { return false }

    return summary.hasPrefix("Developer ID Application:")
}
```

---

## 2. Notarization Setup

### Credentials (Environment Variables)

| Variable | Description |
|----------|-------------|
| `APP_STORE_CONNECT_API_KEY_P8` | Private key in PEM format |
| `APP_STORE_CONNECT_KEY_ID` | Key identifier from App Store Connect |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer (Team) ID from App Store Connect |

### Notarization Process

```bash
# 1. Create temporary P8 file from env var
echo "$APP_STORE_CONNECT_API_KEY_P8" | sed 's/\\n/\n/g' > /tmp/api-key.p8

# 2. Zip the app with ditto (avoids AppleDouble files)
ditto --norsrc -c -k --keepParent "$APP_BUNDLE" "/tmp/${APP_NAME}Notarize.zip"

# 3. Submit for notarization and wait
xcrun notarytool submit "/tmp/${APP_NAME}Notarize.zip" \
  --key /tmp/api-key.p8 \
  --key-id "$APP_STORE_CONNECT_KEY_ID" \
  --issuer "$APP_STORE_CONNECT_ISSUER_ID" \
  --wait

# 4. Staple the notarization ticket to the app
xcrun stapler staple "$APP_BUNDLE"
```

### Post-Notarization Validation

```bash
# Verify Gatekeeper approval
spctl -a -t exec -vv "$APP_BUNDLE"

# Verify stapling
stapler validate "$APP_BUNDLE"
```

---

## 3. Sparkle Update Framework

### Framework Details

- **Version**: Sparkle 2.8.1
- **Package.swift dependency**: `.package(url: "https://github.com/sparkle-project/Sparkle", from: "2.8.1")`
- **Conditional compilation**: `#if canImport(Sparkle) && ENABLE_SPARKLE`

### Info.plist Configuration

```xml
<key>SUFeedURL</key>
<string>https://raw.githubusercontent.com/steipete/CodexBar/main/appcast.xml</string>

<key>SUPublicEDKey</key>
<string>AGCY8w5vHirVfGGDGc8Szc5iuOqupZSh9pMj/Qs67XI=</string>

<key>SUEnableAutomaticChecks</key>
<true/>
```

### EdDSA Key Management

| Key Type | Storage | Purpose |
|----------|---------|---------|
| **Public** (Ed25519) | Embedded in Info.plist | Verify update signatures |
| **Private** (Ed25519) | Secure local file (Dropbox backup) | Sign appcast entries |

**Private key reference**: `SPARKLE_PRIVATE_KEY_FILE` environment variable

### Updater Abstraction Protocol

```swift
@MainActor
protocol UpdaterProviding: AnyObject {
    var automaticallyChecksForUpdates: Bool { get set }
    var automaticallyDownloadsUpdates: Bool { get set }
    var isAvailable: Bool { get }
    var unavailableReason: String? { get }
    var updateStatus: UpdateStatus { get }
    func checkForUpdates(_ sender: Any?)
}
```

### Contexts Where Updates Are Disabled

- Non-bundled apps (debug builds from `swift run`)
- Homebrew Cask installs (use `brew upgrade` instead)
- Non-Developer ID signed apps

---

## 4. Appcast (Update Feed) Configuration

### Feed Structure

- **Format**: RSS 2.0 + Sparkle namespace
- **Hosting**: Raw file in GitHub repo (`appcast.xml` committed to main)
- **URL**: `https://raw.githubusercontent.com/steipete/CodexBar/main/appcast.xml`

### Example Appcast Entry

```xml
<item>
    <title>0.17.0</title>
    <pubDate>Wed, 31 Dec 2025 23:12:24 +0100</pubDate>
    <sparkle:version>48</sparkle:version>
    <sparkle:shortVersionString>0.17.0</sparkle:shortVersionString>
    <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
    <description><![CDATA[<h2>CodexBar 0.17.0</h2>...HTML release notes...]]></description>
    <enclosure
        url="https://github.com/steipete/CodexBar/releases/download/v0.17.0/CodexBar-0.17.0.zip"
        length="14296774"
        type="application/octet-stream"
        sparkle:edSignature="8n//nfQb9cz3hyoc/4+eitFvGl/FJrruUS99aIfqHwgtXhi1V4he9dKh7zKNt78mcP6raJGg+Ha5yHgglfSTDQ=="/>
</item>
```

### Appcast Generation

Uses Sparkle's `generate_appcast` tool:

```bash
generate_appcast \
  --ed-key-file "$PRIVATE_KEY_FILE" \
  --download-url-prefix "https://github.com/steipete/CodexBar/releases/download/v${VERSION}/" \
  --embed-release-notes \
  --link "$FEED_URL" \
  "$WORK_DIR"
```

### Appcast Verification Script

Validates before committing:
- Entry contains version, URL, signature, length
- Downloaded zip size matches `length` attribute
- EdDSA signature is valid

---

## 5. Distribution Channels

| Channel | Method | Update Mechanism |
|---------|--------|------------------|
| **Direct Download** | GitHub Releases (.zip) | Sparkle auto-update |
| **Homebrew Cask** | `brew install --cask steipete/tap/codexbar` | Homebrew (Sparkle disabled) |

### GitHub Release Artifacts

Each release includes:
1. `CodexBar-{version}.zip` - Notarized, code-signed app bundle
2. `CodexBar-{version}.dSYM.zip` - Debug symbols for crash reporting

---

## 6. Version Management

### version.env File

```bash
MARKETING_VERSION=0.17.0
BUILD_NUMBER=48
```

- **MARKETING_VERSION**: Semantic version displayed to users
- **BUILD_NUMBER**: Integer, must be monotonically increasing (Sparkle requirement)

### Info.plist Injection

Values from `version.env` are injected into dynamically generated Info.plist:
- `CFBundleShortVersionString` = MARKETING_VERSION
- `CFBundleVersion` = BUILD_NUMBER

---

## 7. Build Scripts Overview

### Key Scripts

| Script | Purpose |
|--------|---------|
| `Scripts/package_app.sh` | Assemble app bundle with resources & frameworks |
| `Scripts/sign-and-notarize.sh` | Build, sign, notarize, staple, create .zip |
| `Scripts/make_appcast.sh` | Generate signed Sparkle appcast entry |
| `Scripts/verify_appcast.sh` | Validate appcast signature & enclosure size |
| `Scripts/release.sh` | End-to-end release automation |
| `Scripts/setup_dev_signing.sh` | Create self-signed dev certificate |

### package_app.sh Flow

1. Icon conversion (`.icon` bundle → `.icns` via `iconutil`)
2. Architecture selection (single or universal arm64 + x86_64)
3. Swift compilation (`swift build -c release --arch {ARCH}`)
4. Bundle creation (manual `CodexBar.app` directory structure)
5. Copy resources (icons, SwiftPM resource bundles)
6. Bundle Sparkle.framework (copy + sign with nested XPCs)
7. Generate entitlements (create `.entitlements` XMLs)
8. Sign everything (innermost to outermost)
9. Validate (verify architecture count with `lipo -archs`)
10. Cleanup (strip extended attributes)

### release.sh Flow

1. Check clean git worktree + finalized CHANGELOG
2. Run swiftformat, swiftlint, swift test
3. Execute sign-and-notarize.sh
4. Validate Sparkle key file
5. Extract release notes from CHANGELOG
6. Create git tag `v${VERSION}`
7. Push tag to origin
8. Create GitHub release with zip + dSYM (`gh release create`)
9. Generate + sign appcast entry
10. Verify appcast signature + enclosure size
11. Commit appcast.xml to main
12. Push appcast commit

---

## 8. CI/CD Workflows

### ci.yml (Main CI)

**Triggers**: Every push + pull requests

**Steps**:
1. Select Xcode version
2. Install Swift toolchain
3. Run linting (`swiftformat --lint`, `swiftlint --strict`)
4. Run tests (`swift test --parallel`)
5. Matrix build for Linux CLI (ubuntu x86_64 + arm64)

### release-cli.yml (Linux CLI Releases)

**Triggers**: GitHub release publish + manual dispatch

**Steps**:
1. Matrix build for Linux architectures
2. Package as `.tar.gz`
3. Generate SHA256 checksums
4. Upload to GitHub release

---

## 9. Security Considerations

### Key Storage

| Secret | Storage Location |
|--------|------------------|
| Developer ID Certificate | macOS Keychain (system) |
| Sparkle Private Key | Secure local file (Dropbox backup) |
| App Store Connect API Key | Environment variable in CI |

### Sparkle Security

- EdDSA (Ed25519) signatures on all updates
- Public key embedded in app, private key never committed
- Signature verified before update installation

### Self-Signed Dev Certificate Setup

For local development without a paid Developer ID:

```bash
# Scripts/setup_dev_signing.sh creates:
# - Self-signed RSA-4096 certificate
# - Imports to login keychain
# - User must manually trust in Keychain.app
```

---

## 10. Info.plist Dynamic Generation

Key entries generated in `package_app.sh`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.steipete.codexbar</string>

    <key>CFBundleExecutable</key>
    <string>CodexBar</string>

    <key>CFBundleShortVersionString</key>
    <string>0.17.0</string>

    <key>CFBundleVersion</key>
    <string>48</string>

    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>

    <key>LSUIElement</key>
    <true/> <!-- Menu bar only, no Dock icon -->

    <key>SUFeedURL</key>
    <string>https://raw.githubusercontent.com/steipete/CodexBar/main/appcast.xml</string>

    <key>SUPublicEDKey</key>
    <string>AGCY8w5vHirVfGGDGc8Szc5iuOqupZSh9pMj/Qs67XI=</string>

    <key>SUEnableAutomaticChecks</key>
    <true/>

    <key>CodexBuildTimestamp</key>
    <string>2025-12-31T22:12:24Z</string>

    <key>CodexGitCommit</key>
    <string>abc1234</string>
</dict>
</plist>
```

---

## 11. Documentation Files in CodexBar

| File | Purpose |
|------|---------|
| `docs/sparkle.md` | Sparkle configuration details |
| `docs/RELEASING.md` | Complete release checklist |
| `docs/releasing-homebrew.md` | Homebrew tap update process |
| `CHANGELOG.md` | Release notes (parsed for appcast HTML) |

---

## 12. Implementation Recommendations for MarkdownViewer

### Phase 1: Code Signing & Notarization

1. Create `Scripts/` directory with signing scripts
2. Set up Developer ID certificate (or self-signed for dev)
3. Create `version.env` for version management
4. Update `build.sh` to include signing and notarization
5. Create entitlements file (minimal, no sandbox for document viewer)

### Phase 2: Sparkle Integration

1. Add Sparkle dependency to `Package.swift`
2. Generate EdDSA keypair (`generate_keys` from Sparkle)
3. Embed public key in Info.plist
4. Create `appcast.xml` in repo root
5. Add updater UI to the app (menu item "Check for Updates...")
6. Create `make_appcast.sh` script

### Phase 3: Release Automation

1. Create `release.sh` script following CodexBar pattern
2. Set up GitHub Actions for CI (lint, test, build)
3. Document release process in `docs/RELEASING.md`

### Required Secrets/Credentials

- Developer ID Application certificate (Apple Developer Program membership required)
- App Store Connect API key (for notarization)
- Sparkle EdDSA private key (generate locally, store securely)

---

## Appendix: File Structure Reference

```
CodexBar/
├── Scripts/
│   ├── package_app.sh          # Bundle assembly
│   ├── sign-and-notarize.sh    # Signing + notarization
│   ├── make_appcast.sh         # Appcast generation
│   ├── verify_appcast.sh       # Appcast validation
│   ├── release.sh              # Full release automation
│   ├── setup_dev_signing.sh    # Dev certificate setup
│   └── changelog-to-html.sh    # CHANGELOG → HTML
├── .github/
│   └── workflows/
│       ├── ci.yml              # Main CI pipeline
│       └── release-cli.yml     # Linux CLI releases
├── Sources/
│   └── CodexBar/
│       └── CodexbarApp.swift   # Sparkle integration
├── docs/
│   ├── sparkle.md
│   ├── RELEASING.md
│   └── releasing-homebrew.md
├── Package.swift               # SPM manifest with Sparkle
├── appcast.xml                 # Sparkle update feed
├── version.env                 # Version numbers
└── CHANGELOG.md                # Release notes source
```

---

## Appendix B: Detailed CI/CD & Release Automation

This section provides an in-depth look at the automation infrastructure.

### GitHub Actions Workflows

#### ci.yml - Main CI Pipeline

**Triggers**: Every push to any branch + all pull requests

**Jobs**:

1. **`lint-build-test`** (macOS)
   ```yaml
   - Select Xcode 26.1.1 (fallback to 26.1 or default)
   - Install Swift 6.2 toolchain
   - Run SwiftFormat: swiftformat --lint Sources Tests
   - Run SwiftLint: swiftlint --strict
   - Run tests: swift test --parallel
   ```

2. **`build-linux-cli`** (Matrix: ubuntu x64 + arm64)
   ```yaml
   - Install Swift 6.2.1 via swift-actions/setup-swift@v3
   - Build: swift build -c release --product CodexBarCLI --static-swift-stdlib
   - Smoke tests: --help, --version, verify --web fails on Linux
   ```

#### release-cli.yml - Linux CLI Releases

**Triggers**:
- `release: types: [published]` (automatic on GitHub release)
- `workflow_dispatch` (manual)

**Permissions**: `contents: write`

**Matrix**: linux-x64 (ubuntu-24.04), linux-arm64 (ubuntu-24.04-arm)

**Steps**:
```yaml
1. Checkout code
2. Setup Swift 6.2.1
3. Build CodexBarCLI (release, static stdlib)
4. Package: CodexBarCLI-{TAG}-linux-{ARCH}.tar.gz
5. Generate SHA256 checksum
6. Upload to GitHub release: gh release upload "$TAG" $ASSET $ASSET.sha256 --clobber
```

#### upstream-monitor.yml - Dependency Tracking

**Triggers**:
- Scheduled: Monday & Thursday at 9 AM UTC
- Manual: `workflow_dispatch`

**Purpose**: Track changes in upstream dependencies, create issues for review

### Release Script Deep Dive

**File**: `Scripts/release.sh`

```
┌─────────────────────────────────────────────────────────────────┐
│                    RELEASE.SH EXECUTION FLOW                     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  1. VALIDATION PHASE                                            │
│     ├─ Source version.env and library files                     │
│     ├─ Verify clean git worktree (no uncommitted changes)       │
│     ├─ Validate CHANGELOG.md is finalized (validate_changelog)  │
│     └─ Verify appcast.xml monotonic versioning                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  2. CODE QUALITY CHECKS                                         │
│     ├─ SwiftFormat (lint mode - fails if changes needed)        │
│     ├─ SwiftLint (strict mode - all warnings are errors)        │
│     └─ swift test (full test suite must pass)                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  3. BUILD & SIGN PHASE                                          │
│     ├─ Call Scripts/sign-and-notarize.sh                        │
│     ├─ Extract Sparkle private key path                         │
│     └─ Setup cleanup traps for temporary key files              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  4. RELEASE OPERATIONS                                          │
│     ├─ Create git tag: git tag "v${VERSION}"                    │
│     ├─ Push tag to origin                                       │
│     ├─ Extract release notes from CHANGELOG.md                  │
│     └─ Create GitHub release: gh release create "$TAG" ...      │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  5. APPCAST MANAGEMENT                                          │
│     ├─ Call Scripts/make_appcast.sh                             │
│     ├─ Regenerate appcast.xml with EdDSA signatures             │
│     ├─ Verify entry with Scripts/verify_appcast.sh              │
│     └─ Commit updated appcast.xml to main                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  6. POST-RELEASE (Optional)                                     │
│     ├─ If RUN_SPARKLE_UPDATE_TEST=1:                            │
│     │   └─ Call Scripts/test_live_update.sh                     │
│     └─ Verify all release assets with check-release-assets.sh   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  7. FINALIZATION                                                │
│     └─ Push appcast commit and all tags to origin               │
└─────────────────────────────────────────────────────────────────┘
```

### Supporting Scripts Detail

#### sign-and-notarize.sh

**Purpose**: Build, sign, notarize, and package the app

```bash
# Key functions:
1. Environment Setup
   ├─ App identity (Developer ID Application)
   ├─ Bundle ID and configuration
   └─ App Store Connect API credentials validation

2. Build Phase
   ├─ Support architectures: arm64, x86_64, or universal
   └─ Optional clean builds

3. Code Signing (innermost to outermost)
   ├─ Sign helper executables
   ├─ Sign widget extensions (.appex)
   ├─ Sign Sparkle framework and nested XPCs
   └─ Sign main app bundle with:
      codesign --force --timestamp --options runtime --sign "$APP_IDENTITY"

4. Notarization
   ├─ Zip app bundle with ditto
   ├─ Submit: xcrun notarytool submit --wait
   └─ Staple: xcrun stapler staple

5. Distribution
   ├─ Remove extended attributes (xattr -rc)
   ├─ Validate notarization status
   ├─ Create universal dSYM via lipo
   └─ Package final ZIP
```

#### make_appcast.sh

**Purpose**: Generate signed Sparkle update feed entry

```bash
1. Validate ZIP file and SPARKLE_PRIVATE_KEY_FILE exists
2. Extract version from filename or SPARKLE_RELEASE_VERSION env
3. Generate HTML release notes via changelog-to-html.sh
4. Run generate_appcast:
   generate_appcast \
     --ed-key-file "$PRIVATE_KEY_FILE" \
     --download-url-prefix "https://github.com/.../releases/download/v${VERSION}/" \
     --embed-release-notes \
     --link "$FEED_URL" \
     "$WORK_DIR"
5. Output: Updated appcast.xml
```

#### verify_appcast.sh

**Purpose**: Validate Sparkle update entries before committing

```bash
1. Validate Sparkle private key file exists
2. Parse appcast.xml (extract URL, signature, length)
3. Download release ZIP
4. Verify file size matches declaration
5. Verify EdDSA signature with sign_update tool
6. Cleanup via EXIT trap
```

#### validate_changelog.sh

**Purpose**: Pre-release changelog verification

```bash
1. Verify VERSION argument matches top section of CHANGELOG.md
2. Confirm section exists: grep "^## ${VERSION}"
3. Detect unreleased entries at top (reject if found)
4. Exit with error on any validation failure
```

#### changelog-to-html.sh

**Purpose**: Convert CHANGELOG.md to HTML for appcast

```
Markdown Input          →  HTML Output
─────────────────────────────────────────
## Version X.X.X        →  <h2>...</h2>
### Subsection          →  <h3>...</h3>
- List item             →  <ul><li>...</li></ul>
**bold**                →  <strong>...</strong>
`code`                  →  <code>...</code>
[Link](url)             →  <a href="">...</a>
```

### Quality Gates Summary

| Gate | Tool | Strictness | When |
|------|------|-----------|------|
| Code formatting | SwiftFormat | Lint (fails on diff) | CI + Release |
| Linting | SwiftLint | Strict (warnings = errors) | CI + Release |
| Testing | swift test | All must pass | CI + Release |
| Changelog | validate_changelog.sh | Must be finalized | Release |
| Appcast | verify_appcast.sh | Signature must validate | Release |
| Assets | check-release-assets.sh | All artifacts exist | Release |

### Secrets & Environment Variables

**GitHub Actions Secrets**:
| Secret | Used In | Purpose |
|--------|---------|---------|
| `GITHUB_TOKEN` | release-cli.yml | Upload release assets via gh CLI |

**Local Environment Variables**:
| Variable | Purpose |
|----------|---------|
| `SPARKLE_PRIVATE_KEY_FILE` | Path to Ed25519 private key |
| `APP_STORE_CONNECT_API_KEY_P8` | Notarization API key |
| `APP_STORE_CONNECT_KEY_ID` | Notarization key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | Notarization issuer ID |
| `RUN_SPARKLE_UPDATE_TEST` | Trigger live update testing |
| `MARKETING_VERSION` | From version.env |
| `BUILD_NUMBER` | From version.env |

### Workflow Orchestration Diagram

```
Developer Push to Branch
         │
         ▼
┌────────────────────────┐
│   CI Workflow (ci.yml) │
│  ├─ macOS: lint, test  │
│  └─ Linux: build CLI   │
└────────────────────────┘
         │
         ▼
   [All checks pass]
         │
         ▼
    Merge to main
         │
         ▼
┌────────────────────────────────────────┐
│  Developer runs Scripts/release.sh     │
│  (Manual - controlled release)         │
│  ├─ Validates changelog                │
│  ├─ Runs quality checks                │
│  ├─ Builds & signs (sign-and-notarize) │
│  ├─ Creates git tag                    │
│  ├─ Publishes GitHub release (gh CLI)  │
│  ├─ Generates appcast (make_appcast)   │
│  ├─ Verifies appcast (verify_appcast)  │
│  └─ Commits appcast to main            │
└────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────┐
│  GitHub detects release published      │
│                 │                      │
│                 ▼                      │
│  Release CLI Workflow (release-cli)    │
│  ├─ Matrix: Build x64 & ARM64          │
│  ├─ Package tarballs + checksums       │
│  └─ Upload to GitHub release           │
└────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────┐
│  Sparkle Clients                       │
│  ├─ Check appcast.xml periodically     │
│  ├─ Download CodexBar-{VERSION}.zip    │
│  └─ Verify signature before install    │
└────────────────────────────────────────┘
```

### Key Architectural Patterns

1. **Modular Scripts**: Single responsibility, composable, independently callable
2. **Defensive Programming**: `set -euo pipefail`, trap handlers, explicit validation
3. **CI/CD Separation**: CI automatic, releases manual (developer control)
4. **Multi-Architecture**: Universal macOS binaries, separate Linux builds
5. **Security-First**: Notarization, Ed25519 signatures, private keys never committed
