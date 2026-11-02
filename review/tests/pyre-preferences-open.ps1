# App-level test (review harness), Pyre909 builds only: Preferences opens faster with the same contents. The font name lists
# (General's dialog font, Print's header and footer) hold the whole font list: General's at once, Print's once the page is
# shown (filled then, not when Preferences opens), each with its font selected; the New Document page's languages are named
# from this instance's menu (getNameStrFromCmd: with a second instance in another UI language in front, the names are this
# one's, not the other's); the first opening's time is printed (INFO).
# Contract of review\tests: -Exe <notepad++.exe>; PASS/FAIL lines; last line "<n> checks, <m> failed".
param([Parameter(Mandatory)] [string] $Exe)
$ErrorActionPreference = 'Stop'
if (-not [Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($Exe)).Contains('Pyre909 build')) {
	'INFO  not a Pyre909 build: skipped'; '0 checks, 0 failed'; exit
}
Add-Type -Namespace PO -Name U -MemberDefinition @'
public delegate bool EnumProc(IntPtr h, IntPtr l);
[DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
[DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EnumProc f, IntPtr l);
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, System.Text.StringBuilder s, int n);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, System.Text.StringBuilder s, int n);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, System.Text.StringBuilder l);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, string l);
[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h, int id);
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
[DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
'@
$script:results = [Collections.Generic.List[string]]::new(); $script:fails = 0
function Check([string] $name, [bool] $ok, [string] $detail = '') {
	if (-not $ok) { $script:fails++ }
	$script:results.Add(("{0}  {1}{2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $(if ($detail) { "  [$detail]" } else { '' })))
}
function Send([IntPtr] $h, [int] $msg, [long] $w = 0, [long] $l = 0) { $r = [IntPtr]::Zero; [void][PO.U]::SendMessageTimeout($h, $msg, [IntPtr]$w, [IntPtr]$l, 2, 10000, [ref]$r); $r.ToInt64() }
function Get-Cls([IntPtr] $h) { $sb = [Text.StringBuilder]::new(64); [void][PO.U]::GetClassName($h, $sb, 64); $sb.ToString() }
function Get-Title([IntPtr] $h) { $sb = [Text.StringBuilder]::new(128); [void][PO.U]::GetWindowText($h, $sb, 128); $sb.ToString() }
function Get-Kids([IntPtr] $p) { $script:kids = [Collections.Generic.List[IntPtr]]::new(); [void][PO.U]::EnumChildWindows($p, { param($h, $l) $script:kids.Add($h); $true }, [IntPtr]::Zero); $script:kids.ToArray() }
function Get-Tops([uint32] $procId) { $script:tops = [Collections.Generic.List[IntPtr]]::new(); [void][PO.U]::EnumWindows({ param($h, $l) $q = 0; [void][PO.U]::GetWindowThreadProcessId($h, [ref]$q); if ($q -eq $procId) { $script:tops.Add($h) }; $true }, [IntPtr]::Zero); $script:tops.ToArray() }
# a combo box's items: their number, the selected one's text (CB_GETLBTEXT, marshalled across processes)
function Get-ComboText([IntPtr] $combo, [long] $index) { $len = Send $combo 0x0149 $index; if ($len -lt 0) { return '' }; $sb = [Text.StringBuilder]::new([int]$len + 1); [void][PO.U]::SendMessage($combo, 0x0148, [IntPtr]$index, $sb); $sb.ToString() }
function Get-Combo([IntPtr] $combo) { $n = Send $combo 0x0146; $sel = Send $combo 0x0147; [pscustomobject]@{ Count = $n; Selected = $(if ($sel -ge 0) { Get-ComboText $combo $sel } else { '(none)' }) } }
function Start-Npp([string] $settings) {
	$p = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$settings", '-titleAdd=REVIEW-TEST' -PassThru
	for ($i = 0; $i -lt 150 -and $p.MainWindowHandle -eq 0; $i++) { Start-Sleep -Milliseconds 100; $p.Refresh() }
	Start-Sleep -Milliseconds 2500
	$p
}
function Stop-Npp($p) { if (-not $p.HasExited) { [void][PO.U]::PostMessage($p.MainWindowHandle, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero); if (-not $p.WaitForExit(10000)) { Stop-Process -Id $p.Id -Force } } }
# Preferences of a process and its page (a child dialog holding control id)
function Open-Preferences($p) {
	$sw = [Diagnostics.Stopwatch]::StartNew()
	$r = [IntPtr]::Zero; [void][PO.U]::SendMessageTimeout($p.MainWindowHandle, 0x0111, [IntPtr]48011, [IntPtr]::Zero, 0, 30000, [ref]$r)
	$ms = $sw.Elapsed.TotalMilliseconds
	$d = Get-Tops ([uint32]$p.Id) | Where-Object { [PO.U]::IsWindowVisible($_) -and [PO.U]::GetDlgItem($_, 6002) -ne [IntPtr]::Zero } | Select-Object -First 1 # IDC_LIST_DLGTITLE
	[pscustomobject]@{ Dialog = $d; Ms = $ms }
}
function Get-Page([IntPtr] $prefs, [int] $controlId) { Get-Kids $prefs | Where-Object { (Get-Cls $_) -eq '#32770' -and [PO.U]::GetDlgItem($_, $controlId) -ne [IntPtr]::Zero } | Select-Object -First 1 }
function Show-Page([IntPtr] $prefs, [string] $name) {
	$list = [PO.U]::GetDlgItem($prefs, 6002)
	$i = [PO.U]::SendMessage($list, 0x01A2, [IntPtr](-1), $name).ToInt64(); [void](Send $list 0x0186 $i)
	[void](Send $prefs 0x0111 ((1 -shl 16) -bor 6002) $list.ToInt64()); Start-Sleep -Milliseconds 500
}
$root = Join-Path ([IO.Path]::GetTempPath()) ('npp-review\pyre-preferences-open-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
try {
	$settings = Join-Path $root 'english'; New-Item -ItemType Directory -Force $settings | Out-Null
	$p = Start-Npp $settings
	$open = Open-Preferences $p
	$script:results.Add(("INFO  Preferences' first opening: {0:N0} ms" -f $open.Ms))
	$prefs = $open.Dialog
	Check 'Preferences opened' ($prefs -ne $null)
	$general = Get-Page $prefs 7169 # IDC_COMBO_DIALOG_FONT_NAME
	$dialogFont = Get-Combo ([PO.U]::GetDlgItem($general, 7169))
	Check "General: the dialog font list filled, its font selected" (($dialogFont.Count -gt 50) -and ($dialogFont.Selected -ne '(none)')) "$($dialogFont.Count) fonts, '$($dialogFont.Selected)'"
	$print = Get-Page $prefs 6704 # IDC_COMBO_HFONTNAME
	$before = (Get-Combo ([PO.U]::GetDlgItem($print, 6704))).Count
	Check 'Print: its font lists not filled before the page is shown' ($before -eq 0) "$before items"
	Show-Page $prefs 'Print'
	$h = Get-Combo ([PO.U]::GetDlgItem($print, 6704)); $f = Get-Combo ([PO.U]::GetDlgItem($print, 6715)) # IDC_COMBO_FFONTNAME
	Check '  shown: both filled with the whole list, the font of config.xml selected (none: the empty first item)' (($h.Count -eq $dialogFont.Count) -and ($f.Count -eq $dialogFont.Count) -and ($h.Selected -eq '') -and ($f.Selected -eq '')) "header $($h.Count) '$($h.Selected)', footer $($f.Count) '$($f.Selected)'"
	Show-Page $prefs 'General'; Show-Page $prefs 'Print'
	$h2 = Get-Combo ([PO.U]::GetDlgItem($print, 6704))
	Check '  shown again: filled once' ($h2.Count -eq $dialogFont.Count) "$($h2.Count) items"
	Stop-Npp $p

	# two instances: this one with a translation of its Normal Text menu item (IDM_LANG_TEXT, the default language list's
	# first item), another one in English in front of it (FindWindow found that one first)
	$fr = Join-Path $root 'translated'; New-Item -ItemType Directory -Force $fr | Out-Null
	$frenchNormalText = 'Aucun (Texte normal)'
	Set-Content -LiteralPath (Join-Path $fr 'nativeLang.xml') -Encoding utf8 -Value @"
<?xml version="1.0" encoding="utf-8" ?>
<NotepadPlus><Native-Langue name="Test" filename="test.xml"><Menu><Main><Entries/><Commands><Item id="46016" name="$frenchNormalText"/></Commands></Main></Menu></Native-Langue></NotepadPlus>
"@
	$pFr = Start-Npp $fr
	$pEn = Start-Npp $settings
	[void][PO.U]::BringWindowToTop($pEn.MainWindowHandle); [void][PO.U]::SetForegroundWindow($pEn.MainWindowHandle); Start-Sleep -Milliseconds 500
	$prefsFr = (Open-Preferences $pFr).Dialog
	$newDoc = Get-Page $prefsFr 6412 # IDC_COMBO_DEFAULTLANG
	$first = Get-ComboText ([PO.U]::GetDlgItem($newDoc, 6412)) 0
	Check 'New Document, with an English instance in front: the default language list named from this (translated) instance''s menu' ($first -eq $frenchNormalText) "first item '$first', translated '$frenchNormalText'"
	Stop-Npp $pEn; Stop-Npp $pFr
}
finally {
	foreach ($q in @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $Exe -and $_.MainWindowTitle -match 'REVIEW-TEST' })) { Stop-Process -Id $q.Id -Force }
	$script:results
	"settings folders: $root"
	"{0} checks, {1} failed" -f @($script:results | Where-Object { $_ -notmatch '^INFO' }).Count, $script:fails
}
