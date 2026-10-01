# Packages the Pyre909 build of Notepad++ as an x64 portable zip, in the layout of the official portable zip
# (see PowerEditor/installer/packageAll.bat): the files of this repository and the built notepad++.exe, plus the
# plugins and updater of the official portable zip of the same version (else of the latest release), which
# Plugins Admin needs. disableNppAutoUpdate.xml keeps the updater from replacing this build with an official one,
# doLocalConf.xml keeps the settings in the folder.
#
# Usage: package.ps1 -Exe <notepad++.exe> -OutDir <dir> [-Commit <sha>] [-OfficialZip <npp.x.y.z.portable.x64.zip>]
# Writes <OutDir>/<name>.zip, <name>.zip.sha256 and notes.md, and name / version / short to $GITHUB_OUTPUT if set.

param(
	[Parameter(Mandatory)] [string] $Exe,
	[Parameter(Mandatory)] [string] $OutDir,
	[string] $Commit = '',
	[string] $OfficialZip = ''
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
$src = Join-Path $root 'PowerEditor' 'src'
$bin = Join-Path $root 'PowerEditor' 'bin'
$installer = Join-Path $root 'PowerEditor' 'installer'

$resource = Get-Content (Join-Path $src 'resource.h') -Raw
$version = [regex]::Match($resource, 'VERSION_PRODUCT_VALUE L"([0-9.]+)').Groups[1].Value
if (-not $version) { throw 'VERSION_PRODUCT_VALUE not found in resource.h' }
$short = if ($Commit) { $Commit.Substring(0, [Math]::Min(7, $Commit.Length)) } else { 'local' }
$name = "npp.$version.pyre-$short.portable.x64"

New-Item -ItemType Directory -Force $OutDir | Out-Null
$OutDir = (Resolve-Path $OutDir).Path
$pkg = Join-Path $OutDir $name
if (Test-Path $pkg) { Remove-Item -Recurse -Force $pkg }
New-Item -ItemType Directory $pkg | Out-Null

function Copy-Files([string] $from, [string] $to) {
	$files = @(Get-ChildItem -Path $from -File)
	if ($files.Count -eq 0) { throw "no files: $from" }
	$dir = Join-Path $pkg $to
	New-Item -ItemType Directory -Force $dir | Out-Null
	$files | Copy-Item -Destination $dir
}

# the files of the official portable zip that this repository has
Copy-Item (Join-Path $root 'LICENSE') (Join-Path $pkg 'license.txt')
Copy-Item (Join-Path $bin 'readme.txt'), (Join-Path $bin 'change.log') $pkg
Copy-Item (Join-Path $src 'langs.model.xml'), (Join-Path $src 'stylers.model.xml'), (Join-Path $src 'tabContextMenu_example.xml'), (Join-Path $src 'toolbarButtonsConf_example.xml') $pkg
Copy-Item (Join-Path $installer 'xml4Config' 'doLocalConf.xml'), (Join-Path $installer 'xml4Config' 'disableNppAutoUpdate.xml') $pkg
Copy-Item $Exe (Join-Path $pkg 'notepad++.exe')
Copy-Files (Join-Path $installer 'nativeLang' '*.xml') 'localization'
Copy-Files (Join-Path $installer 'APIs' '*.xml') 'autoCompletion'
Copy-Files (Join-Path $installer 'functionList' '*.xml') 'functionList'
Copy-Files (Join-Path $installer 'themes' '*.xml') 'themes'
Copy-Files (Join-Path $bin 'userDefineLangs' 'markdown._preinstalled*.udl.xml') 'userDefineLangs'

# the plugins and updater of the official portable zip
$headers = @{}
if ($env:GH_TOKEN) { $headers['Authorization'] = "Bearer $env:GH_TOKEN" }
$officialFrom = "v$version"
if (-not $OfficialZip) {
	$OfficialZip = Join-Path $OutDir 'official.portable.x64.zip'
	$releases = 'https://github.com/notepad-plus-plus/notepad-plus-plus/releases'
	try {
		Invoke-WebRequest "$releases/download/v$version/npp.$version.portable.x64.zip" -OutFile $OfficialZip
	}
	catch {
		# a version not released yet: the latest release
		$latest = Invoke-RestMethod 'https://api.github.com/repos/notepad-plus-plus/notepad-plus-plus/releases/latest' -Headers $headers
		$asset = $latest.assets | Where-Object name -Match '^npp\.[0-9.]+\.portable\.x64\.zip$' | Select-Object -First 1
		if (-not $asset) { throw "no x64 portable zip in the latest release $($latest.tag_name)" }
		Invoke-WebRequest $asset.browser_download_url -OutFile $OfficialZip
		$officialFrom = $latest.tag_name
	}
}
$official = Join-Path $OutDir 'official'
if (Test-Path $official) { Remove-Item -Recurse -Force $official }
Expand-Archive $OfficialZip -DestinationPath $official
foreach ($required in 'plugins/Config/nppPluginList.dll', 'updater/GUP.exe') {
	if (-not (Test-Path (Join-Path $official $required))) { throw "the official portable zip has no $required" }
}
Copy-Item (Join-Path $official 'plugins'), (Join-Path $official 'updater') $pkg -Recurse

# about this build
$repo = if ($env:GITHUB_REPOSITORY) { "$env:GITHUB_SERVER_URL/$env:GITHUB_REPOSITORY" } else { 'https://github.com/Pyre909/notepad-plus-plus' }
$commitLink = if ($Commit) { "$repo/commit/$Commit" } else { '(local build)' }
@"
Notepad++ $version, Pyre909 build: an unofficial build of Notepad++.
Source: $commitLink (branch pyre of $repo)
Plugins and updater: from the official Notepad++ $officialFrom portable zip.

This is a portable copy: its settings are kept in this folder (doLocalConf.xml).
Auto-update is off (disableNppAutoUpdate.xml), so the official updater won't replace this build;
Plugins Admin still works. To update, unzip a newer build over this folder: your settings
(config.xml, stylers.xml, shortcuts.xml, session.xml...) aren't in the zip and are kept.
"@ | Set-Content -Path (Join-Path $pkg 'PYRE-BUILD.txt') -Encoding utf8

@"
Notepad++ $version, Pyre909 build (x64, portable).

- Source: $commitLink
- Plugins and updater from the official Notepad++ $officialFrom portable zip
- Auto-update off; settings kept in the folder (see PYRE-BUILD.txt in the zip)
"@ | Set-Content -Path (Join-Path $OutDir 'notes.md') -Encoding utf8

$zip = Join-Path $OutDir "$name.zip"
if (Test-Path $zip) { Remove-Item -Force $zip }
Compress-Archive -Path (Join-Path $pkg '*') -DestinationPath $zip -CompressionLevel Optimal
$hash = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  $name.zip" | Set-Content -Path "$zip.sha256" -Encoding ascii -NoNewline

Get-ChildItem -Path $pkg -Recurse -File | ForEach-Object { '{0,10}  {1}' -f $_.Length, $_.FullName.Substring($pkg.Length + 1) }
"$name.zip: $((Get-Item $zip).Length) bytes, sha256 $hash"

if ($env:GITHUB_OUTPUT) {
	"name=$name", "version=$version", "short=$short" | Add-Content -Path $env:GITHUB_OUTPUT
}
