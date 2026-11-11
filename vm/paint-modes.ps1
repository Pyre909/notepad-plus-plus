param([Parameter(Mandatory)] [string] $Exe, [string] $File = "$env:TEMP\npp-bench\files\code.cpp", [int] $Paints = 60, [string] $Extra = '')
# Wall time and Notepad++'s CPU time per full repaint of the edit view (RedrawWindow, RDW_UPDATENOW), in each rendering
# mode: GDI (offered), DirectWrite, retain frames, draw to GDI DC, DirectX 11
Add-Type -Namespace PM -Name U -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool RedrawWindow(IntPtr h, IntPtr r, IntPtr rgn, uint flags);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr p, IntPtr after, string cls, string title);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int hh, bool repaint);
'@
foreach ($m in @(@('GDI', 0), @('DirectWrite', 1), @('retain frames', 2), @('to GDI DC', 3), @('DirectX 11', 4))) {
	$settings = Join-Path $env:TEMP ('npp-pm-' + [guid]::NewGuid().ToString('N').Substring(0, 6)); New-Item -ItemType Directory $settings | Out-Null
	[IO.File]::WriteAllText((Join-Path $settings 'config.xml'), "<?xml version=""1.0"" encoding=""UTF-8"" ?><NotepadPlus><GUIConfigs><GUIConfig name=""MISC"" writeTechnologyEngine=""$($m[1])"" offerGdiRendering=""yes"" />$Extra</GUIConfigs></NotepadPlus>")
	$p = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$settings", "`"$File`"" -PassThru
	for ($i = 0; $i -lt 100 -and $p.MainWindowHandle -eq 0; $i++) { Start-Sleep -Milliseconds 100; $p.Refresh() }
	Start-Sleep -Milliseconds 1500
	[void][PM.U]::MoveWindow($p.MainWindowHandle, 40, 40, 1200, 800, $true); Start-Sleep -Milliseconds 800
	$view = [IntPtr]::Zero; $h = [IntPtr]::Zero
	while (($h = [PM.U]::FindWindowEx($p.MainWindowHandle, $h, 'Scintilla', [NullString]::Value)) -ne [IntPtr]::Zero) { if ($view -eq [IntPtr]::Zero -and [PM.U]::IsWindowVisible($h)) { $view = $h } }
	foreach ($i in 1..5) { [void][PM.U]::RedrawWindow($view, [IntPtr]::Zero, [IntPtr]::Zero, 0x0101) }
	$p.Refresh(); $cpu0 = $p.TotalProcessorTime.TotalMilliseconds
	$sw = [Diagnostics.Stopwatch]::StartNew()
	foreach ($i in 1..$Paints) { [void][PM.U]::RedrawWindow($view, [IntPtr]::Zero, [IntPtr]::Zero, 0x0101) } # INVALIDATE | UPDATENOW
	$wall = $sw.Elapsed.TotalMilliseconds / $Paints
	$p.Refresh(); $cpu = ($p.TotalProcessorTime.TotalMilliseconds - $cpu0) / $Paints
	"{0,-14} {1,6:N1} ms a paint, {2,5:N1} ms CPU" -f $m[0], $wall, $cpu
	Stop-Process -Id $p.Id -Force; [void]$p.WaitForExit(5000)
	Remove-Item -LiteralPath $settings -Recurse -Force
}
