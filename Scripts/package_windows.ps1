# CodexBar Windows Packaging Script
# Creates a distributable package for Windows

param(
    [string]$Version = "0.0.0",
    [string]$OutputDir = ".\dist",
    [switch]$CreateInstaller,
    [switch]$SignBinary
)

$ErrorActionPreference = "Stop"

function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

function Write-Info($message) {
    Write-ColorOutput Cyan "[INFO] $message"
}

function Write-Success($message) {
    Write-ColorOutput Green "[SUCCESS] $message"
}

function Write-Warning($message) {
    Write-ColorOutput Yellow "[WARNING] $message"
}

function Write-Error($message) {
    Write-ColorOutput Red "[ERROR] $message"
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$buildDir = Join-Path $projectRoot ".build\release"
$exeName = "CodexBarCLI.exe"
$exePath = Join-Path $buildDir $exeName

# Ensure the build exists
if (-not (Test-Path $exePath)) {
    Write-Error "Executable not found: $exePath"
    Write-Info "Run build_windows.ps1 first"
    exit 1
}

# Create output directory
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

$OutputDir = Resolve-Path $OutputDir

Write-Info "Packaging CodexBar v$Version for Windows"

# Package name
$packageName = "CodexBar-v$Version-windows-x64"
$packageDir = Join-Path $OutputDir $packageName

# Clean and create package directory
if (Test-Path $packageDir) {
    Remove-Item -Recurse -Force $packageDir
}
New-Item -ItemType Directory -Path $packageDir | Out-Null

# Copy executable
Write-Info "Copying executable..."
Copy-Item $exePath $packageDir

# Sign binary if requested
if ($SignBinary) {
    Write-Info "Signing binary..."

    $certPath = $env:CODEXBAR_SIGN_CERT
    $certPassword = $env:CODEXBAR_SIGN_PASSWORD

    if (-not $certPath -or -not $certPassword) {
        Write-Warning "Signing skipped: CODEXBAR_SIGN_CERT and CODEXBAR_SIGN_PASSWORD environment variables not set"
    } else {
        $signedExe = Join-Path $packageDir $exeName
        try {
            & signtool sign /f $certPath /p $certPassword /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 $signedExe
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Binary signed successfully"
            } else {
                Write-Warning "Signing failed, continuing without signature"
            }
        } catch {
            Write-Warning "Signing failed: $_"
        }
    }
}

# Create README
$readmeContent = @"
CodexBar v$Version for Windows
================================

CodexBar is a CLI tool for monitoring API usage across AI providers.

Installation
------------
1. Add this directory to your PATH, or
2. Copy CodexBarCLI.exe to a directory in your PATH

Usage
-----
    CodexBarCLI.exe --help
    CodexBarCLI.exe usage
    CodexBarCLI.exe usage --provider claude

Supported Providers
-------------------
- Claude (Anthropic)
- Codex (OpenAI)
- Gemini (Google)
- Copilot (GitHub)
- Cursor
- JetBrains AI
- And more...

Configuration
-------------
Configuration is stored in:
    %APPDATA%\CodexBar\config.json

For more information, visit:
    https://github.com/steipete/CodexBar

"@

$readmeContent | Out-File -FilePath (Join-Path $packageDir "README.txt") -Encoding UTF8

# Create ZIP archive
$zipPath = Join-Path $OutputDir "$packageName.zip"
Write-Info "Creating ZIP archive..."

if (Test-Path $zipPath) {
    Remove-Item $zipPath
}

Compress-Archive -Path "$packageDir\*" -DestinationPath $zipPath

Write-Success "Created: $zipPath"

# Create installer if requested
if ($CreateInstaller) {
    Write-Info "Creating installer..."

    # Check for Inno Setup
    $innoSetup = Get-Command "iscc" -ErrorAction SilentlyContinue

    if (-not $innoSetup) {
        Write-Warning "Inno Setup not found. Skipping installer creation."
        Write-Info "Install Inno Setup from: https://jrsoftware.org/isinfo.php"
    } else {
        $issScript = @"
[Setup]
AppName=CodexBar
AppVersion=$Version
DefaultDirName={autopf}\CodexBar
DefaultGroupName=CodexBar
OutputDir=$OutputDir
OutputBaseFilename=CodexBar-v$Version-windows-x64-setup
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

[Files]
Source: "$packageDir\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{group}\CodexBar CLI"; Filename: "{app}\CodexBarCLI.exe"

[Registry]
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; \
    ValueType: expandsz; ValueName: "Path"; ValueData: "{olddata};{app}"; \
    Check: NeedsAddPath('{app}')

[Code]
function NeedsAddPath(Param: string): boolean;
var
  OrigPath: string;
begin
  if not RegQueryStringValue(HKLM, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 'Path', OrigPath)
  then begin
    Result := True;
    exit;
  end;
  Result := Pos(';' + Param + ';', ';' + OrigPath + ';') = 0;
end;
"@

        $issPath = Join-Path $OutputDir "CodexBar.iss"
        $issScript | Out-File -FilePath $issPath -Encoding UTF8

        & iscc $issPath

        if ($LASTEXITCODE -eq 0) {
            Write-Success "Installer created successfully"
        } else {
            Write-Warning "Installer creation failed"
        }

        Remove-Item $issPath
    }
}

# Cleanup package directory
Remove-Item -Recurse -Force $packageDir

Write-Success "Packaging complete!"
Write-Info "Output directory: $OutputDir"

# List created files
Get-ChildItem $OutputDir -Filter "CodexBar-v$Version*" | ForEach-Object {
    Write-Info "  - $($_.Name) ($([math]::Round($_.Length / 1MB, 2)) MB)"
}
