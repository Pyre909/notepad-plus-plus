# App-level test (review harness), Pyre909 builds only: the Text Rendering antialiasing of config.xml (fontAntialiasing,
# Parameters.cpp readTextRenderingParams) and the smoothFont of the Notepad++ versions without it, sharing config.xml:
# smoothFont="yes" is ClearType, and a smoothFont that disagrees with fontAntialiasing was changed since by such a version,
# so it wins; without smoothFont (written by hand), fontAntialiasing. smoothFont is written as the antialiasing is ClearType
# or not, and the attributes of the former advanced overrides (fontGamma...) are dropped.
# Contract of review\tests: -Exe <notepad++.exe>; PASS/FAIL lines; last line "<n> checks, <m> failed".
param([Parameter(Mandatory)] [string] $Exe)
$ErrorActionPreference = 'Stop'
if (-not [Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($Exe)).Contains('Pyre909 build')) {
	'INFO  not a Pyre909 build: skipped'; '0 checks, 0 failed'; exit
}
Add-Type -Namespace TC -Name U -MemberDefinition @'
public delegate bool EnumProc(IntPtr h, IntPtr l);
[DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EnumProc f, IntPtr l);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, System.Text.StringBuilder s, int n);
[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
[DllImport("user32.dll")] public static extern bool SystemParametersInfo(uint action, uint param, out uint value, uint winIni);
'@
$SCI_GETFONTQUALITY = 2612; $SCI_GETTECHNOLOGY = 2631
$script:results = [Collections.Generic.List[string]]::new(); $script:fails = 0
function Check([string] $name, [bool] $ok, [string] $detail = '') {
	if (-not $ok) { $script:fails++ }
	$script:results.Add(("{0}  {1}{2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $(if ($detail) { "  [$detail]" } else { '' })))
}
function Send([IntPtr] $h, [int] $msg, [long] $w = 0, [long] $l = 0) { $r = [IntPtr]::Zero; [void][TC.U]::SendMessageTimeout($h, $msg, [IntPtr]$w, [IntPtr]$l, 2, 5000, [ref]$r); $r.ToInt64() }

# the quality "Follow Windows" gives with DirectWrite: smoothing off 1, Standard 2, ClearType 0 (see getWindowsFontQuality)
$smoothing = [uint32]0; [void][TC.U]::SystemParametersInfo(0x004A, 0, [ref]$smoothing, 0)
$type = [uint32]0; [void][TC.U]::SystemParametersInfo(0x200A, 0, [ref]$type, 0)
$followWindows = if (-not $smoothing) { 1 } elseif ($type -eq 1) { 2 } else { 0 }

$root = Join-Path ([IO.Path]::GetTempPath()) ('npp-review\pyre-text-rendering-config-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
# Notepad++ with a settings folder: the font quality of its main view (-1 if none), the config.xml it wrote on exit
function Invoke-Npp([string] $settings) {
	$proc = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$settings", '-titleAdd=REVIEW-TEST' -PassThru
	$quality = -1; $technology = -1
	try {
		for ($i = 0; $i -lt 100; $i++) { $proc.Refresh(); if ($proc.MainWindowHandle -ne 0) { break }; Start-Sleep -Milliseconds 100 }
		Start-Sleep -Milliseconds 800
		$script:kids = [Collections.Generic.List[IntPtr]]::new(); [void][TC.U]::EnumChildWindows($proc.MainWindowHandle, { param($h, $l) $script:kids.Add($h); $true }, [IntPtr]::Zero)
		$view = $script:kids | Where-Object { $sb = [Text.StringBuilder]::new(32); [void][TC.U]::GetClassName($_, $sb, 32); ($sb.ToString() -eq 'Scintilla') -and [TC.U]::IsWindowVisible($_) -and ([TC.U]::GetParent($_) -eq $proc.MainWindowHandle) } | Select-Object -First 1
		if ($view) { $quality = Send $view $SCI_GETFONTQUALITY; $technology = Send $view $SCI_GETTECHNOLOGY }
	}
	finally {
		if (-not $proc.HasExited) { [void][TC.U]::PostMessage($proc.MainWindowHandle, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero); if (-not $proc.WaitForExit(10000)) { Stop-Process -Id $proc.Id -Force } }
	}
	[pscustomobject]@{ Quality = $quality; Technology = $technology; Config = [IO.File]::ReadAllText((Join-Path $settings 'config.xml')) }
}
function Get-Attribute([string] $config, [string] $name) { if ($config -match "<GUIConfig name=`"ScintillaPrimaryView`"[^>]*?\s$name=`"([^`"]*)`"") { $Matches[1] } else { '(none)' } }

try {
	# a config.xml written by this build, as the base of the cases
	$base = Join-Path $root 'base'; New-Item -ItemType Directory -Force $base | Out-Null
	$baseConfig = (Invoke-Npp $base).Config
	Check 'a fresh config.xml: Follow Windows, smoothFont no' (((Get-Attribute $baseConfig 'fontAntialiasing') -eq '0') -and ((Get-Attribute $baseConfig 'smoothFont') -eq 'no'))

	$cases = @(
		@{ Name = 'ClearType, smoothFont yes: ClearType'; Antialiasing = '1'; Smooth = 'yes'; Quality = 3; Written = '1'; WrittenSmooth = 'yes' },
		@{ Name = 'ClearType, smoothFont turned off by another Notepad++: Follow Windows'; Antialiasing = '1'; Smooth = 'no'; Quality = $followWindows; Written = '0'; WrittenSmooth = 'no' },
		@{ Name = 'Grayscale, smoothFont no: Grayscale'; Antialiasing = '3'; Smooth = 'no'; Quality = 2; Written = '3'; WrittenSmooth = 'no' },
		@{ Name = 'no fontAntialiasing (config.xml of another Notepad++), smoothFont yes: ClearType'; Antialiasing = $null; Smooth = 'yes'; Quality = 3; Written = '1'; WrittenSmooth = 'yes' },
		@{ Name = 'ClearType, no smoothFont (written by hand): ClearType'; Antialiasing = '1'; Smooth = $null; Quality = 3; Written = '1'; WrittenSmooth = 'yes' }
	)
	$n = 0
	foreach ($case in $cases) {
		$settings = Join-Path $root ("case{0}" -f ++$n); New-Item -ItemType Directory -Force $settings | Out-Null
		$config = if ($null -eq $case.Smooth) { $baseConfig -replace '\s+smoothFont="[^"]*"', '' } else { $baseConfig -replace 'smoothFont="[^"]*"', "smoothFont=`"$($case.Smooth)`"" }
		$config = if ($null -eq $case.Antialiasing) { $config -replace '\s+fontAntialiasing="[^"]*"', '' } else { $config -replace 'fontAntialiasing="[^"]*"', "fontAntialiasing=`"$($case.Antialiasing)`"" }
		# the attributes of the former advanced overrides, dropped on save
		$config = $config -replace 'fontContrast="([^"]*)"', 'fontContrast="$1" fontGamma="1800" fontLightTextGamma="-1"'
		[IO.File]::WriteAllText((Join-Path $settings 'config.xml'), $config, [Text.UTF8Encoding]::new($false))
		$run = Invoke-Npp $settings
		Check $case.Name ($run.Quality -eq $case.Quality) "technology $($run.Technology), font quality $($run.Quality), expected $($case.Quality)"
		$written = "fontAntialiasing {0}, smoothFont {1}, fontGamma {2}" -f (Get-Attribute $run.Config 'fontAntialiasing'), (Get-Attribute $run.Config 'smoothFont'), (Get-Attribute $run.Config 'fontGamma')
		Check "  saved: fontAntialiasing $($case.Written), smoothFont $($case.WrittenSmooth), no override" (((Get-Attribute $run.Config 'fontAntialiasing') -eq $case.Written) -and ((Get-Attribute $run.Config 'smoothFont') -eq $case.WrittenSmooth) -and ($run.Config -notmatch 'fontGamma|fontLightTextGamma')) $written
	}
}
finally {
	$script:results
	"settings folders: $root"
	"{0} checks, {1} failed" -f $script:results.Count, $script:fails
}
