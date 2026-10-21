# App-level test (review harness), Pyre909 builds only: Preferences > Editing 1 > Line Wrap > "Per document"
# (config.xml wrapPerDocument). Off (the default): View > Word wrap is one wrap for all documents, as upstream. On: it wraps
# the current document only and each keeps its own (the menu check and toolbar follow the document shown); a document
# opened or created takes the last choice, toggling another one later not changing it; a large file opens unwrapped without unwrapping the others; the
# session keeps each document's wrap (session.xml wrap="yes|no") across a restart, the first tab's too (shown before the
# session's wrap is read), active or not, a large file staying unwrapped whatever the session says; the Document Map
# follows the document shown; turned off in Preferences, one wrap
# for all again, the last choice.
# Contract of review\tests: -Exe <notepad++.exe>; PASS/FAIL lines; last line "<n> checks, <m> failed".
param([Parameter(Mandatory)] [string] $Exe)
$ErrorActionPreference = 'Stop'
# a Pyre909 build names itself in its About box (PYRE_BUILD_TAG in AboutDlg.cpp)
if (-not [Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($Exe)).Contains('Pyre909 build')) {
	'INFO  not a Pyre909 build: skipped'; '0 checks, 0 failed'; exit
}
Add-Type -Namespace WP -Name U -MemberDefinition @'
public delegate bool EnumProc(IntPtr h, IntPtr l);
[DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
[DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EnumProc f, IntPtr l);
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, System.Text.StringBuilder s, int n);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, System.Text.StringBuilder s, int n);
[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
[DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h, int id);
[DllImport("user32.dll")] public static extern IntPtr GetMenu(IntPtr h);
[DllImport("user32.dll")] public static extern uint GetMenuState(IntPtr m, uint id, uint flags);
'@
$WM_CLOSE = 0x0010; $WM_COMMAND = 0x0111; $BM_SETCHECK = 0x00F1
$NPPM_ACTIVATEDOC = 2024 + 28; $IDM_FILE_NEW = 41001; $IDM_VIEW_WRAP = 44022; $IDM_SETTING_PREFERENCE = 48011
$SCI_GETWRAPMODE = 2269; $IDC_CHECK_WRAPPERDOCUMENT = 6369; $IDM_VIEW_DOC_MAP = 44080

$script:results = [Collections.Generic.List[string]]::new(); $script:fails = 0
function Check([string] $name, [bool] $ok, [string] $detail = '') {
	if (-not $ok) { $script:fails++ }
	$script:results.Add(("{0}  {1}{2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $(if ($detail) { "  [$detail]" } else { '' })))
}
function Send([IntPtr] $h, [int] $msg, [long] $w = 0, [long] $l = 0) { $r = [IntPtr]::Zero; [void][WP.U]::SendMessageTimeout($h, $msg, [IntPtr]$w, [IntPtr]$l, 2, 15000, [ref]$r); $r.ToInt64() }
function Get-Cls([IntPtr] $h) { $sb = [Text.StringBuilder]::new(64); [void][WP.U]::GetClassName($h, $sb, 64); $sb.ToString() }
function Get-Title([IntPtr] $h) { $sb = [Text.StringBuilder]::new(128); [void][WP.U]::GetWindowText($h, $sb, 128); $sb.ToString() }
function Get-Kids([IntPtr] $p) { $script:kids = [Collections.Generic.List[IntPtr]]::new(); [void][WP.U]::EnumChildWindows($p, { param($h, $l) $script:kids.Add($h); $true }, [IntPtr]::Zero); $script:kids.ToArray() }
function Get-Tops([uint32] $procId) { $script:tops = [Collections.Generic.List[IntPtr]]::new(); [void][WP.U]::EnumWindows({ param($h, $l) $q = 0; [void][WP.U]::GetWindowThreadProcessId($h, [ref]$q); if ($q -eq $procId) { $script:tops.Add($h) }; $true }, [IntPtr]::Zero); $script:tops.ToArray() }
function Get-View($p) { Get-Kids $p.MainWindowHandle | Where-Object { (Get-Cls $_) -eq 'Scintilla' -and [WP.U]::IsWindowVisible($_) -and [WP.U]::GetParent($_) -eq $p.MainWindowHandle } | Select-Object -First 1 }

function Start-Npp([string] $settings, [string[]] $files = @(), [switch] $NoSession) {
	$argList = @('-multiInst', "-settingsDir=$settings", '-titleAdd=REVIEW-TEST')
	if ($NoSession) { $argList += '-nosession' }
	$p = Start-Process $Exe -ArgumentList ($argList + ($files | ForEach-Object { "`"$_`"" })) -PassThru
	for ($i = 0; $i -lt 150; $i++) { Start-Sleep -Milliseconds 100; $p.Refresh(); if (($p.MainWindowHandle -ne 0) -and (Get-View $p)) { break } }
	Start-Sleep -Milliseconds 1500
	$p
}
function Stop-Npp($p) {
	if (-not $p.HasExited) {
		[void][WP.U]::PostMessage($p.MainWindowHandle, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero)
		if (-not $p.WaitForExit(15000)) { Stop-Process -Id $p.Id -Force }
	}
}
function Show-Doc($p, [int] $index) { [void](Send $p.MainWindowHandle $NPPM_ACTIVATEDOC 0 $index); Start-Sleep -Milliseconds 400 }
function Toggle-Wrap($p) { [void](Send $p.MainWindowHandle $WM_COMMAND $IDM_VIEW_WRAP); Start-Sleep -Milliseconds 400 }
# the view's wrap, and the menu item's check: "1/1" wrapped and checked
function Get-Wrap($p) { "{0}/{1}" -f (Send (Get-View $p) $SCI_GETWRAPMODE), $(if ([WP.U]::GetMenuState([WP.U]::GetMenu($p.MainWindowHandle), $IDM_VIEW_WRAP, 0) -band 8) { 1 } else { 0 }) }
# the Document Map's view wrapped or not ("?" if the map isn't found)
function Get-MapWrap($p) {
	$map = Get-Kids $p.MainWindowHandle | Where-Object { (Get-Cls $_) -eq 'Scintilla' -and (Get-Title ([WP.U]::GetParent($_))) -eq 'Document Map' } | Select-Object -First 1
	if ($map) { Send $map $SCI_GETWRAPMODE } else { '?' }
}
function Set-Config([string] $path, [hashtable] $replacements) {
	$c = [IO.File]::ReadAllText($path)
	foreach ($k in $replacements.Keys) { if ($c -notmatch $k) { throw "config: no $k" }; $c = $c -replace $k, $replacements[$k] }
	[IO.File]::WriteAllText($path, $c, [Text.UTF8Encoding]::new($false))
}

$root = Join-Path ([IO.Path]::GetTempPath()) ('npp-review\pyre-wrap-per-document-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
try {
	New-Item -ItemType Directory -Force $root | Out-Null
	$long = ('word ' * 120).Trim() # a line that wraps
	$fileA = Join-Path $root 'a.txt'; [IO.File]::WriteAllText($fileA, "$long`r`n")
	$fileB = Join-Path $root 'b.txt'; [IO.File]::WriteAllText($fileB, "$long`r`n")
	$fileL = Join-Path $root 'large.txt' # 2 MB: a large file with fileSizeMB="1"
	$sb = [Text.StringBuilder]::new(); while ($sb.Length -lt 2.1MB) { [void]$sb.Append("$long`r`n") }; [IO.File]::WriteAllText($fileL, $sb.ToString())

	# --- off (the default): one wrap for all, as upstream
	$settings = Join-Path $root 'off'; New-Item -ItemType Directory -Force $settings | Out-Null
	Stop-Npp (Start-Npp $settings -NoSession)
	$scint = (Select-String -Path (Join-Path $settings 'config.xml') -Pattern '<GUIConfig name="ScintillaPrimaryView"[^>]*>').Matches[0].Value
	Check 'config.xml: wrapPerDocument="no" by default' ($scint -match 'wrapPerDocument="no"') ($scint -replace '^(.{0,40}).*(wrapPerDocument="\w+").*$', '$1... $2')
	$proc = Start-Npp $settings @($fileA, $fileB) -NoSession
	Toggle-Wrap $proc; $b = Get-Wrap $proc
	Show-Doc $proc 0; $a = Get-Wrap $proc
	Check 'off: View > Word wrap wraps every document' (($b -eq '1/1') -and ($a -eq '1/1')) "b $b, a $a"
	Stop-Npp $proc

	# --- on: each document its own
	$settings = Join-Path $root 'on'; New-Item -ItemType Directory -Force $settings | Out-Null
	Stop-Npp (Start-Npp $settings -NoSession)
	$configPath = Join-Path $settings 'config.xml'
	Set-Config $configPath @{ 'wrapPerDocument="no"' = 'wrapPerDocument="yes"'; '(<GUIConfig name="ScintillaPrimaryView"[^>]*?) Wrap="no"' = '$1 Wrap="yes"'; '(<GUIConfig name="largeFileRestriction"[^>]*?)fileSizeMB="\d+"' = '$1fileSizeMB="1"' }
	$proc = Start-Npp $settings @($fileA, $fileB, $fileL) # a session
	$l = Get-Wrap $proc
	Show-Doc $proc 0; $a = Get-Wrap $proc
	Check 'on: a large file opened unwrapped, the others with the last choice (wrapped)' (($l -eq '0/0') -and ($a -eq '1/1')) "large $l, a $a"
	Toggle-Wrap $proc; $a = Get-Wrap $proc
	Show-Doc $proc 1; $b = Get-Wrap $proc
	Show-Doc $proc 0; $a2 = Get-Wrap $proc
	Check '  View > Word wrap: the current document only, the menu check following the document shown' (($a -eq '0/0') -and ($b -eq '1/1') -and ($a2 -eq '0/0')) "a $a, b $b, a again $a2"
	[void](Send $proc.MainWindowHandle $WM_COMMAND $IDM_FILE_NEW); Start-Sleep -Milliseconds 500; $n = Get-Wrap $proc
	Check '  a new document: the last choice (not wrapped)' ($n -eq '0/0') "new $n"
	# the last choice made "wrapped" (b toggled twice) while a, the first tab, stays unwrapped and is the active one at exit
	Show-Doc $proc 1; Toggle-Wrap $proc; Toggle-Wrap $proc; Show-Doc $proc 0
	Stop-Npp $proc
	$session = [IO.File]::ReadAllText((Join-Path $settings 'session.xml'))
	$wraps = foreach ($name in 'a.txt', 'b.txt', 'large.txt') { $m = [regex]::Match($session, "<File [^>]*filename=""[^""]*\\$([regex]::Escape($name))""[^>]*>"); "{0}={1}" -f $name, $(if ($m.Value -match ' wrap="(\w+)"') { $Matches[1] } else { '(none)' }) }
	Check '  session.xml: each document''s wrap' (($wraps -join ' ') -eq 'a.txt=no b.txt=yes large.txt=no') ($wraps -join ' ')
	$scint = (Select-String -Path $configPath -Pattern '<GUIConfig name="ScintillaPrimaryView"[^>]*>').Matches[0].Value
	Check '  config.xml: wrapPerDocument="yes", Wrap the last choice ("yes")' (($scint -match 'wrapPerDocument="yes"') -and ($scint -match ' Wrap="yes"')) ''
	# a large file wrapped in the session (by hand): it stays unwrapped
	$sessionPath = Join-Path $settings 'session.xml'
	$session = [regex]::Replace([IO.File]::ReadAllText($sessionPath), '(<File [^>]*large\.txt"[^>]*?) wrap="no"', '$1 wrap="yes"')
	[IO.File]::WriteAllText($sessionPath, $session, [Text.UTF8Encoding]::new($false))

	$proc = Start-Npp $settings
	$a = Get-Wrap $proc # the first tab, active
	Show-Doc $proc 1; $b = Get-Wrap $proc
	Show-Doc $proc 0; $a2 = Get-Wrap $proc
	Show-Doc $proc 2; $l = Get-Wrap $proc
	Check 'restart: the session''s wraps back, the first tab (active) unwrapped though the last choice is "wrapped"' (($a -eq '0/0') -and ($b -eq '1/1') -and ($a2 -eq '0/0')) "a $a, b $b, a again $a2"
	Check '  a large file wrapped in the session: unwrapped' ($l -eq '0/0') "large $l"
	# the Document Map follows the document shown
	[void](Send $proc.MainWindowHandle $WM_COMMAND $IDM_VIEW_DOC_MAP); Start-Sleep -Milliseconds 1500
	Show-Doc $proc 1; Start-Sleep -Milliseconds 800; $mb = Get-MapWrap $proc
	Show-Doc $proc 0; Start-Sleep -Milliseconds 800; $ma = Get-MapWrap $proc
	Check '  the Document Map: wrapped for b, unwrapped for a' (($mb -eq 1) -and ($ma -eq 0)) "map: b $mb, a $ma"
	[void](Send $proc.MainWindowHandle $WM_COMMAND $IDM_VIEW_DOC_MAP); Start-Sleep -Milliseconds 500
	Show-Doc $proc 1 # b active at exit: a, the first tab, not active at the next start
	Stop-Npp $proc

	$proc = Start-Npp $settings
	$b = Get-Wrap $proc
	Show-Doc $proc 0; $a = Get-Wrap $proc
	Show-Doc $proc 1; $b2 = Get-Wrap $proc
	Check 'restart with b active: the first tab (not active) keeps its wrap' (($b -eq '1/1') -and ($a -eq '0/0') -and ($b2 -eq '1/1')) "b $b, a $a, b again $b2"

	# Preferences > Editing 1 > "Per document" unchecked: one wrap for all again, the last choice (no wrap)
	[void][WP.U]::PostMessage($proc.MainWindowHandle, $WM_COMMAND, [IntPtr]$IDM_SETTING_PREFERENCE, [IntPtr]::Zero)
	$page = [IntPtr]::Zero
	for ($i = 0; $i -lt 40 -and $page -eq [IntPtr]::Zero; $i++) {
		Start-Sleep -Milliseconds 250
		$prefs = Get-Tops ([uint32]$proc.Id) | Where-Object { [WP.U]::IsWindowVisible($_) -and (Get-Title $_) -eq 'Preferences' } | Select-Object -First 1
		if ($prefs) { $page = Get-Kids $prefs | Where-Object { (Get-Cls $_) -eq '#32770' -and [WP.U]::GetDlgItem($_, $IDC_CHECK_WRAPPERDOCUMENT) -ne [IntPtr]::Zero } | Select-Object -First 1 }
	}
	Check 'Preferences: the "Per document" check box' ($page -ne $null -and $page -ne [IntPtr]::Zero)
	if ($page) {
		$box = [WP.U]::GetDlgItem($page, $IDC_CHECK_WRAPPERDOCUMENT)
		[void](Send $box $BM_SETCHECK 0)
		[void](Send $page $WM_COMMAND $IDC_CHECK_WRAPPERDOCUMENT $box.ToInt64()); Start-Sleep -Milliseconds 500 # BN_CLICKED
		[void][WP.U]::PostMessage($prefs, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero); Start-Sleep -Milliseconds 500
		$b = Get-Wrap $proc
		Show-Doc $proc 0; $a = Get-Wrap $proc
		Toggle-Wrap $proc; $a2 = Get-Wrap $proc
		Show-Doc $proc 1; $b2 = Get-Wrap $proc
		Check '  unchecked: one wrap for all (the last choice, wrapped), the toggle for all again' (($b -eq '1/1') -and ($a -eq '1/1') -and ($a2 -eq '0/0') -and ($b2 -eq '0/0')) "b $b, a $a; toggled: a $a2, b $b2"
	}
	Stop-Npp $proc
}
finally {
	foreach ($p in @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $Exe -and $_.MainWindowTitle -match 'REVIEW-TEST' })) { Stop-Process -Id $p.Id -Force }
	$script:results
	"settings folders: $root"
	"{0} checks, {1} failed" -f $script:results.Count, $script:fails
}
