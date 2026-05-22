#Requires -Version 5.1
<#
.SYNOPSIS
    Risk Language Compiler — Windows Setup
.DESCRIPTION
    - Installs MinGW-w64 GCC (winlibs build) if gcc is not already on PATH
    - Adds GCC to the system PATH permanently
    - Sets the HOME environment variable for the current user (needed by riskc)
    - Creates %USERPROFILE%\.risk\lib\ for the standard library
    - Broadcasts the environment change so new terminals pick it up immediately

.PARAMETER InstallDir
    Where to extract GCC. Default: C:\mingw64

.PARAMETER RiskStdlibDir
    Where to create the Risk standard-library directory.
    Default: %USERPROFILE%\.risk\lib

.PARAMETER SkipGcc
    Pass this switch if you already have GCC and only want the env/PATH setup.
#>
param(
    [string] $InstallDir    = "C:\mingw64",
    [string] $RiskStdlibDir = "$env:USERPROFILE\.risk\lib",
    [switch] $SkipGcc
)

$ErrorActionPreference = "Stop"

function Write-Step { param($m) Write-Host "  >> $m" -ForegroundColor Cyan    }
function Write-OK   { param($m) Write-Host "  OK $m" -ForegroundColor Green   }
function Write-Warn { param($m) Write-Host "WARN $m" -ForegroundColor Yellow  }
function Write-Fail { param($m) Write-Host "FAIL $m" -ForegroundColor Red     }

function Show-Banner {
    Write-Host ""
    Write-Host "  ██████╗ ██╗███████╗██╗  ██╗     ██████╗ ██████╗ ███╗   ███╗██████╗ " -ForegroundColor Magenta
    Write-Host "  ██╔══██╗██║██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗████╗ ████║██╔══██╗" -ForegroundColor Magenta
    Write-Host "  ██████╔╝██║███████╗█████╔╝     ██║     ██║   ██║██╔████╔██║██████╔╝" -ForegroundColor Magenta
    Write-Host "  ██╔══██╗██║╚════██║██╔═██╗     ██║     ██║   ██║██║╚██╔╝██║██╔═══╝ " -ForegroundColor Magenta
    Write-Host "  ██║  ██║██║███████║██║  ██╗    ╚██████╗╚██████╔╝██║ ╚═╝ ██║██║     " -ForegroundColor Magenta
    Write-Host "  ╚═╝  ╚═╝╚═╝╚══════╝╚═╝  ╚═╝     ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚═╝     " -ForegroundColor Magenta
    Write-Host ""
    Write-Host "              Windows Setup — Risk Language Compiler" -ForegroundColor White
    Write-Host ""
}

