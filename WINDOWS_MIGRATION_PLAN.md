# CodexBar Windows Migration Plan

## Executive Summary

This document outlines the complete plan for migrating CodexBar from macOS to Windows, removing all Mac-specific code and dependencies. CodexBar is currently a Swift macOS menu bar application that monitors API usage across 15+ AI providers.

---

## Current Architecture Overview

| Component | Technology | Files |
|-----------|------------|-------|
| **Build System** | Swift Package Manager | `Package.swift` |
| **GUI Layer** | AppKit + SwiftUI | 200+ files in `Sources/CodexBar/` |
| **Core Logic** | Swift (cross-platform) | `Sources/CodexBarCore/` |
| **CLI** | Swift (already cross-platform) | `Sources/CodexBarCLI/` |
| **Widget** | WidgetKit | `Sources/CodexBarWidget/` |
| **Helpers** | Swift CLI tools | `CodexBarClaudeWatchdog`, `CodexBarClaudeWebProbe` |

---

## Phase 1: Remove macOS-Specific Components

### 1.1 Build Targets to Remove

Remove the following targets from `Package.swift`:

| Target | Reason |
|--------|--------|
| `CodexBar` | Main macOS app (AppKit/SwiftUI GUI) |
| `CodexBarWidget` | WidgetKit (macOS only) |
| `CodexBarClaudeWatchdog` | macOS PTY helper |
| `CodexBarClaudeWebProbe` | macOS WebKit helper |

### 1.2 Dependencies to Remove

| Dependency | Location | Reason |
|------------|----------|--------|
| **Sparkle** | `Package.swift` line 9 | macOS auto-updater |
| **KeyboardShortcuts** | `Package.swift` line 10 | macOS global hotkeys |
| **SweetCookieKit** | External dependency | macOS browser cookie access |

### 1.3 Source Directories to Remove

```
Sources/CodexBar/                    # Entire macOS GUI app
Sources/CodexBarWidget/              # WidgetKit extension
Sources/CodexBarClaudeWatchdog/      # macOS PTY helper
Sources/CodexBarClaudeWebProbe/      # macOS WebKit helper
```

### 1.4 macOS Framework Imports to Remove

| Framework | Files Affected | Purpose |
|-----------|----------------|---------|
| `AppKit` | 150+ files | NSStatusItem, NSMenu, NSWindow |
| `WebKit` | 15+ files | WKWebView, cookie access |
| `Security` | 5+ files | Keychain (SecItem* APIs) |
| `ServiceManagement` | 1 file | SMAppService (login items) |
| `QuartzCore` | 3 files | CADisplayLink |
| `CoreVideo` | 2 files | CVDisplayLink |

---

## Phase 2: Core Logic Refactoring

### 2.1 Files to Keep (Platform-Agnostic)

These files contain provider integration logic and can be reused:

```
Sources/CodexBarCore/
├── Providers/           # All provider fetch logic (keep all)
│   ├── Anthropic/
│   ├── Augment/
│   ├── Cerebras/
│   ├── Codex/
│   ├── Copilot/
│   ├── Cursor/
│   ├── DeepSeek/
│   ├── Factory/
│   ├── Gemini/
│   ├── JetBrains/
│   ├── Kimi/
│   ├── Mistral/
│   ├── MiniMax/
│   ├── OpenAI/
│   ├── OpenRouter/
│   ├── Windsurf/
│   ├── xAI/
│   └── zAI/
├── Models/              # Data models (keep all)
├── Logging/             # Structured logging (keep all)
├── Config/              # Configuration (keep all)
└── Networking/          # HTTP clients (keep all)
```

### 2.2 Files Requiring Modification

| File | Required Changes |
|------|------------------|
| `KeychainCacheStore.swift` | Replace with Windows Credential Manager |
| `BrowserDetection.swift` | Replace with Windows registry/path detection |
| `PathEnvironment.swift` | Replace with Windows PATH handling |
| `WebKit/*.swift` | Replace with Windows web scraping solution |

### 2.3 Conditional Compilation Blocks

Remove or replace all `#if os(macOS)` blocks (42+ instances):

