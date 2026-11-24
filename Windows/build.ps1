# Galax-z for Windows: test, build, package. In PowerShell, from anywhere:
#
#   powershell -ExecutionPolicy Bypass -File Windows\build.ps1           test everything, then build Windows\build\Galax-z\ and a zip
#   ... -File Windows\build.ps1 -SkipTests                                 build only
#   ... -File Windows\build.ps1 -Run                                       and start it afterwards
#   ... -File Windows\build.ps1 -Public                                    the same to hand out (as the Mac's PUBLIC=1): no debug
#                                                                          information, no byline of yours, and no folder of yours in it
#
# With Inno Setup 6 on the computer (winget install --id JRSoftware.InnoSetup --exact) it also makes a setup program,
# Windows\build\Galax-z-<version>-windows-<arch>-setup.exe (Galax-z.iss). -Installer makes that a must.
#
# Everything it says also goes to Windows\build\report.txt: that file is what to send back when something fails.
# It needs the Swift toolchain for Windows and Visual Studio's C++ build tools (Windows\README.md says how to get both).
# It writes nothing to an OP-Z, and it does not run the app unless you say -Run.
param(
    [switch]$SkipTests,
    [switch]$Run,
    # To hand out: the programs carry no debug information (it names the folders they were built from), your git config's
    # galaxz.byline is left out, and any folder name of yours still in them fails the build instead of warning.
    [switch]$Public,
    # Fail when Inno Setup is not here, instead of leaving the setup program out.
    [switch]$Installer,
    # SwiftPM's build folder. Outside your user folder on purpose: build paths end up inside programs, and yours has your name in it.
    [string]$Scratch = "$env:SystemDrive\galaxz-build"
)

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$root = Split-Path -Parent $here
$out = Join-Path $here 'build'
New-Item -ItemType Directory -Force -Path $out | Out-Null
$report = Join-Path $out 'report.txt'
Set-Content -Path $report -Value "Galax-z for Windows: build report" -Encoding UTF8
$results = New-Object System.Collections.Generic.List[string]

function Say([string]$line) {
    Write-Host $line
    Add-Content -Path $report -Value $line -Encoding UTF8
}

function Finish([int]$code) {
    Say ''
    Say '== summary'
    foreach ($r in $results) { Say $r }
    Say ''
    Say "report: $report"
    exit $code
}

# A program, its output into the report, its exit code checked. Native programs write warnings to stderr: that is not a failure.
function Step([string]$what, [scriptblock]$cmd) {
    Say ''
    Say "== $what"
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $start = Get-Date
    # the report stays UTF-8 (Tee-Object would write UTF-16 into it)
    $w = New-Object IO.StreamWriter($report, $true, (New-Object Text.UTF8Encoding($false)))
    try { & $cmd 2>&1 | ForEach-Object { $l = "$_"; $w.WriteLine($l); $l } | Out-Host }
    finally { $w.Close() }
    $code = $LASTEXITCODE
    $ErrorActionPreference = $old
    $secs = [int]((Get-Date) - $start).TotalSeconds
    if ($code -ne 0) {
        $results.Add("FAILED  $what (exit $code, ${secs} s)")
        Finish 1
    }
    $results.Add("ok      $what (${secs} s)")
}

# --- what this computer is ---------------------------------------------------------------------------------------------
Say "date:     $((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')) UTC"
$os = Get-CimInstance Win32_OperatingSystem
Say "windows:  $($os.Caption) $($os.Version) ($env:PROCESSOR_ARCHITECTURE)"
Say "cpu:      $((Get-CimInstance Win32_Processor | Select-Object -First 1).Name), $([Environment]::ProcessorCount) threads"
Say "shell:    PowerShell $($PSVersionTable.PSVersion)"
if (Get-Command git -ErrorAction SilentlyContinue) {
    Push-Location $root
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $commit = (git rev-parse --short HEAD 2>$null); $dirty = (git status --porcelain 2>$null | Measure-Object).Count
    $crlf = (git config core.autocrlf 2>$null)
    $ErrorActionPreference = $old
    Pop-Location
    Say "source:   $commit, $dirty files changed since; core.autocrlf=$crlf"
}

