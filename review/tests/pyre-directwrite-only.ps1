# App-level test (review harness), Pyre909 builds only: DirectWrite the only rendering mode Preferences > Editing 1
# offers (2026-11-10). Fresh settings: the four DirectWrite modes, DirectWrite (default) chosen, the views in DirectWrite.
# A config.xml with GDI (writeTechnologyEngine="0", an older one): GDI listed first and chosen, the views in GDI; choosing
# DirectWrite switches them at once. config.xml's offerGdiRendering="yes" (written by hand): GDI listed with DirectWrite
# chosen, and kept in config.xml when Notepad++ saves it.
# Contract of review\tests: -Exe <notepad++.exe>; PASS/FAIL lines; last line "<n> checks, <m> failed".
param([Parameter(Mandatory)] [string] $Exe)
$ErrorActionPreference = 'Stop'
if (-not [Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($Exe)).Contains('Pyre909 build')) {
	'INFO  not a Pyre909 build: skipped'; '0 checks, 0 failed'; exit
}
Add-Type -TypeDefinition @'
using System; using System.Text; using System.Runtime.InteropServices;
public static class DO {
	public delegate bool EnumProc(IntPtr h, IntPtr l);
	[DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
	[DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EnumProc f, IntPtr l);
	[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
	[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
	[DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h, int id);
	[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
	[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
	[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, StringBuilder l);
	[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
	[DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
}
'@
$WM_CLOSE = 0x0010; $WM_COMMAND = 0x0111; $CB_GETCOUNT = 0x0146; $CB_GETCURSEL = 0x0147; $CB_SETCURSEL = 0x014E; $CB_GETLBTEXT = 0x0148
$IDC_COMBO_SC_TECHNOLOGY_CHOICE = 6362; $IDM_SETTING_PREFERENCE = 48011; $SCI_GETTECHNOLOGY = 2631

$script:results = [Collections.Generic.List[string]]::new(); $script:fails = 0
function Check([string] $name, [bool] $ok, [string] $detail = '') {
	if (-not $ok) { $script:fails++ }
	$script:results.Add(("{0}  {1}{2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $(if ($detail) { "  [$detail]" } else { '' })))
}
function Get-Cls([IntPtr] $h) { $sb = [Text.StringBuilder]::new(64); [void][DO]::GetClassName($h, $sb, 64); $sb.ToString() }
function Get-Tops {
	$script:acc = [Collections.Generic.List[IntPtr]]::new()
	[void][DO]::EnumWindows({ param($h, $l) $p = 0; [void][DO]::GetWindowThreadProcessId($h, [ref]$p); if ($p -eq $script:npid) { $script:acc.Add($h) }; $true }, [IntPtr]::Zero)
	$script:acc.ToArray()
}
function Get-Kids([IntPtr] $parent) {
	$script:kids = [Collections.Generic.List[IntPtr]]::new()
	[void][DO]::EnumChildWindows($parent, { param($h, $l) $script:kids.Add($h); $true }, [IntPtr]::Zero)
	$script:kids.ToArray()
}
function Send([IntPtr] $h, [int] $msg, [long] $w = 0, [long] $l = 0) { $r = [IntPtr]::Zero; [void][DO]::SendMessageTimeout($h, $msg, [IntPtr]$w, [IntPtr]$l, 2, 5000, [ref]$r); $r.ToInt64() }

$root = Join-Path ([IO.Path]::GetTempPath()) ('npp-review\pyre-directwrite-only-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
# starts Notepad++ with a settings folder of its own, its config.xml's MISC attributes as given (none: no config.xml)
function Start-Npp([string] $name, [string] $miscAttributes) {
	$script:settings = Join-Path $root $name; New-Item -ItemType Directory -Force $script:settings | Out-Null
	if ($miscAttributes) {
		[IO.File]::WriteAllText((Join-Path $script:settings 'config.xml'), "<?xml version=""1.0"" encoding=""UTF-8"" ?><NotepadPlus><GUIConfigs><GUIConfig name=""MISC"" $miscAttributes /></GUIConfigs></NotepadPlus>")
	}
	$script:proc = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$script:settings", '-titleAdd=REVIEW-TEST' -PassThru
	$script:npid = $script:proc.Id
	for ($i = 0; $i -lt 100; $i++) { $script:proc.Refresh(); if ($script:proc.MainWindowHandle -ne 0) { break }; Start-Sleep -Milliseconds 100 }
	$script:main = $script:proc.MainWindowHandle; Start-Sleep -Milliseconds 800
	$script:view = Get-Kids $script:main | Where-Object { (Get-Cls $_) -eq 'Scintilla' -and [DO]::IsWindowVisible($_) -and ([DO]::GetParent($_) -eq $script:main) } | Select-Object -First 1
	[void](Send $script:main $WM_COMMAND $IDM_SETTING_PREFERENCE)
	$script:page = $null
	for ($i = 0; $i -lt 50 -and -not $script:page; $i++) {
		Start-Sleep -Milliseconds 100
		foreach ($t in Get-Tops) { if ((Get-Cls $t) -eq '#32770') { $m = Get-Kids $t | Where-Object { [DO]::GetDlgItem($_, $IDC_COMBO_SC_TECHNOLOGY_CHOICE) -ne [IntPtr]::Zero } | Select-Object -First 1; if ($m) { $script:page = $m } } }
	}
	$script:combo = [DO]::GetDlgItem($script:page, $IDC_COMBO_SC_TECHNOLOGY_CHOICE)
}
function Stop-Npp {
	if (-not $script:proc.HasExited) { [void][DO]::PostMessage($script:main, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero); if (-not $script:proc.WaitForExit(10000)) { Stop-Process -Id $script:proc.Id -Force } }
}
function Get-Items {
	@(0..((Send $script:combo $CB_GETCOUNT) - 1) | ForEach-Object { $sb = [Text.StringBuilder]::new(128); [void][DO]::SendMessage($script:combo, $CB_GETLBTEXT, [IntPtr]$_, $sb); $sb.ToString() })
}

try {
	Start-Npp 'fresh' ''
	$items = Get-Items
	Check 'fresh settings: the four DirectWrite modes only, DirectWrite (default) chosen, the view in DirectWrite' ((($items -join '|') -eq 'DirectWrite (default)|DirectWrite (retain frames)|DirectWrite (draw to GDI DC)|DirectWrite (DirectX 11)') -and ((Send $script:combo $CB_GETCURSEL) -eq 0) -and ((Send $script:view $SCI_GETTECHNOLOGY) -eq 1)) "items '$($items -join "', '")'; chosen $(Send $script:combo $CB_GETCURSEL)"
	# the last item, DirectX 11 (SC_TECHNOLOGY_DIRECT_WRITE_1, 4), then the first again: the items map to their modes
	[void](Send $script:combo $CB_SETCURSEL 3); [void](Send $script:page $WM_COMMAND ((1 -shl 16) -bor $IDC_COMBO_SC_TECHNOLOGY_CHOICE) $script:combo.ToInt64()); Start-Sleep -Milliseconds 400
	$dx11 = Send $script:view $SCI_GETTECHNOLOGY
	[void](Send $script:combo $CB_SETCURSEL 0); [void](Send $script:page $WM_COMMAND ((1 -shl 16) -bor $IDC_COMBO_SC_TECHNOLOGY_CHOICE) $script:combo.ToInt64()); Start-Sleep -Milliseconds 400
	Check '  the list''s items map to their modes: DirectX 11 (technology 4), then DirectWrite (1)' (($dx11 -eq 4) -and ((Send $script:view $SCI_GETTECHNOLOGY) -eq 1)) "technology $dx11, then $(Send $script:view $SCI_GETTECHNOLOGY)"
	Stop-Npp

	Start-Npp 'gdi' 'writeTechnologyEngine="0"'
	$items = Get-Items
	Check 'an older config.xml with GDI: GDI listed first and chosen, the view in GDI' (($items.Count -eq 5) -and ($items[0] -like 'GDI*') -and ((Send $script:combo $CB_GETCURSEL) -eq 0) -and ((Send $script:view $SCI_GETTECHNOLOGY) -eq 0)) "items $($items.Count), chosen $(Send $script:combo $CB_GETCURSEL), technology $(Send $script:view $SCI_GETTECHNOLOGY)"
	[void](Send $script:combo $CB_SETCURSEL 1); [void](Send $script:page $WM_COMMAND ((1 -shl 16) -bor $IDC_COMBO_SC_TECHNOLOGY_CHOICE) $script:combo.ToInt64()); Start-Sleep -Milliseconds 400
	Check '  DirectWrite chosen: the view switched at once' ((Send $script:view $SCI_GETTECHNOLOGY) -eq 1) "technology $(Send $script:view $SCI_GETTECHNOLOGY)"
	Stop-Npp
	Check '  saved: writeTechnologyEngine="1"' ((Get-Content -LiteralPath (Join-Path $script:settings 'config.xml') -Raw) -match 'writeTechnologyEngine="1"')

	Start-Npp 'offered' 'offerGdiRendering="yes"'
	$items = Get-Items
	Check 'offerGdiRendering="yes": GDI listed, DirectWrite (default) chosen' (($items.Count -eq 5) -and ($items[0] -like 'GDI*') -and ((Send $script:combo $CB_GETCURSEL) -eq 1) -and ((Send $script:view $SCI_GETTECHNOLOGY) -eq 1)) "items $($items.Count), chosen $(Send $script:combo $CB_GETCURSEL)"
	Stop-Npp
	Check '  kept in config.xml when Notepad++ saves it' ((Get-Content -LiteralPath (Join-Path $script:settings 'config.xml') -Raw) -match 'offerGdiRendering="yes"')
}
finally {
	foreach ($q in @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $Exe -and $_.MainWindowTitle -match 'REVIEW-TEST' })) { Stop-Process -Id $q.Id -Force }
	$script:results
	"{0} checks, {1} failed" -f @($script:results | Where-Object { $_ -notmatch '^INFO' }).Count, $script:fails
}