$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin   = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "`nAdministrator rights are required to modify the system PATH." -ForegroundColor Yellow
    Write-Host "Relaunching as Administrator...`n" -ForegroundColor Yellow
    $myArgs = "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" `
            + " -InstallDir `"$InstallDir`"" `
            + " -RiskStdlibDir `"$RiskStdlibDir`""
    if ($SkipGcc) { $myArgs += " -SkipGcc" }
    Start-Process PowerShell -Verb RunAs -ArgumentList $myArgs
    exit 0
}

Show-Banner

if ($SkipGcc) {
    Write-Step "Skipping GCC installation (-SkipGcc was passed)."
} else {
    Write-Step "Checking for an existing GCC installation..."
    $existingGcc = Get-Command gcc -ErrorAction SilentlyContinue

    if ($existingGcc) {
        $ver = (& gcc --version 2>&1 | Select-Object -First 1).ToString().Trim()
        Write-OK "GCC already on PATH: $ver"
        Write-OK "Skipping download."
    } else {
        Write-Step "GCC not found — downloading MinGW-w64 (winlibs, POSIX threads, SEH, UCRT)..."

        $zipUrl  = $null
        $zipName = $null

        try {
            $apiUrl  = "https://api.github.com/repos/brechtsanders/winlibs_mingw/releases/latest"
            $headers = @{ "User-Agent" = "risk-lang-installer/1.0" }
            $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers -TimeoutSec 20

            $asset = $release.assets | Where-Object {
                $_.name -match "x86_64"  -and
                $_.name -match "posix"   -and
                $_.name -match "seh"     -and
                $_.name -match "ucrt"    -and
                $_.name -match "\.zip$"
            } | Select-Object -First 1

            if ($asset) {
                $zipUrl  = $asset.browser_download_url
                $zipName = $asset.name
                Write-Step "Latest release found: $zipName"
            }
        } catch {
            Write-Warn "GitHub API unreachable ($_). Falling back to known stable release."
        }

        if (-not $zipUrl) {
            $zipName = "winlibs-x86_64-posix-seh-gcc-14.2.0-mingw-w64ucrt-12.0.0-r1.zip"
            $zipUrl  = "https://github.com/brechtsanders/winlibs_mingw/releases/download/" +
                       "14.2.0posix-18.1.8-12.0.0-ucrt-r1/$zipName"
        }

        $tmpZip = Join-Path $env:TEMP $zipName
        Write-Step "Downloading: $zipName"

        $downloaded = $false
        try {
            Import-Module BitsTransfer -ErrorAction Stop
            Start-BitsTransfer -Source $zipUrl -Destination $tmpZip `
                               -DisplayName "Risk Setup: Downloading GCC" `
                               -Description $zipName
            $downloaded = $true
        } catch {}

        if (-not $downloaded) {
            try {
                $wc = New-Object System.Net.WebClient
                $wc.Headers.Add("User-Agent", "risk-lang-installer/1.0")

                $wc.DownloadProgressChanged += {
                    param($s, $e)
                    Write-Progress -Activity "Downloading GCC" `
                                   -Status "$($e.ProgressPercentage)% complete" `
                                   -PercentComplete $e.ProgressPercentage
                }
                $wc.DownloadFileTaskAsync($zipUrl, $tmpZip).Wait()
                Write-Progress -Activity "Downloading GCC" -Completed
                $downloaded = $true
            } catch {}
        }

        if (-not $downloaded) {
            Write-Fail "Download failed. Please install GCC manually:"
            Write-Host ""
            Write-Host "  1. Visit https://winlibs.com/" -ForegroundColor Yellow
            Write-Host "  2. Download the x86_64 POSIX SEH UCRT .zip" -ForegroundColor Yellow
            Write-Host "  3. Extract it to $InstallDir" -ForegroundColor Yellow
            Write-Host "  4. Re-run this script with  -SkipGcc" -ForegroundColor Yellow
            Write-Host ""
            exit 1
        }

        Write-OK "Download complete."

        Write-Step "Extracting to $(Split-Path $InstallDir -Parent) ..."

        if (Test-Path $InstallDir) {
            Write-Warn "Removing old installation at $InstallDir"
            Remove-Item $InstallDir -Recurse -Force
        }

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        try {
            [System.IO.Compression.ZipFile]::ExtractToDirectory(
                $tmpZip,
                (Split-Path $InstallDir -Parent)
            )
        } catch {
            Write-Fail "Extraction failed: $_"
            exit 1
        }

        $extracted = Join-Path (Split-Path $InstallDir -Parent) "mingw64"
        if ((Test-Path $extracted) -and ($extracted -ne $InstallDir)) {
            Write-Step "Renaming mingw64 -> $InstallDir"
            Rename-Item $extracted (Split-Path $InstallDir -Leaf) -ErrorAction SilentlyContinue
        }

        Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue
        Write-OK "GCC extracted to $InstallDir"
    }
}

$gccBin  = Join-Path $InstallDir "bin"
$regSys  = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment"

Write-Step "Updating system PATH..."

if (Test-Path $gccBin) {
    $sysPath = (Get-ItemProperty $regSys -Name Path).Path

    if ($sysPath -notlike "*$gccBin*") {
        $newPath = $sysPath.TrimEnd(';') + ";$gccBin"
        Set-ItemProperty $regSys -Name Path -Value $newPath
        Write-OK "Added to system PATH: $gccBin"
    } else {
        Write-OK "GCC bin already present in system PATH."
    }

    $env:PATH = $env:PATH.TrimEnd(';') + ";$gccBin"
} else {
    Write-Warn "$gccBin not found — PATH not updated. Did the extraction succeed?"
}

Write-Step "Checking HOME environment variable..."
$regUser    = "HKCU:\Environment"
$existHome  = (Get-ItemProperty $regUser -Name HOME -ErrorAction SilentlyContinue).HOME

if (-not $existHome -or $existHome -eq '') {
    Set-ItemProperty $regUser -Name HOME -Value $env:USERPROFILE
    $env:HOME = $env:USERPROFILE
    Write-OK "HOME set to $env:USERPROFILE"
} else {
    Write-OK "HOME is already set to $existHome"
}

Write-Step "Creating Risk standard-library directory..."

if (-not (Test-Path $RiskStdlibDir)) {
    New-Item -ItemType Directory -Path $RiskStdlibDir -Force | Out-Null
    Write-OK "Created: $RiskStdlibDir"
} else {
    Write-OK "Already exists: $RiskStdlibDir"
}

Write-Step "Verifying GCC..."
$gccExe = Join-Path $gccBin "gcc.exe"

if (Test-Path $gccExe) {
    try {
        $ver = (& $gccExe --version 2>&1 | Select-Object -First 1).ToString().Trim()
        Write-OK "$ver"
    } catch {
        Write-Warn "Could not run gcc --version. Try opening a new terminal."
    }
} else {
    Write-Warn "gcc.exe not found at $gccExe"
}

Write-Step "Broadcasting environment changes to the system..."
try {
    $memberDef = @'
[DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(
    IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam,
    uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
'@
    $u      = Add-Type -MemberDefinition $memberDef -Name NativeMethods `
                       -Namespace Win32 -PassThru -ErrorAction SilentlyContinue
    $result = [UIntPtr]::Zero
    $null   = $u::SendMessageTimeout(
                  [IntPtr]0xFFFF, 0x001A, [UIntPtr]::Zero,
                  "Environment", 2, 5000, [ref]$result)
    Write-OK "Broadcast sent."
} catch {
    Write-Warn "Could not broadcast (non-critical): $_"
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║              Setup completed successfully!               ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  GCC location  : $gccBin"         -ForegroundColor White
Write-Host "  HOME          : $env:USERPROFILE" -ForegroundColor White
Write-Host "  Risk stdlib   : $RiskStdlibDir"   -ForegroundColor White
Write-Host ""
Write-Host "  !! Open a NEW terminal window for PATH changes to take effect. !!" `
           -ForegroundColor Yellow
Write-Host ""
Write-Host "  You can now compile Risk programs with:" -ForegroundColor Cyan
Write-Host "    riskc main.risk -o myprogram"          -ForegroundColor Cyan
Write-Host ""
