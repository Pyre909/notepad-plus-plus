param([Parameter(Mandatory)] [string] $Exe, [string] $Font = 'MonoLisaCode', [int] $Size = 10, [string] $Theme = '', [int] $Zoom = 0, [string] $SaveTo = '')
# Whole-pixel cells, measured: the grid's cell width, and how many different renderings one character gets across 24
# columns (each cell's pixels compared, from where its glyph starts), for 0, m and a CJK character, DirectWrite and GDI
Add-Type -AssemblyName System.Drawing
Add-Type -Namespace CPh -Name U -MemberDefinition @'
[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr p, IntPtr after, string cls, string title);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
[DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
[DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr c);
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
[StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
'@
[void][CPh.U]::SetThreadDpiAwarenessContext([IntPtr](-4))
function Send([IntPtr] $h, [int] $m, [long] $w = 0, [long] $l = 0) { $r = [IntPtr]::Zero; [void][CPh.U]::SendMessageTimeout($h, $m, [IntPtr]$w, [IntPtr]$l, 2, 10000, [ref]$r); $r.ToInt64() }
$dir = Join-Path $env:TEMP ('npp-cph-' + [guid]::NewGuid().ToString('N').Substring(0, 6)); New-Item -ItemType Directory $dir | Out-Null
$model = [IO.File]::ReadAllText($(if ($Theme) { $Theme } else { Join-Path (Split-Path $Exe) 'stylers.model.xml' }))
$model = [regex]::Replace($model, '(<WidgetStyle name="Default Style" styleID="32"[^>]*?fontName=")[^"]*("[^>]*?fontSize=")[^"]*"', "`${1}$Font`${2}$Size`"")
[IO.File]::WriteAllText((Join-Path $dir 'stylers.xml'), $model, [Text.UTF8Encoding]::new($false))
$file = Join-Path $dir 'c.txt'
$samples = @(('0' * 24), ('m' * 24), (([string][char]0x4E2D) * 24))
[IO.File]::WriteAllText($file, ((' ' * 160) + "X`r`n" + ($samples -join "`r`n") + "`r`n"), [Text.UTF8Encoding]::new($false))
$p = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$dir", "`"$file`"" -PassThru
for ($i = 0; $i -lt 100 -and $p.MainWindowHandle -eq 0; $i++) { Start-Sleep -Milliseconds 100; $p.Refresh() }
Start-Sleep -Milliseconds 1500
$main = $p.MainWindowHandle
$sc = [IntPtr]::Zero; $h = [IntPtr]::Zero
while (($h = [CPh.U]::FindWindowEx($main, $h, 'Scintilla', [NullString]::Value)) -ne [IntPtr]::Zero) { if ($sc -eq [IntPtr]::Zero -and [CPh.U]::IsWindowVisible($h)) { $sc = $h } }
[void](Send $sc 2025 0); [void](Send $sc 2373 $Zoom)
foreach ($grid in 'off', 'on') {
	if ($grid -eq 'on') { [void](Send $main 0x0111 44190) }
	foreach ($tech in @(@(1, 'DirectWrite'), @(0, 'GDI'))) {
		[void](Send $sc 2630 $tech[0]); Start-Sleep -Milliseconds 500
		$p0 = Send $sc 2167 0
		$cell = ((Send $sc 2164 0 ($p0 + 160)) - (Send $sc 2164 0 $p0)) / 160.0
		$rm = [CPh.U+RECT]::new(); [void][CPh.U]::GetWindowRect($main, [ref]$rm)
		$o = [CPh.U+POINT]::new(); [void][CPh.U]::ClientToScreen($sc, [ref]$o)
		$bmp = [Drawing.Bitmap]::new($rm.Right - $rm.Left, $rm.Bottom - $rm.Top); $g = [Drawing.Graphics]::FromImage($bmp); $hdc = $g.GetHdc(); [void][CPh.U]::PrintWindow($main, $hdc, 2); $g.ReleaseHdc($hdc); $g.Dispose()
		$height = Send $sc 2279 1
		$results = foreach ($line in 1..3) {
			$start = Send $sc 2167 $line
			$y = $o.Y - $rm.Top + (Send $sc 2165 0 $start)
			$xs = @(); $pos = $start; for ($k = 0; $k -le 24; $k++) { $xs += (Send $sc 2164 0 $pos); $pos = Send $sc 2418 $pos 1 }
			$w = [int][Math]::Floor(($xs[24] - $xs[0]) / 24.0)
			$kinds = @{}
			for ($k = 0; $k -lt 24; $k++) {
				# the cell's pixels from the whole pixel its position falls in (positions are truncated, as drawn on whole pixels)
				$sb = [Text.StringBuilder]::new()
				for ($yy = 0; $yy -lt $height; $yy++) { for ($xx = 0; $xx -lt $w; $xx++) { [void]$sb.Append($bmp.GetPixel($o.X - $rm.Left + $xs[$k] + $xx, $y + $yy).ToArgb()) } }
				$kinds[$sb.ToString()] = 1
			}
			"{0}: {1} rendering(s), advance {2:N3} px" -f @('0', 'm', 'CJK')[$line - 1], $kinds.Count, (($xs[24] - $xs[0]) / 24.0)
		}
		if ($SaveTo) { $crop = $bmp.Clone([Drawing.Rectangle]::new($o.X - $rm.Left, $o.Y - $rm.Top + (Send $sc 2165 0 (Send $sc 2167 1)), 360, $height), $bmp.PixelFormat); $crop.Save("$SaveTo-$grid-$($tech[1]).png"); $crop.Dispose() }
		$bmp.Dispose()
		"grid {0}, {1}: cell {2:N3} px; {3}" -f $grid, $tech[1], $cell, ($results -join '; ')
	}
}
Stop-Process -Id $p.Id -Force; [void]$p.WaitForExit(5000)
[IO.Directory]::Delete($dir, $true)
