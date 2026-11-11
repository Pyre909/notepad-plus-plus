param([Parameter(Mandatory)] [string[]] $Exe, [string] $Font = 'MonoLisaCode', [string] $OutDir = "$PSScriptRoot\grid-pixels")
# The same mixed screen with the character grid on (DirectWrite, then GDI), captured with each build: pixels that differ
Add-Type -AssemblyName System.Drawing
Add-Type -Namespace GP -Name U -MemberDefinition @'
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr p, IntPtr after, string cls, string title);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int hh, bool repaint);
[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
[DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
[DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
[DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr c);
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
'@
[void][GP.U]::SetThreadDpiAwarenessContext([IntPtr](-4))
New-Item -ItemType Directory -Force $OutDir | Out-Null
$c = { param([int[]] $codes) -join ($codes | ForEach-Object { [char]::ConvertFromUtf32($_) }) }
$lines = @(
	'    if (value > limit) { result = compute(value, limit); } // a comment',
	('Vietnamese: ' + (& $c 0x1EA0,0x1EA1,0x1EBF,0x1EC7,0x1ED9,0x1EE3,0x1EF1) + ' Greek: ' + (& $c 0x1F00,0x1F08,0x1F70)),
	('Quotes ' + (& $c 0x201C) + 'text' + (& $c 0x201D) + ' dash ' + (& $c 0x2013,0x2014,0x2026,0x2022) + ' arrows ' + (& $c 0x2190,0x2192,0x21D2,0x2200,0x2264,0x2260)),
	((& $c 0x250C,0x2500,0x2500,0x252C,0x2500,0x2510) + ' box ' + (& $c 0x2502,0x2588,0x2591,0x25A0,0x25CF,0x2605) + ' half ' + (& $c 0xFF76,0xFF80,0xFF9D)),
	('CJK ' + (& $c 0x65E5,0x672C,0x8A9E,0x306E,0x30C6,0x30AD,0x30B9,0x30C8,0x3001,0x4E2D,0x6587) + ' end'),
	('		indented	with tabs		and   spaces   ')
)
$file = Join-Path $OutDir 'mixed.txt'; [IO.File]::WriteAllText($file, (($lines * 4) -join "`r`n"), [Text.UTF8Encoding]::new($false))
$shots = @{}
foreach ($exe in $Exe) {
	foreach ($tech in 1, 0) {
		$settings = Join-Path $env:TEMP ('npp-gp-' + [guid]::NewGuid().ToString('N').Substring(0, 6)); New-Item -ItemType Directory $settings | Out-Null
		$model = [IO.File]::ReadAllText((Join-Path (Split-Path $exe) 'stylers.model.xml'))
		$model = [regex]::Replace($model, '(<WidgetStyle name="Default Style" styleID="32"[^>]*?fontName=")[^"]*("[^>]*?fontSize=")[^"]*"', "`${1}$Font`${2}10`"")
		[IO.File]::WriteAllText((Join-Path $settings 'stylers.xml'), $model, [Text.UTF8Encoding]::new($false))
		[IO.File]::WriteAllText((Join-Path $settings 'config.xml'), "<?xml version=""1.0"" encoding=""UTF-8"" ?><NotepadPlus><GUIConfigs><GUIConfig name=""MISC"" writeTechnologyEngine=""$tech"" offerGdiRendering=""yes"" /></GUIConfigs></NotepadPlus>")
		$p = Start-Process $exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$settings", "`"$file`"" -PassThru
		for ($i = 0; $i -lt 100 -and $p.MainWindowHandle -eq 0; $i++) { Start-Sleep -Milliseconds 100; $p.Refresh() }
		Start-Sleep -Milliseconds 1500
		[void][GP.U]::MoveWindow($p.MainWindowHandle, 40, 40, 1300, 800, $true); Start-Sleep -Milliseconds 600
		$r = [IntPtr]::Zero; [void][GP.U]::SendMessageTimeout($p.MainWindowHandle, 0x0111, [IntPtr]44190, [IntPtr]::Zero, 2, 10000, [ref]$r) # grid on
		$view = [IntPtr]::Zero; $h = [IntPtr]::Zero
		while (($h = [GP.U]::FindWindowEx($p.MainWindowHandle, $h, 'Scintilla', [NullString]::Value)) -ne [IntPtr]::Zero) { if ($view -eq [IntPtr]::Zero -and [GP.U]::IsWindowVisible($h)) { $view = $h } }
		[void][GP.U]::SendMessageTimeout($view, 2512, [IntPtr]0, [IntPtr]::Zero, 2, 10000, [ref]$r) # SCI_SETCARETSTYLE invisible
		Start-Sleep -Milliseconds 800
		$cr = [GP.U+RECT]::new(); [void][GP.U]::GetClientRect($view, [ref]$cr)
		$bmp = [Drawing.Bitmap]::new($cr.Right, $cr.Bottom); $g = [Drawing.Graphics]::FromImage($bmp); $hdc = $g.GetHdc()
		[void][GP.U]::PrintWindow($view, $hdc, 3); $g.ReleaseHdc($hdc); $g.Dispose()
		$name = "{0}-{1}" -f (Split-Path (Split-Path $exe) -Leaf), $(if ($tech) { 'dw' } else { 'gdi' })
		$bmp.Save((Join-Path $OutDir "$name.png")); $shots[$name] = $bmp
		Stop-Process -Id $p.Id -Force; [void]$p.WaitForExit(5000)
		Remove-Item -LiteralPath $settings -Recurse -Force
	}
}
$names = @($shots.Keys | Sort-Object)
foreach ($tech in 'dw', 'gdi') {
	$pair = @($names | Where-Object { $_.EndsWith("-$tech") })
	if ($pair.Count -lt 2) { continue }
	$a = $shots[$pair[0]]; $b = $shots[$pair[1]]; $n = 0
	for ($y = 0; $y -lt [Math]::Min($a.Height, $b.Height); $y++) { for ($x = 0; $x -lt [Math]::Min($a.Width, $b.Width); $x++) { if ($a.GetPixel($x, $y).ToArgb() -ne $b.GetPixel($x, $y).ToArgb()) { $n++ } } }
	"{0}: {1} vs {2}: {3} pixels differ" -f $tech, $pair[0], $pair[1], $n
}
