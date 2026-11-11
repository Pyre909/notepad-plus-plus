param([Parameter(Mandatory)] [string] $Exe, [string] $Font = 'MonoLisaCode', [int] $Paints = 60)
# Notepad++'s CPU per full repaint of the edit view (RedrawWindow, RDW_UPDATENOW): a screen of CJK text and one of ASCII
# code, DirectWrite and GDI, the character grid off and on (IDM_VIEW_CHARACTER_GRID). CPU, not wall time: DirectWrite's
# paints wait for the display's refresh
Add-Type -Namespace GC -Name U -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool RedrawWindow(IntPtr h, IntPtr r, IntPtr rgn, uint flags);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr p, IntPtr after, string cls, string title);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int hh, bool repaint);
[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
'@
$dir = Join-Path $env:TEMP ('npp-gc-' + [guid]::NewGuid().ToString('N').Substring(0, 6)); New-Item -ItemType Directory $dir | Out-Null
$cjkLine = -join (1..12 | ForEach-Object { [string]::new([char[]](0x65E5, 0x672C, 0x8A9E, 0x306E, 0x30C6, 0x30AD, 0x30B9, 0x30C8, 0x3001, 0x4E2D, 0x6587, 0x6DF7, 0x6392, 0x3002)) })
$asciiLine = '    if (value > limit) { result = compute(value, limit); } // a comment, then more text'
foreach ($sample in @(@('CJK', $cjkLine), @('ASCII code', $asciiLine))) {
	$file = Join-Path $dir 'paint.cpp'; [IO.File]::WriteAllText($file, ((1..80 | ForEach-Object { $sample[1] }) -join "`r`n"), [Text.UTF8Encoding]::new($false))
	foreach ($m in @(@('DirectWrite', 1), @('GDI', 0))) {
		$settings = Join-Path $dir ('s' + [guid]::NewGuid().ToString('N').Substring(0, 4)); New-Item -ItemType Directory $settings | Out-Null
		$model = [IO.File]::ReadAllText((Join-Path (Split-Path $Exe) 'stylers.model.xml'))
		$model = [regex]::Replace($model, '(<WidgetStyle name="Default Style" styleID="32"[^>]*?fontName=")[^"]*("[^>]*?fontSize=")[^"]*"', "`${1}$Font`${2}10`"")
		[IO.File]::WriteAllText((Join-Path $settings 'stylers.xml'), $model, [Text.UTF8Encoding]::new($false))
		[IO.File]::WriteAllText((Join-Path $settings 'config.xml'), "<?xml version=""1.0"" encoding=""UTF-8"" ?><NotepadPlus><GUIConfigs><GUIConfig name=""MISC"" writeTechnologyEngine=""$($m[1])"" offerGdiRendering=""yes"" /></GUIConfigs></NotepadPlus>")
		$p = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$settings", "`"$file`"" -PassThru
		for ($i = 0; $i -lt 100 -and $p.MainWindowHandle -eq 0; $i++) { Start-Sleep -Milliseconds 100; $p.Refresh() }
		Start-Sleep -Milliseconds 1500
		[void][GC.U]::MoveWindow($p.MainWindowHandle, 40, 40, 1200, 800, $true); Start-Sleep -Milliseconds 800
		$view = [IntPtr]::Zero; $h = [IntPtr]::Zero
		while (($h = [GC.U]::FindWindowEx($p.MainWindowHandle, $h, 'Scintilla', [NullString]::Value)) -ne [IntPtr]::Zero) { if ($view -eq [IntPtr]::Zero -and [GC.U]::IsWindowVisible($h)) { $view = $h } }
		$results = foreach ($grid in 'off', 'on') {
			if ($grid -eq 'on') { $r = [IntPtr]::Zero; [void][GC.U]::SendMessageTimeout($p.MainWindowHandle, 0x0111, [IntPtr]44190, [IntPtr]::Zero, 2, 10000, [ref]$r); Start-Sleep -Milliseconds 500 }
			foreach ($i in 1..5) { [void][GC.U]::RedrawWindow($view, [IntPtr]::Zero, [IntPtr]::Zero, 0x0101) }
			$rounds = foreach ($round in 1..3) {
				$p.Refresh(); $cpu0 = $p.TotalProcessorTime.TotalMilliseconds
				foreach ($i in 1..$Paints) { [void][GC.U]::RedrawWindow($view, [IntPtr]::Zero, [IntPtr]::Zero, 0x0101) }
				$p.Refresh(); ($p.TotalProcessorTime.TotalMilliseconds - $cpu0) / $Paints
			}
			'{0:N2}' -f ($rounds | Sort-Object)[1]
		}
		"{0}, {1}: grid off {2} ms, on {3} ms CPU a paint" -f $sample[0], $m[0], $results[0], $results[1]
		Stop-Process -Id $p.Id -Force; [void]$p.WaitForExit(5000)
	}
}
Remove-Item -LiteralPath $dir -Recurse -Force
