# App-level test (review harness), Pyre909 builds only: the strokes of Notepad++'s indicators (the links: 8, the find, mark
# and smart highlighting boxes: 21 to 31) follow the DPI in whole pixels (1 up to 137%, 2 from 150%, 3 from 250%), and a
# plugin's indicator (9 to 20) is left at Scintilla's 1 pixel. Markers have no getter: their widths are set the same way
# (ScintillaEditView::setStrokeWidthsForDpi), and the screenshot tool of the review shows them.
# Contract of review\tests: -Exe <notepad++.exe>; PASS/FAIL lines; last line "<n> checks, <m> failed".
param([Parameter(Mandatory)] [string] $Exe)
$ErrorActionPreference = 'Stop'
if (-not [Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($Exe)).Contains('Pyre909 build')) {
	'INFO  not a Pyre909 build: skipped'; '0 checks, 0 failed'; exit
}
Add-Type -Namespace SW -Name U -MemberDefinition @'
public delegate bool EnumProc(IntPtr h, IntPtr l);
[DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EnumProc f, IntPtr l);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, System.Text.StringBuilder s, int n);
[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
[DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
'@
$script:results = [Collections.Generic.List[string]]::new(); $script:fails = 0
function Check([string] $name, [bool] $ok, [string] $detail = '') {
	if (-not $ok) { $script:fails++ }
	$script:results.Add(("{0}  {1}{2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $(if ($detail) { "  [$detail]" } else { '' })))
}
function Send([IntPtr] $h, [int] $msg, [long] $w = 0, [long] $l = 0) { $r = [IntPtr]::Zero; [void][SW.U]::SendMessageTimeout($h, $msg, [IntPtr]$w, [IntPtr]$l, 2, 5000, [ref]$r); $r.ToInt64() }
$SCI_INDICGETSTROKEWIDTH = 2752

$root = Join-Path ([IO.Path]::GetTempPath()) ('npp-review\pyre-stroke-widths-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
try {
	New-Item -ItemType Directory -Force $root | Out-Null
	$p = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$root", '-titleAdd=REVIEW-TEST' -PassThru
	$script:view = [IntPtr]::Zero
	for ($i = 0; $i -lt 150 -and $script:view -eq [IntPtr]::Zero; $i++) {
		Start-Sleep -Milliseconds 100; $p.Refresh()
		if ($p.MainWindowHandle -ne 0) { [void][SW.U]::EnumChildWindows($p.MainWindowHandle, { param($h, $l) $sb = [Text.StringBuilder]::new(32); [void][SW.U]::GetClassName($h, $sb, 32); if ($sb.ToString() -eq 'Scintilla' -and [SW.U]::IsWindowVisible($h) -and [SW.U]::GetParent($h) -eq $p.MainWindowHandle) { $script:view = $h }; $true }, [IntPtr]::Zero) }
	}
	Start-Sleep -Milliseconds 800
	$dpi = [SW.U]::GetDpiForWindow($script:view)
	$expected = [Math]::Floor(([Math]::Floor(100 * $dpi / 96) + 50) / 100) * 100 # as DPIManagerV2::scale, then rounded to whole pixels
	$own = foreach ($n in @(8) + (21..31)) { "{0}={1}" -f $n, (Send $script:view $SCI_INDICGETSTROKEWIDTH $n) }
	Check "Notepad++'s indicators: $expected hundredths of a pixel at $dpi DPI" (@($own | Where-Object { $_ -notmatch "=$expected$" }).Count -eq 0) ($own -join ' ')
	$plugin = foreach ($n in 9, 15, 20) { "{0}={1}" -f $n, (Send $script:view $SCI_INDICGETSTROKEWIDTH $n) }
	Check '  the plugins'' indicators left at 100' (@($plugin | Where-Object { $_ -notmatch '=100$' }).Count -eq 0) ($plugin -join ' ')
	[void][SW.U]::PostMessage($p.MainWindowHandle, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
	if (-not $p.WaitForExit(10000)) { Stop-Process -Id $p.Id -Force }
}
finally {
	foreach ($q in @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $Exe -and $_.MainWindowTitle -match 'REVIEW-TEST' })) { Stop-Process -Id $q.Id -Force }
	$script:results
	"{0} checks, {1} failed" -f $script:results.Count, $script:fails
}
