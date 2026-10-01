# Builds the x64 or ARM64 installer of the Pyre909 build with the official installer script
# (PowerEditor/installer/nppSetup.nsi). The script takes its files from the release build folders bin64 (x64) or
# binarm64 (ARM64) and bin: this stages there the built exe, the plugins and updater of the official portable zip
# (unpacked by package.ps1 in <OutDir>/official.<arch>), and the Explorer context menu (NppShell) and updater
# translations of the official installer of the same release and architecture.
# Needs NSIS (makensis) and 7-Zip. Run after package.ps1, with the same -OutDir and -Arch.
#
# Usage: installer.ps1 -Exe <notepad++.exe> -OutDir <dir> [-Arch x64|arm64] [-Commit <sha>]
#                      [-OfficialInstaller <npp.x.y.z.Installer.<arch>.exe>] [-MakeNsis <makensis>] [-SevenZip <7z>]
# Writes <OutDir>/<name>.exe and <name>.exe.sha256, and adds a line to <OutDir>/notes.md.

param(
	[Parameter(Mandatory)] [string] $Exe,
	[Parameter(Mandatory)] [string] $OutDir,
	[ValidateSet('x64', 'arm64')] [string] $Arch = 'x64',
	[string] $Commit = '',
	[string] $OfficialInstaller = '',
	[string] $MakeNsis = 'makensis',
	[string] $SevenZip = '7z'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
$editor = Join-Path $root 'PowerEditor'
$installerDir = Join-Path $editor 'installer'
$OutDir = (Resolve-Path $OutDir).Path
$official = Join-Path $OutDir "official.$Arch"
$officialTagFile = Join-Path $OutDir "official-tag.$Arch.txt"
$officialTag = if (Test-Path $officialTagFile) { "$(Get-Content $officialTagFile -Raw)".Trim() } else { '' }
if (-not $officialTag) { throw "no official release in ${officialTagFile}: run package.ps1 first, with the same -OutDir and -Arch" }

$resource = Get-Content (Join-Path $editor 'src' 'resource.h') -Raw
$version = [regex]::Match($resource, 'VERSION_PRODUCT_VALUE L"([0-9.]+)').Groups[1].Value
if (-not $version) { throw 'VERSION_PRODUCT_VALUE not found in resource.h' }
$short = if ($Commit) { $Commit.Substring(0, [Math]::Min(7, $Commit.Length)) } else { 'local' }
$name = "npp.$version.pyre-$short.Installer.$Arch"
$archName, $binArchName, $nsisArch = if ($Arch -eq 'arm64') { 'ARM64', 'binarm64', 'ARCHARM64' } else { 'x64', 'bin64', 'ARCH64' }

# the official installer of the release the plugins and updater come from, unpacked
if (-not $OfficialInstaller) {
	$OfficialInstaller = Join-Path $OutDir "official.Installer.$Arch.exe"
	$tagVersion = $officialTag.TrimStart('v')
	Invoke-WebRequest "https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/$officialTag/npp.$tagVersion.Installer.$Arch.exe" -OutFile $OfficialInstaller
}
$unpacked = Join-Path $OutDir "official-installer.$Arch"
if (Test-Path $unpacked) { Remove-Item -Recurse -Force $unpacked }
& $SevenZip x -y "-o$unpacked" $OfficialInstaller | Out-Null
if ($LastExitCode -ne 0) { throw "7-Zip could not unpack $OfficialInstaller" }
$contextMenu = Join-Path $unpacked 'contextMenu'
$gupLocalization = Join-Path $unpacked '$PLUGINSDIR' 'gupLocalization'
foreach ($required in (Join-Path $contextMenu 'NppShell.msix'), (Join-Path $contextMenu 'NppShell.dll'), $gupLocalization) {
	if (-not (Test-Path -LiteralPath $required)) { throw "the official installer has no $required" }
}

# the release build folders the installer script takes its files from
$binArch = Join-Path $editor $binArchName
$bin = Join-Path $editor 'bin'
$translations = Join-Path $bin 'updater' 'translations'
New-Item -ItemType Directory -Force $binArch, $translations | Out-Null
$exeTarget = Join-Path $binArch 'notepad++.exe'
if ((Resolve-Path $Exe).Path -ne $exeTarget) { Copy-Item $Exe $exeTarget -Force }
Copy-Item (Join-Path $official 'plugins'), (Join-Path $official 'updater') $binArch -Recurse -Force
Copy-Item -LiteralPath (Join-Path $contextMenu 'NppShell.msix') (Join-Path $binArch 'NppShell.msix') -Force
Copy-Item -LiteralPath (Join-Path $contextMenu 'NppShell.dll') (Join-Path $binArch "NppShell.$Arch.dll") -Force
Get-ChildItem -LiteralPath $gupLocalization -Filter '*.xml' | Copy-Item -Destination $translations -Force
Copy-Item (Join-Path $editor 'src' 'langs.model.xml'), (Join-Path $editor 'src' 'stylers.model.xml') $bin -Force

# the installer, unsigned (sign-installers.bat skips signing without the SIGN setting)
$build = Join-Path $installerDir 'build'
if (Test-Path $build) { Remove-Item -Recurse -Force $build }
New-Item -ItemType Directory $build | Out-Null
Push-Location $installerDir
try {
	& $MakeNsis -V2 "-D$nsisArch" nppSetup.nsi
	if ($LastExitCode -ne 0) { throw "makensis failed ($LastExitCode)" }
}
finally {
	Pop-Location
}
$built = @(Get-ChildItem -Path $build -Filter "npp.*.Installer.$Arch.exe")
if ($built.Count -ne 1) { throw "expected one installer in $build" }

$installer = Join-Path $OutDir "$name.exe"
Copy-Item $built[0].FullName $installer -Force
$hash = (Get-FileHash $installer -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  $name.exe" | Set-Content -Path "$installer.sha256" -Encoding ascii -NoNewline
$notes = Join-Path $OutDir 'notes.md'
$note = "- ``$name.exe``: $archName installer: installs like official Notepad++, over an official installation (same folder and settings). Plugins, updater and Explorer menu from official Notepad++ $officialTag."
if (-not ((Get-Content $notes -ErrorAction SilentlyContinue) -contains $note)) { Add-Content -Path $notes -Value $note -Encoding utf8 }
"$name.exe: $((Get-Item $installer).Length) bytes, sha256 $hash"