```swift
// Current pattern (REMOVE):
#if os(macOS)
import AppKit
// macOS-specific code
#else
// Fallback
#endif

// New pattern (REPLACE WITH):
#if os(Windows)
import WinSDK
// Windows-specific code
#endif
```

---

## Phase 3: Windows Implementation

### 3.1 GUI Framework Decision

**Recommended: WPF (.NET) or C++/WinUI 3**

| Option | Pros | Cons |
|--------|------|------|
| **WPF (.NET)** | Mature, rich UI, XAML | Requires .NET runtime |
| **WinUI 3** | Modern, Windows 11 native | Newer, less resources |
| **Electron** | Cross-platform, web tech | Heavy, not native |
| **Swift for Windows** | Same language | Limited Windows support |

**Recommendation**: Build Windows GUI separately in C#/WPF or C++/WinUI 3, calling into the core Swift CLI for data.

### 3.2 System Tray Implementation

Replace `NSStatusItem` with Windows system tray:

```csharp
// Windows System Tray (C# WPF example)
using System.Windows.Forms;

NotifyIcon trayIcon = new NotifyIcon
{
    Icon = new Icon("icon.ico"),
    Visible = true,
    ContextMenuStrip = CreateContextMenu()
};
```

### 3.3 Credential Storage

Replace macOS Keychain with Windows Credential Manager:

| macOS API | Windows Replacement |
|-----------|---------------------|
| `SecItemAdd` | `CredWrite` (wincred.h) |
| `SecItemCopyMatching` | `CredRead` (wincred.h) |
| `SecItemUpdate` | `CredWrite` (wincred.h) |
| `SecItemDelete` | `CredDelete` (wincred.h) |

```cpp
// Windows Credential Manager (C++ example)
#include <wincred.h>

CREDENTIALW cred = {0};
cred.Type = CRED_TYPE_GENERIC;
cred.TargetName = L"CodexBar/APIToken";
cred.CredentialBlobSize = sizeof(token);
cred.CredentialBlob = (LPBYTE)token;
cred.Persist = CRED_PERSIST_LOCAL_MACHINE;
CredWriteW(&cred, 0);
```

### 3.4 Browser Cookie Access

Replace macOS browser paths with Windows equivalents:

| Browser | macOS Path | Windows Path |
|---------|------------|--------------|
| Chrome | `~/Library/Application Support/Google/Chrome/Default/Cookies` | `%LOCALAPPDATA%\Google\Chrome\User Data\Default\Network\Cookies` |
| Firefox | `~/Library/Application Support/Firefox/Profiles/*/cookies.sqlite` | `%APPDATA%\Mozilla\Firefox\Profiles\*\cookies.sqlite` |
| Edge | N/A | `%LOCALAPPDATA%\Microsoft\Edge\User Data\Default\Network\Cookies` |

**DPAPI Decryption Required**: Windows Chrome/Edge cookies are encrypted with DPAPI:
```cpp
#include <dpapi.h>
CryptUnprotectData(&encryptedBlob, NULL, NULL, NULL, NULL, 0, &decryptedBlob);
```

### 3.5 Web Scraping

Replace WebKit with Windows alternatives:

| Option | Description |
|--------|-------------|
| **CefSharp** | Chromium Embedded Framework for .NET |
| **WebView2** | Microsoft Edge WebView2 control |
| **Playwright** | Cross-platform browser automation |

### 3.6 Launch at Login

Replace `SMAppService` with Windows startup registry:

```cpp
// Windows Registry Startup (C++ example)
HKEY hKey;
RegOpenKeyExW(HKEY_CURRENT_USER,
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Run",
    0, KEY_SET_VALUE, &hKey);
RegSetValueExW(hKey, L"CodexBar", 0, REG_SZ,
    (LPBYTE)exePath, (wcslen(exePath) + 1) * sizeof(WCHAR));
RegCloseKey(hKey);
```

### 3.7 Auto-Updates

Replace Sparkle with Windows update mechanism:

| Option | Description |
|--------|-------------|
| **MSIX** | Windows Store / sideloading with auto-update |
| **Squirrel.Windows** | GitHub-hosted auto-updater |
| **Custom HTTP** | Self-hosted update server |

### 3.8 Global Keyboard Shortcuts

