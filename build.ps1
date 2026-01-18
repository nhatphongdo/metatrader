<#
.SYNOPSIS
    Build script for MetaTrader 5 EA and Indicator
.DESCRIPTION
    Compiles all MQ5 files and outputs to build/ directory with proper structure.
    Logs are saved to logs/ directory.
    Use -Install to copy built files to MetaTrader installation folder.
.NOTES
    This script automatically searches for MetaEditor64.exe in common installation paths.
#>

param(
    [switch]$Clean,   # Clean build directory before compiling
    [switch]$Verbose, # Show detailed output
    [switch]$Install  # Copy built files to MetaTrader installation folder
)

$ErrorActionPreference = "Stop"

# Script directory (project root)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Directories
$BuildDir = Join-Path $ScriptDir "build"
$LogsDir = Join-Path $ScriptDir "logs"
$EASourceDir = Join-Path $ScriptDir "expert-advisor"
$IndicatorSourceDir = Join-Path $ScriptDir "indicator"

# Output directories
$EABuildDir = Join-Path $BuildDir "expert-advisor"
$IndicatorBuildDir = Join-Path $BuildDir "indicator"

# Common MetaEditor paths on Windows
$MetaEditorPaths = @(
    "C:\Program Files\MetaTrader 5\metaeditor64.exe",
    "C:\Program Files (x86)\MetaTrader 5\metaeditor64.exe",
    "$env:LOCALAPPDATA\Programs\MetaTrader 5\metaeditor64.exe",
    "$env:APPDATA\MetaQuotes\Terminal\*\metaeditor64.exe",
    "D:\Program Files\MetaTrader 5\metaeditor64.exe",
    "D:\MetaTrader 5\metaeditor64.exe"
)

function Find-MetaEditor {
    foreach ($path in $MetaEditorPaths) {
        if ($path -like "*\*\*") {
            # Handle wildcard paths
            $resolved = Get-ChildItem -Path $path -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($resolved) {
                return $resolved.FullName
            }
        } elseif (Test-Path $path) {
            return $path
        }
    }

    # Try to find via registry
    $regPaths = @(
        "HKLM:\SOFTWARE\MetaQuotes Software Corp\MetaTrader 5",
        "HKCU:\SOFTWARE\MetaQuotes Software Corp\MetaTrader 5",
        "HKLM:\SOFTWARE\WOW6432Node\MetaQuotes Software Corp\MetaTrader 5"
    )

    foreach ($regPath in $regPaths) {
        if (Test-Path $regPath) {
            $installPath = Get-ItemProperty -Path $regPath -Name "InstallPath" -ErrorAction SilentlyContinue
            if ($installPath) {
                $editorPath = Join-Path $installPath.InstallPath "metaeditor64.exe"
                if (Test-Path $editorPath) {
                    return $editorPath
                }
            }
        }
    }

    return $null
}