# signed release files are JSON: a checkout that turned their line ends into CR LF breaks every signature
$signed = Join-Path $root 'Releases\galaxz-v13.galaxz'
if ((Test-Path $signed) -and ([IO.File]::ReadAllBytes($signed) -contains 13)) {
    Say ''
    Say 'This checkout changed line ends (git core.autocrlf): signed files no longer match their signatures.'
    Say 'Clone it again with:  git -c core.autocrlf=false clone <the repository>'
    $results.Add('FAILED  checkout has CR LF line ends')
    Finish 1
}

# --- the tools ---------------------------------------------------------------------------------------------------------
# A PowerShell opened before the toolchain was installed has neither its PATH nor its SDKROOT: take both from Windows' settings.
if (-not (Get-Command swift -ErrorAction SilentlyContinue)) {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}
if (-not $env:SDKROOT) { $env:SDKROOT = [Environment]::GetEnvironmentVariable('SDKROOT', 'User') }
if (-not $env:SDKROOT) { $env:SDKROOT = [Environment]::GetEnvironmentVariable('SDKROOT', 'Machine') }
if (-not (Get-Command swift -ErrorAction SilentlyContinue)) {
    Say ''
    Say 'No Swift here. In PowerShell (then open a new one):'
    Say '  winget install --id Microsoft.VisualStudio.2022.BuildTools --exact --force --custom "--add Microsoft.VisualStudio.Component.Windows11SDK.22621 --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.VC.Tools.ARM64"'
    Say '  winget install --id Swift.Toolchain --exact'
    $results.Add('FAILED  no Swift toolchain')
    Finish 1
}
Step 'swift --version' { swift --version }

# Swift links with Microsoft's link.exe, which is only on PATH in a Visual Studio developer shell: enter one here.
if (-not (Get-Command link.exe -ErrorAction SilentlyContinue)) {
    $vsInstaller = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer'
    $vswhere = Join-Path $vsInstaller 'vswhere.exe'
    $vs = if (Test-Path $vswhere) {
        & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null | Select-Object -First 1
    }
    $devShell = if ($vs) { Join-Path $vs 'Common7\Tools\Microsoft.VisualStudio.DevShell.dll' }
    if (-not $devShell -or -not (Test-Path $devShell)) {
        Say ''
        Say 'No Visual Studio C++ build tools here (Swift links with them). In PowerShell:'
        Say '  winget install --id Microsoft.VisualStudio.2022.BuildTools --exact --force --custom "--add Microsoft.VisualStudio.Component.Windows11SDK.22621 --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.VC.Tools.ARM64"'
        $results.Add('FAILED  no Visual Studio C++ build tools')
        Finish 1
    }
    $hostArch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'amd64' }
    $env:Path = "$env:Path;$vsInstaller"                                 # its own scripts call vswhere
    Import-Module $devShell
    Enter-VsDevShell -VsInstallPath $vs -SkipAutomaticLocation -DevCmdArguments "-arch=$hostArch -host_arch=$hostArch" | Out-Null
    if (-not (Get-Command link.exe -ErrorAction SilentlyContinue)) { $results.Add('FAILED  Visual Studio has no link.exe'); Finish 1 }
}
Say "linker:   $((Get-Command link.exe).Source)"

# Programs carry the folders they were built from (#file in messages, debug information): the source as "galaxz", Swift's own
# folders (in your user folder) as "swift".
$swiftHome = Join-Path $env:LOCALAPPDATA 'Programs\Swift'
$prefix = @('-Xswiftc', '-file-prefix-map', '-Xswiftc', "$root=galaxz", '-Xswiftc', '-debug-prefix-map', '-Xswiftc', "$root=galaxz",
            '-Xswiftc', '-debug-prefix-map', '-Xswiftc', "$swiftHome=swift", '-Xcc', "-ffile-prefix-map=$root=galaxz")

# --- tests: the shared packages and the Windows package, on this computer ----------------------------------------------
if (-not $SkipTests) {
    Step 'tests: GalaxzKit (formats, screens, firmware writer against a fake console, releases, inflate, ports)' {
        swift test --package-path (Join-Path $root 'Packages\GalaxzKit') --scratch-path (Join-Path $Scratch 'kit')
    }
    Step 'tests: the Windows package (dots, mouse, MIDI timing, the demo OP-Z)' {
        swift test --package-path $here --scratch-path (Join-Path $Scratch 'win')
    }
}