Replace `KeyboardShortcuts` package with Windows API:

```cpp
// Windows Global Hotkey (C++ example)
#include <windows.h>
RegisterHotKey(hwnd, 1, MOD_CONTROL | MOD_SHIFT, 'C');
```

---

## Phase 4: Build System Changes

### 4.1 Package.swift Modifications

```swift
// Update platform requirement
platforms: [.windows(.v10)]  // Note: Swift for Windows uses custom toolchain

// Remove macOS targets
// Keep only:
// - CodexBarCore (library)
// - CodexBarCLI (CLI executable)
```

### 4.2 New Build Scripts

| Script | Purpose |
|--------|---------|
| `build_windows.ps1` | PowerShell build script |
| `package_windows.ps1` | MSIX/installer creation |
| `sign_windows.ps1` | Authenticode code signing |

### 4.3 CI/CD Changes

Remove macOS CI jobs, add Windows:

```yaml
# GitHub Actions for Windows
jobs:
  build-windows:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build with Swift
        run: swift build -c release
      - name: Sign with Authenticode
        run: signtool sign /f cert.pfx /p ${{ secrets.CERT_PASSWORD }} CodexBar.exe
```

---

## Phase 5: Migration Checklist

### 5.1 Code Removal Tasks

- [ ] Remove `Sources/CodexBar/` directory
- [ ] Remove `Sources/CodexBarWidget/` directory
- [ ] Remove `Sources/CodexBarClaudeWatchdog/` directory
- [ ] Remove `Sources/CodexBarClaudeWebProbe/` directory
- [ ] Remove Sparkle dependency from `Package.swift`
- [ ] Remove KeyboardShortcuts dependency from `Package.swift`
- [ ] Remove SweetCookieKit dependency
- [ ] Remove macOS-only targets from `Package.swift`
- [ ] Remove `#if os(macOS)` blocks or convert to `#if os(Windows)`
- [ ] Remove `Scripts/package_app.sh`
- [ ] Remove `Scripts/compile_and_run.sh`
- [ ] Remove `Scripts/sign-and-notarize.sh`
- [ ] Remove `appcast.xml`
- [ ] Remove `.xcodeproj` files (if any)

### 5.2 Windows Implementation Tasks

- [ ] Create Windows GUI project (WPF/WinUI)
- [ ] Implement system tray icon
- [ ] Implement context menus
- [ ] Implement preferences window
- [ ] Implement Windows Credential Manager integration
- [ ] Implement Windows browser cookie access
- [ ] Implement WebView2 for web scraping
- [ ] Implement launch at login via registry
- [ ] Implement auto-updater
- [ ] Implement global hotkey support
- [ ] Create Windows installer (MSIX/MSI)
- [ ] Set up Authenticode code signing
- [ ] Create Windows build scripts
- [ ] Set up Windows CI/CD pipeline

### 5.3 Testing Tasks

- [ ] Test all provider integrations on Windows
- [ ] Test credential storage/retrieval
- [ ] Test browser cookie access for all browsers
- [ ] Test web scraping functionality
- [ ] Test system tray behavior
- [ ] Test auto-update mechanism
- [ ] Test launch at login
- [ ] Test global hotkeys
- [ ] Performance testing on Windows 10/11

---

## Phase 6: File-by-File Removal Guide

### Sources to DELETE (macOS-only):

```
Sources/CodexBar/
├── App/
│   ├── CodexbarApp.swift              # DELETE - NSApplicationDelegate
│   └── AppNotifications.swift         # DELETE - UNUserNotificationCenter
├── Controllers/
│   ├── StatusItemController.swift     # DELETE - NSStatusItem
│   ├── StatusItemController+*.swift   # DELETE - All extensions
│   └── OpenAICreditsPurchase*.swift   # DELETE - NSWindowController
├── Views/
│   ├── IconRenderer.swift             # DELETE - NSImage
│   ├── IconView.swift                 # DELETE - NSView
│   ├── DisplayLink.swift              # DELETE - CVDisplayLink
│   ├── MouseLocationReader.swift      # DELETE - NSTrackingArea
│   └── *.swift                        # DELETE - All SwiftUI views
├── Managers/
│   └── LaunchAtLoginManager.swift     # DELETE - SMAppService
└── Resources/
    └── Assets.xcassets                # DELETE - macOS assets
```