function Initialize-Directories {
    # Create directories if they don't exist
    @($BuildDir, $LogsDir, $EABuildDir, $IndicatorBuildDir) | ForEach-Object {
        if (-not (Test-Path $_)) {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
            Write-Host "Created directory: $_" -ForegroundColor Gray
        }
    }

    if ($Clean) {
        Write-Host "Cleaning build directory..." -ForegroundColor Yellow
        Remove-Item -Path "$EABuildDir\*" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$IndicatorBuildDir\*" -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Compile-MQ5 {
    param(
        [string]$SourceFile,
        [string]$OutputDir,
        [string]$LogFile,
        [string]$MetaEditor
    )

    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($SourceFile)
    $outputFile = Join-Path $OutputDir "$fileName.ex5"

    Write-Host "  Compiling: $fileName.mq5" -ForegroundColor Cyan

    # Build arguments
    $args = @(
        "/compile:`"$SourceFile`"",
        "/log:`"$LogFile`""
    )

    # Run MetaEditor
    $process = Start-Process -FilePath $MetaEditor -ArgumentList $args -Wait -PassThru -NoNewWindow

    # Check log for results
    Start-Sleep -Milliseconds 500

    if (Test-Path $LogFile) {
        $logContent = Get-Content $LogFile -Encoding Unicode -Raw

        if ($logContent -match "(\d+)\s+error") {
            $errors = $matches[1]
        } else {
            $errors = 0
        }

        if ($logContent -match "(\d+)\s+warning") {
            $warnings = $matches[1]
        } else {
            $warnings = 0
        }

        if ([int]$errors -gt 0) {
            Write-Host "    FAILED: $errors error(s), $warnings warning(s)" -ForegroundColor Red
            return $false
        } else {
            Write-Host "    SUCCESS: $errors error(s), $warnings warning(s)" -ForegroundColor Green

            # Find and move .ex5 file to build directory
            $sourceDir = Split-Path $SourceFile -Parent
            $ex5Source = Join-Path $sourceDir "$fileName.ex5"
            if (Test-Path $ex5Source) {
                Copy-Item $ex5Source $OutputDir -Force
                Remove-Item $ex5Source -Force  # Xóa file .ex5 từ source
                Write-Host "    Output: $outputFile" -ForegroundColor Gray
            }
            return $true
        }
    }

    Write-Host "    WARNING: Could not read log file" -ForegroundColor Yellow
    return $false
}

function Install-ToMT5 {
    param([string]$MT5Path, [string]$EABuildDir, [string]$IndicatorBuildDir)

    # MT5 stores user data in AppData, not Program Files
    # Find the MQL5 folder in AppData\Roaming\MetaQuotes\Terminal\<ID>\
    $mt5DataPath = $null
    $terminalPath = "$env:APPDATA\MetaQuotes\Terminal"

    if (Test-Path $terminalPath) {
        # Find first terminal folder with MQL5 subdirectory
        $terminals = Get-ChildItem -Path $terminalPath -Directory -ErrorAction SilentlyContinue
        foreach ($terminal in $terminals) {
            $mql5Path = Join-Path $terminal.FullName "MQL5"
            if (Test-Path $mql5Path) {
                $mt5DataPath = $mql5Path
                break
            }
        }
    }

    if (-not $mt5DataPath) {
        Write-Host "  WARNING: MT5 data folder not found in $terminalPath" -ForegroundColor Yellow
        return 0
    }

    $mt5ExpertsDir = Join-Path $mt5DataPath "Experts"
    $mt5IndicatorsDir = Join-Path $mt5DataPath "Indicators"

    Write-Host "  MT5 Data: $mt5DataPath" -ForegroundColor Gray

    if (-not (Test-Path $mt5ExpertsDir)) {
        Write-Host "  WARNING: MT5 Experts folder not found: $mt5ExpertsDir" -ForegroundColor Yellow
        return 0
    }
    if (-not (Test-Path $mt5IndicatorsDir)) {
        Write-Host "  WARNING: MT5 Indicators folder not found: $mt5IndicatorsDir" -ForegroundColor Yellow
        return 0
    }

    $installedCount = 0

    # Install EAs
    $eaFiles = Get-ChildItem -Path $EABuildDir -Filter "*.ex5" -ErrorAction SilentlyContinue
    foreach ($file in $eaFiles) {
        $destPath = Join-Path $mt5ExpertsDir $file.Name
        $shouldCopy = $true
        if (Test-Path $destPath) {
            Write-Host "  File exists: $($file.Name)" -ForegroundColor Yellow
            $response = Read-Host "    Overwrite? (y/N)"
            $shouldCopy = ($response -eq 'y' -or $response -eq 'Y')
            if (-not $shouldCopy) { Write-Host "    Skipped." -ForegroundColor Gray }
        }
        if ($shouldCopy) {
            Copy-Item $file.FullName $destPath -Force
            Write-Host "  Installed EA: $($file.Name) -> $mt5ExpertsDir" -ForegroundColor Green
            $installedCount++
        }
    }

    # Install Indicators
    $indFiles = Get-ChildItem -Path $IndicatorBuildDir -Filter "*.ex5" -ErrorAction SilentlyContinue
    foreach ($file in $indFiles) {
        $destPath = Join-Path $mt5IndicatorsDir $file.Name
        $shouldCopy = $true
        if (Test-Path $destPath) {
            Write-Host "  File exists: $($file.Name)" -ForegroundColor Yellow
            $response = Read-Host "    Overwrite? (y/N)"
            $shouldCopy = ($response -eq 'y' -or $response -eq 'Y')
            if (-not $shouldCopy) { Write-Host "    Skipped." -ForegroundColor Gray }
        }
        if ($shouldCopy) {
            Copy-Item $file.FullName $destPath -Force
            Write-Host "  Installed Indicator: $($file.Name) -> $mt5IndicatorsDir" -ForegroundColor Green
            $installedCount++
        }
    }

    return $installedCount
}

# ============== MAIN ==============

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   MetaTrader 5 Build Script (Windows)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Find MetaEditor
$MetaEditor = Find-MetaEditor
if (-not $MetaEditor) {
    Write-Host "ERROR: MetaEditor64.exe not found!" -ForegroundColor Red
    Write-Host "Please install MetaTrader 5 or set METAEDITOR_PATH environment variable." -ForegroundColor Yellow
    exit 1
}

$MT5Path = Split-Path $MetaEditor -Parent
Write-Host "MetaEditor: $MetaEditor" -ForegroundColor Gray
Write-Host ""

# Initialize directories
Initialize-Directories

$totalErrors = 0
$totalSuccess = 0

# Compile Expert Advisors
Write-Host "[Expert Advisors]" -ForegroundColor Yellow
$eaFiles = Get-ChildItem -Path $EASourceDir -Filter "*.mq5" -ErrorAction SilentlyContinue
if ($eaFiles) {
    foreach ($file in $eaFiles) {
        $logFile = Join-Path $LogsDir "ea_$($file.BaseName).log"
        $result = Compile-MQ5 -SourceFile $file.FullName -OutputDir $EABuildDir -LogFile $logFile -MetaEditor $MetaEditor
        if ($result) { $totalSuccess++ } else { $totalErrors++ }
    }
} else {
    Write-Host "  No EA files found." -ForegroundColor Gray
}

Write-Host ""

# Compile Indicators
Write-Host "[Indicators]" -ForegroundColor Yellow
$indicatorFiles = Get-ChildItem -Path $IndicatorSourceDir -Filter "*.mq5" -ErrorAction SilentlyContinue
if ($indicatorFiles) {
    foreach ($file in $indicatorFiles) {
        $logFile = Join-Path $LogsDir "indicator_$($file.BaseName).log"
        $result = Compile-MQ5 -SourceFile $file.FullName -OutputDir $IndicatorBuildDir -LogFile $logFile -MetaEditor $MetaEditor
        if ($result) { $totalSuccess++ } else { $totalErrors++ }
    }
} else {
    Write-Host "  No Indicator files found." -ForegroundColor Gray
}

# Install to MT5 if requested
if ($Install -and $totalErrors -eq 0 -and $totalSuccess -gt 0) {
    Write-Host ""
    Write-Host "[Installing to MetaTrader 5]" -ForegroundColor Yellow
    $installedCount = Install-ToMT5 -MT5Path $MT5Path -EABuildDir $EABuildDir -IndicatorBuildDir $IndicatorBuildDir
    Write-Host "  Total installed: $installedCount file(s)" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Build Summary:" -ForegroundColor Cyan
Write-Host "  Success: $totalSuccess" -ForegroundColor Green
Write-Host "  Failed:  $totalErrors" -ForegroundColor $(if ($totalErrors -gt 0) { "Red" } else { "Gray" })
Write-Host "  Logs:    $LogsDir" -ForegroundColor Gray
Write-Host "  Output:  $BuildDir" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($totalErrors -gt 0) {
    exit 1
}
exit 0
