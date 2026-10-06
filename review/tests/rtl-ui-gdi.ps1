# App-level test (review harness): right-to-left views drawn with GDI, with a right-to-left UI language (hebrew.xml as
# nativeLang.xml; branch rtl-views-gdi_20261006). Every Scintilla inherits the mirroring of the Notepad++ window, and the
# documents are RTL by default; DirectWrite ignores that mirroring (upstream draws such a view left-to-right in a mirrored
# window, clicks mirrored). With DirectWrite, the default rendering mode, the mirrored views must be drawn with GDI, no
# message must show, and a document switched to LTR must get the rendering mode. Needs no live rendering mode switch.
# Contract of review\tests: -Exe <notepad++.exe>; PASS/FAIL lines; last line "<n> checks, <m> failed".
param([Parameter(Mandatory)] [string] $Exe,
	[string] $LangXml = (Join-Path (Split-Path (Split-Path (Split-Path $Exe))) 'PowerEditor\installer\nativeLang\hebrew.xml'),
	[string] $TestFile = (Join-Path $PSScriptRoot '..\..\vm\weights.cpp'))
$ErrorActionPreference = 'Stop'
Add-Type -Namespace RU -Name U -MemberDefinition @'
public delegate bool EnumProc(IntPtr h, IntPtr l);
[DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
[DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EnumProc f, IntPtr l);
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, System.Text.StringBuilder s, int n);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, System.Text.StringBuilder s, int n);
[DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h, int id);
[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
[DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int idx);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
'@
$WM_CLOSE = 0x0010; $WM_COMMAND = 0x0111; $IDM_EDIT_RTL = 42026; $IDM_EDIT_LTR = 42027

function Get-Cls([IntPtr] $h) { $sb = [Text.StringBuilder]::new(64); [void][RU.U]::GetClassName($h, $sb, 64); $sb.ToString() }
function Get-Txt([IntPtr] $h) { $sb = [Text.StringBuilder]::new(512); [void][RU.U]::GetWindowText($h, $sb, 512); $sb.ToString() }
function Get-Tops { $script:acc = [Collections.Generic.List[IntPtr]]::new(); [void][RU.U]::EnumWindows({ param($h, $l) $p = 0; [void][RU.U]::GetWindowThreadProcessId($h, [ref]$p); if ($p -eq $script:npid) { $script:acc.Add($h) }; $true }, [IntPtr]::Zero); $script:acc.ToArray() }
function Get-Kids([IntPtr] $p) { $script:kids = [Collections.Generic.List[IntPtr]]::new(); [void][RU.U]::EnumChildWindows($p, { param($h, $l) $script:kids.Add($h); $true }, [IntPtr]::Zero); $script:kids.ToArray() }
function Get-Views { $v = [Collections.Generic.List[IntPtr]]::new(); foreach ($t in (Get-Tops)) { if ((Get-Cls $t) -eq 'Scintilla') { $v.Add($t) }; foreach ($c in (Get-Kids $t)) { if ((Get-Cls $c) -eq 'Scintilla' -and -not $v.Contains($c)) { $v.Add($c) } } }; $v.ToArray() }
function Get-MainViews { @(Get-Views | Where-Object { ([RU.U]::GetParent($_) -eq $script:main) -and [RU.U]::IsWindowVisible($_) }) }
function Send([IntPtr] $h, [int] $msg, [long] $w = 0, [long] $l = 0) { $r = [IntPtr]::Zero; [void][RU.U]::SendMessageTimeout($h, $msg, [IntPtr]$w, [IntPtr]$l, 2, 5000, [ref]$r); $r.ToInt64() }
function Get-Tech([IntPtr] $h) { Send $h 2631 }
function Test-RTL([IntPtr] $h) { ([RU.U]::GetWindowLong($h, -20) -band 0x00400000) -ne 0 }
function Describe([IntPtr] $h) { '{0}, technology {1}' -f $(if (Test-RTL $h) { 'RTL' } else { 'LTR' }), (Get-Tech $h) }
function Wait-AnyBox([int] $tenths = 10) {
	for ($i = 0; $i -lt $tenths; $i++) {
		Start-Sleep -Milliseconds 100
		$b = Get-Tops | Where-Object { (Get-Cls $_) -eq '#32770' -and [RU.U]::IsWindowVisible($_) } | Select-Object -First 1
		if ($b) { return $b }
	}
	$null
}
function Close-AnyBox([IntPtr] $b) { $no = [RU.U]::GetDlgItem($b, 7); if ($no -ne [IntPtr]::Zero) { [void][RU.U]::PostMessage($b, $WM_COMMAND, [IntPtr]7, $no) } else { [void][RU.U]::PostMessage($b, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero) } }
function Box-Text([IntPtr] $b) { (Get-Txt $b) + ': ' + ((Get-Kids $b | ForEach-Object { Get-Txt $_ } | Where-Object { $_ }) -join ' | ') }
$script:results = [Collections.Generic.List[string]]::new(); $script:fails = 0
function Check([string] $name, [bool] $ok, [string] $detail = '') {
	if (-not $ok) { $script:fails++ }
	$script:results.Add(("{0}  {1}{2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $(if ($detail) { "  [$detail]" } else { '' })))
}

if (-not (Test-Path $LangXml)) { "FAIL  no language file $LangXml"; '1 checks, 1 failed'; exit }
$settings = Join-Path ([IO.Path]::GetTempPath()) ('npp-review\rtl-ui-gdi-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force $settings | Out-Null
Copy-Item $LangXml (Join-Path $settings 'nativeLang.xml'); Copy-Item $TestFile $settings; $file = Join-Path $settings (Split-Path $TestFile -Leaf)
$proc = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$settings", '-titleAdd=REVIEW-TEST', $file -PassThru
$script:npid = $proc.Id
try {
	for ($i = 0; $i -lt 100; $i++) { $proc.Refresh(); if ($proc.MainWindowHandle -ne 0) { break }; Start-Sleep -Milliseconds 100 }
	$script:main = $proc.MainWindowHandle; Start-Sleep -Milliseconds 800
	$views = @(Get-Views)
	Check 'RTL UI: the Notepad++ window is mirrored' (Test-RTL $script:main)
	Check 'RTL UI: every view mirrored (inherited, and the document RTL by default)' ((@($views | Where-Object { -not (Test-RTL $_) }).Count -eq 0) -and ($views.Count -gt 0)) ("{0} views" -f $views.Count)
	Check 'start with DirectWrite (fresh settings default): every mirrored view on GDI' (@($views | Where-Object { (Get-Tech $_) -ne 0 }).Count -eq 0) (($views | ForEach-Object { Describe $_ }) -join '; ')
	$box = Wait-AnyBox 5
	Check 'start: no message' ($null -eq $box) $(if ($box) { Box-Text $box })
	if ($box) { Close-AnyBox $box }

	# the document switched to LTR: its view gets the rendering mode, the hidden mirrored views keep GDI
	[void](Send $script:main $WM_COMMAND $IDM_EDIT_LTR); Start-Sleep -Milliseconds 300
	$mv = @(Get-MainViews); $hidden = @(Get-Views | Where-Object { -not [RU.U]::IsWindowVisible($_) })
	Check 'LTR document: its view unmirrored, on DirectWrite' (($mv.Count -eq 1) -and (-not (Test-RTL $mv[0])) -and ((Get-Tech $mv[0]) -eq 1)) (($mv | ForEach-Object { Describe $_ }) -join '; ')
	Check 'the hidden views: still mirrored, on GDI' (($hidden.Count -gt 0) -and (@($hidden | Where-Object { -not (Test-RTL $_) -or ((Get-Tech $_) -ne 0) }).Count -eq 0)) ("{0} hidden" -f $hidden.Count)
	if ($mv.Count -eq 1) {
		[void][RU.U]::PostMessage($script:main, $WM_COMMAND, [IntPtr]$IDM_EDIT_RTL, [IntPtr]::Zero)
		$box = Wait-AnyBox
		Check 'back to RTL with DirectWrite: no message' ($null -eq $box) $(if ($box) { Box-Text $box })
		if ($box) { Close-AnyBox $box }
		Check 'back to RTL: mirrored, on GDI' ((Test-RTL $mv[0]) -and ((Get-Tech $mv[0]) -eq 0)) (Describe $mv[0])
	}

	# on exit the documents close and a new empty one (RTL by default) is activated: upstream warned here, with DirectWrite
	[void][RU.U]::PostMessage($script:main, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero)
	$boxes = @()
	for ($i = 0; $i -lt 60 -and -not $proc.HasExited; $i++) { $b = Wait-AnyBox 2; if ($b) { $boxes += Box-Text $b; Close-AnyBox $b } }
	Check 'exit: no message' ($boxes.Count -eq 0) ($boxes -join '; ')
	$exited = $proc.WaitForExit(15000)
	Check 'Notepad++ closes normally' ($exited -and $proc.ExitCode -eq 0) $(if ($exited) { "exit code $($proc.ExitCode)" } else { 'still running' })
}
finally {
	if (-not $proc.HasExited) { [void][RU.U]::PostMessage($script:main, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero); if (-not $proc.WaitForExit(10000)) { Stop-Process -Id $proc.Id -Force } }
	$script:results
	"settings folder: $settings"
	"{0} checks, {1} failed" -f $script:results.Count, $script:fails
}