# --- the app -----------------------------------------------------------------------------------------------------------
Step 'build: Galax-z.exe and galaxz-ports.exe (release)' {
    swift build -c release --package-path $here --scratch-path (Join-Path $Scratch 'win') @prefix
}
$old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
$bin = (swift build -c release --package-path $here --scratch-path (Join-Path $Scratch 'win') --show-bin-path 2>$null | Select-Object -Last 1).Trim()
$ErrorActionPreference = $old
Say "built in: $bin"

# --- the package: the programs, their files, Swift's runtime ------------------------------------------------------------
$app = Join-Path $out 'Galax-z'
if (Test-Path $app) { Remove-Item -Recurse -Force $app }
New-Item -ItemType Directory -Force -Path $app | Out-Null
foreach ($f in @('Galax-z.exe', 'galaxz-ports.exe')) { Copy-Item (Join-Path $bin $f) $app }
# -Public: no debug information (it names Swift's folders, in your user folder), as PUBLIC=1 Tools/package-mac.sh strips its symbols
if ($Public) {
    $strip = Join-Path (Split-Path -Parent (Get-Command swift).Source) 'llvm-strip.exe'
    if (-not (Test-Path $strip)) { $results.Add('FAILED  no llvm-strip beside swift'); Finish 1 }
    Step 'strip: no debug information in the programs' { & $strip --strip-debug (Join-Path $app 'Galax-z.exe') (Join-Path $app 'galaxz-ports.exe') }
}
# SwiftPM's resource bundles: the engine list, the demo song, the Galax-z OS builds and records
# (Name.resources from SwiftPM's own build system, Name.bundle from Swift Build, Swift 6.3 on; the app looks for its own)
$bundles = @(Get-ChildItem -Path $bin -Directory | Where-Object { $_.Extension -in '.resources', '.bundle' })
if ($bundles.Count -eq 0) { Say "no resource bundles in $bin"; $results.Add('FAILED  no resource bundles to package'); Finish 1 }
$bundles | ForEach-Object { Copy-Item -Recurse $_.FullName $app }
Copy-Item (Join-Path $here 'Galax-z.ico') $app
foreach ($f in @('LICENSE', 'THIRD_PARTY.md', 'DISCLAIMER.md')) { Copy-Item (Join-Path $root $f) $app }
Copy-Item (Join-Path $here 'README.md') (Join-Path $app 'README.md')
# Who made this build, in Settings › Credits (GALAXZ_BYLINE on the Mac): yours from `git config galaxz.byline`, not in a -Public one
$byline = 'by Luis Tosado'
if (-not $Public -and (Get-Command git -ErrorAction SilentlyContinue)) {
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $mine = (git -C $root config galaxz.byline 2>$null)
    $ErrorActionPreference = $old
    if ($mine) { $byline = $mine }
}
[IO.File]::WriteAllText((Join-Path $app 'byline.txt'), $byline, (New-Object Text.UTF8Encoding($false)))

# Swift's runtime, from the folder of it on PATH (the installer puts it there)
$runtime = ($env:Path -split ';' | Where-Object { $_ -and (Test-Path (Join-Path $_ 'swiftCore.dll')) } | Select-Object -First 1)
if (-not $runtime) { Say 'Swift runtime (swiftCore.dll) not found on PATH'; $results.Add('FAILED  no Swift runtime to package'); Finish 1 }
Say "runtime:  $runtime"
Get-ChildItem -Path $runtime -Filter '*.dll' | ForEach-Object { Copy-Item $_.FullName $app }
# the C++ runtime Swift's needs, beside it, for a computer that has never had it
foreach ($f in @('vcruntime140.dll', 'vcruntime140_1.dll', 'msvcp140.dll')) {
    $p = Join-Path "$env:SystemRoot\System32" $f
    if (Test-Path $p) { Copy-Item $p $app }
}
$results.Add("ok      package: $((Get-ChildItem $app -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB -as [int]) MB in $app")

