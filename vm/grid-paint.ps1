param([Parameter(Mandatory)] [string] $Exe, [string] $Font = 'MonoLisaCode', [int] $Paints = 20)
# Paint time of a screen of CJK text (and one of ASCII code), grid off and on, DirectWrite and GDI: median of 5 rounds.
Add-Type -Namespace CP -Name U -MemberDefinition @'
[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
[DllImport("user32.dll")] public static extern bool InvalidateRect(IntPtr h, IntPtr r, bool erase);
[DllImport("user32.dll")] public static extern bool UpdateWindow(IntPtr h);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int hh, bool repaint);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr p, IntPtr after, string cls, string title);
'@
function Send([IntPtr] $h, [int] $m, [long] $w = 0, [long] $l = 0) { $r = [IntPtr]::Zero; [void][CP.U]::SendMessageTimeout($h, $m, [IntPtr]$w, [IntPtr]$l, 2, 10000, [ref]$r); $r.ToInt64() }
$dir = Join-Path $env:TEMP ('npp-cp-' + [guid]::NewGuid().ToString('N').Substring(0, 6)); New-Item -ItemType Directory $dir | Out-Null
$cjkLine = -join (1..12 | ForEach-Object { '日本語のテキスト、中文混排。' })
$asciiLine = '    if (value > limit) { result = compute(value, limit); } // a comment, then more text'
foreach ($sample in @(@('CJK', $cjkLine), @('ASCII code', $asciiLine))) {
	$file = Join-Path $dir 'paint.txt'; [IO.File]::WriteAllText($file, ((1..80 | ForEach-Object { $sample[1] }) -join "`r`n"), [Text.UTF8Encoding]::new($false))
	$settings = Join-Path $dir ('s' + [guid]::NewGuid().ToString('N').Substring(0, 4)); New-Item -ItemType Directory $settings | Out-Null
	$model = [IO.File]::ReadAllText((Join-Path (Split-Path $Exe) 'stylers.model.xml'))
	$model = [regex]::Replace($model, '(<WidgetStyle name="Default Style" styleID="32"[^>]*?fontName=")[^"]*("[^>]*?fontSize=")[^"]*"', "`${1}$Font`${2}10`"")
	[IO.File]::WriteAllText((Join-Path $settings 'stylers.xml'), $model, [Text.UTF8Encoding]::new($false))
	$p = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$settings", "`"$file`"" -PassThru
	for ($i = 0; $i -lt 100 -and $p.MainWindowHandle -eq 0; $i++) { Start-Sleep -Milliseconds 100; $p.Refresh() }
	Start-Sleep -Milliseconds 1500
	[void][CP.U]::MoveWindow($p.MainWindowHandle, 20, 20, 1600, 1000, $true); Start-Sleep -Milliseconds 400
	$sc = [IntPtr]::Zero; $h = [IntPtr]::Zero
	while (($h = [CP.U]::FindWindowEx($p.MainWindowHandle, $h, 'Scintilla', [NullString]::Value)) -ne [IntPtr]::Zero) { if ($sc -eq [IntPtr]::Zero -and [CP.U]::IsWindowVisible($h)) { $sc = $h } }
	foreach ($tech in @(@(1, 'DirectWrite'), @(0, 'GDI'))) {
		[void](Send $sc 2630 $tech[0]); Start-Sleep -Milliseconds 300
		$result = @{}
		foreach ($grid in 'off', 'on') {
			if ($grid -eq 'on') { [void](Send $p.MainWindowHandle 0x0111 44190) }
			$times = @()
			for ($round = 0; $round -lt 5; $round++) {
				[void][CP.U]::InvalidateRect($sc, [IntPtr]::Zero, $false); [void][CP.U]::UpdateWindow($sc)
				$sw = [Diagnostics.Stopwatch]::StartNew()
				for ($i = 0; $i -lt $Paints; $i++) { [void][CP.U]::InvalidateRect($sc, [IntPtr]::Zero, $false); [void][CP.U]::UpdateWindow($sc) }
				$times += $sw.Elapsed.TotalMilliseconds / $Paints
			}
			$result[$grid] = ($times | Sort-Object)[2]
			if ($grid -eq 'on') { [void](Send $p.MainWindowHandle 0x0111 44190) }
		}
		"{0}, {1}: grid off {2:N1} ms, on {3:N1} ms per paint ({4} lines on screen)" -f $sample[0], $tech[1], $result['off'], $result['on'], (Send $sc 2370)
	}
	Stop-Process -Id $p.Id -Force; [void]$p.WaitForExit(5000)
}
[IO.Directory]::Delete($dir, $true)
