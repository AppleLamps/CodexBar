# CodexBar Windows Build Script
# Requires: Swift for Windows toolchain (https://www.swift.org/download/)

param(
    [ValidateSet("debug", "release")]
    [string]$Configuration = "release",
    [switch]$Clean,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

# Colors for output
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

function Write-Error($message) {
    Write-ColorOutput Red "[ERROR] $message"
}

# Check for Swift installation
function Test-SwiftInstallation {
    try {
        $swiftVersion = swift --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Info "Swift found: $($swiftVersion -split "`n" | Select-Object -First 1)"
            return $true
        }
    } catch {
        # Swift not found
    }
    return $false
}

# Main build function
function Build-CodexBar {
    Write-Info "Building CodexBar for Windows ($Configuration configuration)"

    $projectRoot = Split-Path -Parent $PSScriptRoot

    # Change to project root
    Push-Location $projectRoot

    try {
        # Clean if requested
        if ($Clean) {
            Write-Info "Cleaning build directory..."
            if (Test-Path ".build") {
                Remove-Item -Recurse -Force ".build"
            }
        }

        # Build arguments
        $buildArgs = @(
            "build",
            "-c", $Configuration,
            "--product", "CodexBarCLI"
        )

        if ($Verbose) {
            $buildArgs += "-v"
        }

        Write-Info "Running: swift $($buildArgs -join ' ')"

        # Run build
        & swift @buildArgs

        if ($LASTEXITCODE -ne 0) {
            Write-Error "Build failed with exit code $LASTEXITCODE"
            exit $LASTEXITCODE
        }

        # Find the built executable
        $exePath = Join-Path $projectRoot ".build\$Configuration\CodexBarCLI.exe"
        if (Test-Path $exePath) {
            Write-Success "Build successful!"
            Write-Info "Executable: $exePath"

            # Get file info
            $fileInfo = Get-Item $exePath
            Write-Info "Size: $([math]::Round($fileInfo.Length / 1MB, 2)) MB"
        } else {
            Write-Error "Executable not found at expected path: $exePath"
            exit 1
        }

    } finally {
        Pop-Location
    }
}

# Check prerequisites
Write-Info "Checking prerequisites..."

if (-not (Test-SwiftInstallation)) {
    Write-Error "Swift is not installed or not in PATH"
    Write-Info "Please install Swift for Windows from: https://www.swift.org/download/"
    exit 1
}

# Run the build
Build-CodexBar

Write-Success "Build complete!"
