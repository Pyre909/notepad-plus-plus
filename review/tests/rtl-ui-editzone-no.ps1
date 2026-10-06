# App-level test (review harness): a right-to-left UI language with editZoneRTL="no" (hebrew.xml given that attribute,
# as nativeLang.xml): the documents are LTR, but the views are mirrored like the Notepad++ window. Started without a
# session and without a file, the first documents are activated while already current (activateBuffer returns early),
# so upstream leaves the main view mirrored (issue #17518: RTL with GDI; with DirectWrite drawn left-to-right in a
# mirrored window). Checks that the main view is LTR and drawn with the rendering mode, and that no message shows.
# Contract of review\tests: -Exe <notepad++.exe>; PASS/FAIL lines; last line "<n> checks, <m> failed".
param([Parameter(Mandatory)] [string] $Exe,
	[string] $LangXml = (Join-Path (Split-Path (Split-Path (Split-Path $Exe))) 'PowerEditor\installer\nativeLang\hebrew.xml'))
$ErrorActionPreference = 'Stop'
Add-Type -Namespace EZ -Name U -MemberDefinition @'
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
$WM_CLOSE = 0x0010; $WM_COMMAND = 0x0111; $IDM_FILE_NEW = 41001
function Get-Cls([IntPtr] $h) { $sb = [Text.StringBuilder]::new(64); [void][EZ.U]::GetClassName($h, $sb, 64); $sb.ToString() }
function Get-Txt([IntPtr] $h) { $sb = [Text.StringBuilder]::new(512); [void][EZ.U]::GetWindowText($h, $sb, 512); $sb.ToString() }
function Get-Tops { $script:acc = [Collections.Generic.List[IntPtr]]::new(); [void][EZ.U]::EnumWindows({ param($h, $l) $p = 0; [void][EZ.U]::GetWindowThreadProcessId($h, [ref]$p); if ($p -eq $script:npid) { $script:acc.Add($h) }; $true }, [IntPtr]::Zero); $script:acc.ToArray() }
function Get-Kids([IntPtr] $p) { $script:kids = [Collections.Generic.List[IntPtr]]::new(); [void][EZ.U]::EnumChildWindows($p, { param($h, $l) $script:kids.Add($h); $true }, [IntPtr]::Zero); $script:kids.ToArray() }
function Send([IntPtr] $h, [int] $msg, [long] $w = 0, [long] $l = 0) { $r = [IntPtr]::Zero; [void][EZ.U]::SendMessageTimeout($h, $msg, [IntPtr]$w, [IntPtr]$l, 2, 5000, [ref]$r); $r.ToInt64() }
function Test-RTL([IntPtr] $h) { ([EZ.U]::GetWindowLong($h, -20) -band 0x00400000) -ne 0 }
function Get-Boxes { @(Get-Tops | Where-Object { (Get-Cls $_) -eq '#32770' -and [EZ.U]::IsWindowVisible($_) } | ForEach-Object { (Get-Txt $_) + ': ' + ((Get-Kids $_ | ForEach-Object { Get-Txt $_ } | Where-Object { $_ }) -join ' | ') }) }
$script:results = [Collections.Generic.List[string]]::new(); $script:fails = 0
function Check([string] $name, [bool] $ok, [string] $detail = '') {
	if (-not $ok) { $script:fails++ }
	$script:results.Add(("{0}  {1}{2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $(if ($detail) { "  [$detail]" } else { '' })))
}

if (-not (Test-Path $LangXml)) { "FAIL  no language file $LangXml"; '1 checks, 1 failed'; exit }
$settings = Join-Path ([IO.Path]::GetTempPath()) ('npp-review\rtl-ui-editzone-no-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force $settings | Out-Null
$xml = [IO.File]::ReadAllText($LangXml) -replace '(<Native-Langue name="Hebrew" RTL="yes")', '$1 editZoneRTL="no"'
if ($xml -notmatch 'editZoneRTL="no" filename') { "FAIL  could not set editZoneRTL in $LangXml"; '1 checks, 1 failed'; exit }
[IO.File]::WriteAllText((Join-Path $settings 'nativeLang.xml'), $xml, [Text.UTF8Encoding]::new($false))
$proc = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$settings", '-titleAdd=REVIEW-TEST' -PassThru
$script:npid = $proc.Id
try {
	for ($i = 0; $i -lt 100; $i++) { $proc.Refresh(); if ($proc.MainWindowHandle -ne 0) { break }; Start-Sleep -Milliseconds 100 }
	$script:main = $proc.MainWindowHandle; Start-Sleep -Milliseconds 1000
	$view = Get-Kids $script:main | Where-Object { (Get-Cls $_) -eq 'Scintilla' -and [EZ.U]::IsWindowVisible($_) -and [EZ.U]::GetParent($_) -eq $script:main } | Select-Object -First 1
	Check 'RTL UI: the Notepad++ window is mirrored' (Test-RTL $script:main)
	Check 'editZoneRTL="no", no session, no file: the first document is LTR' (-not (Test-RTL $view))
	Check 'and drawn with the rendering mode, DirectWrite (fresh settings default)' ((Send $view 2631) -eq 1) ("technology " + (Send $view 2631))
	[void](Send $script:main $WM_COMMAND $IDM_FILE_NEW); Start-Sleep -Milliseconds 400
	Check 'File > New: LTR too, on DirectWrite' ((-not (Test-RTL $view)) -and ((Send $view 2631) -eq 1))
	$boxes = Get-Boxes
	Check 'no message' ($boxes.Count -eq 0) ($boxes -join '; ')

	[void][EZ.U]::PostMessage($script:main, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero)
	$boxes = @()
	for ($i = 0; $i -lt 60 -and -not $proc.HasExited; $i++) {
		Start-Sleep -Milliseconds 250
		foreach ($b in @(Get-Tops | Where-Object { (Get-Cls $_) -eq '#32770' -and [EZ.U]::IsWindowVisible($_) })) {
			$boxes += (Get-Txt $b) + ': ' + ((Get-Kids $b | ForEach-Object { Get-Txt $_ } | Where-Object { $_ }) -join ' | ')
			$no = [EZ.U]::GetDlgItem($b, 7); if ($no -ne [IntPtr]::Zero) { [void][EZ.U]::PostMessage($b, $WM_COMMAND, [IntPtr]7, $no) } else { [void][EZ.U]::PostMessage($b, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero) }
		}
	}
	Check 'exit: no message' ($boxes.Count -eq 0) ($boxes -join '; ')
	$exited = $proc.WaitForExit(15000)
	Check 'Notepad++ closes normally' ($exited -and $proc.ExitCode -eq 0) $(if ($exited) { "exit code $($proc.ExitCode)" } else { 'still running' })
}
finally {
	if (-not $proc.HasExited) { [void][EZ.U]::PostMessage($script:main, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero); if (-not $proc.WaitForExit(10000)) { Stop-Process -Id $proc.Id -Force } }
	$script:results
	"settings folder: $settings"
	"{0} checks, {1} failed" -f $script:results.Count, $script:fails
}