### Sources to MODIFY (cross-platform core):

```
Sources/CodexBarCore/
├── Cache/
│   └── KeychainCacheStore.swift       # MODIFY - Replace Keychain
├── Browser/
│   └── BrowserDetection.swift         # MODIFY - Windows paths
├── Environment/
│   └── PathEnvironment.swift          # MODIFY - Windows PATH
├── WebKit/
│   └── *.swift                        # MODIFY - Replace WebKit
└── OpenAIWeb/
    └── *.swift                        # MODIFY - Replace WKWebView
```

### Sources to KEEP (platform-agnostic):

```
Sources/CodexBarCore/
├── Providers/                         # KEEP - All provider logic
├── Models/                            # KEEP - Data models
├── Networking/                        # KEEP - HTTP clients
├── Logging/                           # KEEP - Structured logging
└── Config/                            # KEEP - Configuration

Sources/CodexBarCLI/                   # KEEP - Cross-platform CLI
```

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    CURRENT (macOS)                              │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │ CodexBar    │  │ CodexBar    │  │ CodexBarClaudeWatchdog  │  │
│  │ (GUI App)   │  │ Widget      │  │ (Helper)                │  │
│  │ [AppKit]    │  │ [WidgetKit] │  │                         │  │
│  └──────┬──────┘  └──────┬──────┘  └────────────┬────────────┘  │
│         │                │                      │               │
│         └────────────────┼──────────────────────┘               │
│                          ▼                                      │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                    CodexBarCore                           │  │
│  │  [Keychain] [WebKit] [Browser Detection] [Providers]      │  │
│  └───────────────────────────────────────────────────────────┘  │
│                          ▼                                      │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                    CodexBarCLI                            │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    TARGET (Windows)                             │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                  CodexBar Windows GUI                       ││
│  │                  [WPF / WinUI 3]                            ││
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐   ││
│  │  │ System Tray │ │ Preferences │ │ WebView2            │   ││
│  │  │ NotifyIcon  │ │ Window      │ │ (Web Scraping)      │   ││
│  │  └─────────────┘ └─────────────┘ └─────────────────────┘   ││
│  └──────────────────────────┬──────────────────────────────────┘│
│                             ▼                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                    CodexBarCore                           │  │
│  │  [CredManager] [WebView2] [Registry Detection] [Providers]│  │
│  └───────────────────────────────────────────────────────────┘  │
│                             ▼                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                    CodexBarCLI                            │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Estimated Effort

| Phase | Tasks | Estimated Hours |
|-------|-------|-----------------|
| Phase 1 | Remove macOS components | 4-6 hours |
| Phase 2 | Core logic refactoring | 15-20 hours |
| Phase 3 | Windows implementation | 80-100 hours |
| Phase 4 | Build system changes | 10-15 hours |
| Phase 5 | Testing & QA | 20-30 hours |
| **Total** | | **130-170 hours** |

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Swift for Windows limitations | High | Build GUI in C#/C++, CLI in Swift |
| Browser cookie DPAPI complexity | Medium | Use existing Windows crypto libraries |
| WebView2 availability | Low | Fallback to CefSharp if needed |
| Code signing complexity | Medium | Document Authenticode process thoroughly |
| Provider API changes during migration | Medium | Maintain regression tests |

---

## Recommendations

1. **Hybrid Architecture**: Keep Swift for core logic/CLI, build GUI in C#/WPF
2. **Incremental Migration**: Start with CLI-only Windows support, then add GUI
3. **Shared Data Layer**: Use JSON/HTTP IPC between Swift CLI and Windows GUI
4. **Feature Parity**: Prioritize core features (usage monitoring) before extras (web scraping)

---

## Next Steps

1. **Immediate**: Remove all macOS-only directories and dependencies
2. **Short-term**: Refactor core to remove macOS conditionals
3. **Medium-term**: Build Windows GUI prototype with system tray
4. **Long-term**: Full Windows feature implementation and testing

---

*Document created: 2026-01-30*
*Target: Windows 10/11*
*Source: CodexBar macOS codebase analysis*