# --- privacy: programs carry the folders they were built in. Nothing of yours may be in what is handed out ----------------
$needles = @($env:USERPROFILE, $root) | Where-Object { $_ -and $_.Length -ge 6 }
if ($env:USERNAME -and $env:USERNAME.Length -ge 4) { $needles += "\$env:USERNAME\" }
$found = @()
foreach ($f in @('Galax-z.exe', 'galaxz-ports.exe')) {
    $bytes = [IO.File]::ReadAllBytes((Join-Path $app $f))
    $ascii = [Text.Encoding]::GetEncoding(28591).GetString($bytes)        # one char a byte
    $wide = [Text.Encoding]::Unicode.GetString($bytes)
    foreach ($n in $needles) {
        if ($ascii.IndexOf($n, [StringComparison]::OrdinalIgnoreCase) -ge 0 -or $wide.IndexOf($n, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
            $found += "$f contains '$n'"
        }
    }
}
if ($found.Count -gt 0) {
    foreach ($x in $found) { Say "PRIVATE: $x" }
    if ($Public) { $results.Add("FAILED  privacy: the programs name your folders ($($found.Count))"); Finish 1 }
    $results.Add("WARNING privacy: the programs name your folders ($($found.Count)): fine for you, not for handing out (-Public)")
} else {
    $results.Add('ok      privacy: no user name or home folder in the programs')
}

# the notices are in it, and no file of TE's (as Tools/package-mac.sh checks)
foreach ($f in @('THIRD_PARTY.md', 'LICENSE')) {
    if (-not (Test-Path (Join-Path $app $f))) { $results.Add("FAILED  $f is not in the package"); Finish 1 }
}
$te = @(Get-ChildItem -Path $app -Recurse -File | Where-Object { $_.Extension -in '.ldr', '.zfw' -or $_.Name -eq 'os.crc32' })
if ($te.Count -gt 0) { foreach ($f in $te) { Say "TE's: $($f.FullName)" }; $results.Add("FAILED  TE's files in the package"); Finish 1 }
$results.Add("ok      notices in, no file of TE's")

# --- the zip: Galax-z-<version>-windows-<arch>.zip to hand out (-Public), ...-mine.zip otherwise --------------------------
$arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }
$version = (Select-String -Path (Join-Path $root 'project.yml') -Pattern 'MARKETING_VERSION:\s*"?([^"\s]+)' | Select-Object -First 1).Matches.Groups[1].Value
$zip = Join-Path $out ("Galax-z-$version-windows-$arch" + $(if ($Public) { '' } else { '-mine' }) + '.zip')
if (Test-Path $zip) { Remove-Item -Force $zip }
Compress-Archive -Path $app -DestinationPath $zip
$hash = (Get-FileHash -Algorithm SHA256 $zip).Hash.ToLower()
$results.Add("ok      zip: $zip ($((Get-Item $zip).Length / 1MB -as [int]) MB), sha256 $hash")

# --- the setup program (Galax-z.iss): installs for the person, no administrator; Start menu, uninstaller -------------------
$iscc = @((Get-Command iscc.exe -ErrorAction SilentlyContinue).Source,
          "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
          "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
          "$env:ProgramFiles\Inno Setup 6\ISCC.exe") | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if ($iscc) {
    $setupName = "Galax-z-$version-windows-$arch-setup" + $(if ($Public) { '' } else { '-mine' })
    Step "setup: $setupName.exe (Inno Setup)" {
        & $iscc /Q "/DVersion=$version" "/DArch=$arch" "/DSource=$app" "/DOut=$out" "/DName=$setupName" (Join-Path $here 'Galax-z.iss')
    }
    $setup = Join-Path $out "$setupName.exe"
    $results.Add("ok      setup: $setup ($([math]::Round((Get-Item $setup).Length / 1MB)) MB), sha256 $((Get-FileHash -Algorithm SHA256 $setup).Hash.ToLower())")
} elseif ($Installer) {
    Say 'No Inno Setup here. In PowerShell:  winget install --id JRSoftware.InnoSetup --exact'
    $results.Add('FAILED  no Inno Setup for the setup program')
    Finish 1
} else {
    $results.Add('skipped setup program: no Inno Setup (winget install --id JRSoftware.InnoSetup --exact)')
}

if ($Run) { Start-Process (Join-Path $app 'Galax-z.exe') }
Finish 0
