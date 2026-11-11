param([Parameter(Mandatory)] [string] $Exe, [int] $Moves = 200, [int] $LineKB = 1024)
# Notepad++'s CPU per caret move (SCI_CHARLEFT / SCI_CHARRIGHT pairs sent to the view, the status bar updated at each) at
# the end of one line of $LineKB KB (UTF-8, a few non-ASCII characters), the status bar's position as "column", and with
# Len: (lineLength="yes"), and as "both"
Add-Type -Namespace CL -Name U -MemberDefinition @'
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr p, IntPtr after, string cls, string title);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
'@
function Send([IntPtr] $h, [int] $m, [long] $w = 0, [long] $l = 0) { $r = [IntPtr]::Zero; [void][CL.U]::SendMessageTimeout($h, $m, [IntPtr]$w, [IntPtr]$l, 2, 20000, [ref]$r); $r.ToInt64() }
$dir = Join-Path $env:TEMP ('npp-cl-' + [guid]::NewGuid().ToString('N').Substring(0, 6)); New-Item -ItemType Directory $dir | Out-Null
$unit = 'abcdefghij klmnopqrst uvwxyz 0123456789 ' + [string][char]0x00E9 + ' '
$file = Join-Path $dir 'long.txt'
$sb = [Text.StringBuilder]::new(); while ($sb.Length -lt $LineKB * 1024) { [void]$sb.Append($unit) }
[IO.File]::WriteAllText($file, $sb.ToString(), [Text.UTF8Encoding]::new($false))
foreach ($c in @(@('column', 'position="column" lineLength="no"'), @('column, Len:', 'position="column" lineLength="yes"'), @('both, Len:', 'position="both" lineLength="yes"'))) {
	$settings = Join-Path $dir ('s' + [guid]::NewGuid().ToString('N').Substring(0, 4)); New-Item -ItemType Directory $settings | Out-Null
	[IO.File]::WriteAllText((Join-Path $settings 'config.xml'), "<?xml version=""1.0"" encoding=""UTF-8"" ?><NotepadPlus><GUIConfigs><GUIConfig name=""StatusBar"" $($c[1]) /></GUIConfigs></NotepadPlus>")
	$p = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$settings", "`"$file`"" -PassThru
	for ($i = 0; $i -lt 100 -and $p.MainWindowHandle -eq 0; $i++) { Start-Sleep -Milliseconds 100; $p.Refresh() }
	Start-Sleep -Milliseconds 2000
	$view = [IntPtr]::Zero; $h = [IntPtr]::Zero
	while (($h = [CL.U]::FindWindowEx($p.MainWindowHandle, $h, 'Scintilla', [NullString]::Value)) -ne [IntPtr]::Zero) { if ($view -eq [IntPtr]::Zero -and [CL.U]::IsWindowVisible($h)) { $view = $h } }
	[void](Send $view 2318); Start-Sleep -Milliseconds 800 # SCI_DOCUMENTEND
	foreach ($i in 1..10) { [void](Send $view 2304); [void](Send $view 2306) } # warm
	$p.Refresh(); $cpu0 = $p.TotalProcessorTime.TotalMilliseconds
	foreach ($i in 1..($Moves / 2)) { [void](Send $view 2304); Start-Sleep -Milliseconds 0; [void](Send $view 2306) } # SCI_CHARLEFT, SCI_CHARRIGHT
	Start-Sleep -Milliseconds 1500 # the paints (and status bar updates) the moves queued
	$p.Refresh(); $cpu = ($p.TotalProcessorTime.TotalMilliseconds - $cpu0) / $Moves
	"{0,-14} {1,6:N2} ms CPU a caret move (a line of {2} KB, the caret at its end)" -f $c[0], $cpu, $LineKB
	Stop-Process -Id $p.Id -Force; [void]$p.WaitForExit(5000)
}
Remove-Item -LiteralPath $dir -Recurse -Force
