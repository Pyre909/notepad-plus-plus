param([Parameter(Mandatory)] [string] $Exe, [Parameter(Mandatory)] [string] $OutDir, [string] $ThemeDir = "$env:APPDATA\Notepad++\themes")
# Pyre909's text in Pyre909's themes (Pyre Daylight, Pyre Night: MonoLisa Code 10 pt) under each Text Rendering setting
# of Preferences > Editing 1, set in config.xml as Preferences writes it; each drawn by Notepad++ and captured at 1:1
# (crop-<n>.png), and a 4x detail of each (detail-<n>.png); a manifest of what each is (sheet.json)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -Namespace RS -Name U -MemberDefinition @'
[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr p, IntPtr after, string cls, string title);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
[DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
[DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int hh, bool repaint);
[DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr c);
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
[StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
'@
[void][RS.U]::SetThreadDpiAwarenessContext([IntPtr](-4))
function Send([IntPtr] $h, [int] $m, [long] $w = 0, [long] $l = 0) { $r = [IntPtr]::Zero; [void][RS.U]::SendMessageTimeout($h, $m, [IntPtr]$w, [IntPtr]$l, 2, 10000, [ref]$r); $r.ToInt64() }
New-Item -ItemType Directory -Force $OutDir | Out-Null
$utf8 = [Text.UTF8Encoding]::new($false)
$sample = Join-Path $OutDir 'sample.cpp'
$line1 = 'int total(const Order& o) { return o.qty * o.price; } // 0O 1lI|'
[IO.File]::WriteAllText($sample, (@(
	$line1,
	'if (x >= 10 && y != 0) { log("ok -> done"); }  // => <= !=',
	'Invoice 0042    12,345.67    2026-11-02    MMWW iijj',
	'The quick brown fox jumps over the lazy dog: {[()]} ;:,.'
) -join "`r`n") + "`r`n", $utf8)
# Preferences' names: technology 0 GDI, 1 DirectWrite; antialiasing 0 Follow Windows, 1 ClearType, 2 ClearType with
# less color fringing, 3 Grayscale, 4 None; DirectWrite mode 0 Automatic, 1 Natural, 2 Symmetric, 3 GDI classic;
# contrast 0 Follow Windows, 1 Medium, 2 High, 3 Very high
$aaNames = 'Follow Windows', 'ClearType', 'ClearType, less color', 'Grayscale', 'None'
$modeNames = 'Automatic', 'Natural', 'Symmetric', 'GDI classic'
$contrastNames = 'Follow Windows', 'Medium', 'High', 'Very high'
$variants = @(
	@{ T = 1; A = 0; M = 0; C = 0; Note = 'your current settings' },
	@{ T = 1; A = 1; M = 1; C = 0 }, @{ T = 1; A = 1; M = 2; C = 0 }, @{ T = 1; A = 1; M = 3; C = 0 },
	@{ T = 1; A = 2; M = 0; C = 0 }, @{ T = 1; A = 3; M = 0; C = 0 }, @{ T = 1; A = 4; M = 0; C = 0 },
	@{ T = 1; A = 0; M = 0; C = 1 }, @{ T = 1; A = 0; M = 0; C = 2 }, @{ T = 1; A = 0; M = 0; C = 3 },
	@{ T = 1; A = 3; M = 3; C = 0 },
	@{ T = 0; A = 1; M = 0; C = 0 }, @{ T = 0; A = 3; M = 0; C = 0 }, @{ T = 0; A = 4; M = 0; C = 0 })
$manifest = [Collections.Generic.List[object]]::new()
$n = 0
foreach ($theme in 'Pyre Daylight', 'Pyre Night') {
	$settings = Join-Path $env:TEMP ('npp-rs-' + [guid]::NewGuid().ToString('N').Substring(0, 6)); New-Item -ItemType Directory $settings | Out-Null
	Copy-Item -LiteralPath (Join-Path $ThemeDir "$theme.xml") (Join-Path $settings 'stylers.xml')
	# a first start and a normal close writes config.xml
	$p = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$settings" -PassThru
	for ($i = 0; $i -lt 100 -and $p.MainWindowHandle -eq 0; $i++) { Start-Sleep -Milliseconds 100; $p.Refresh() }
	Start-Sleep -Milliseconds 1500
	[void][RS.U]::PostMessage($p.MainWindowHandle, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero); [void]$p.WaitForExit(10000)
	$configPath = Join-Path $settings 'config.xml'
	$base = [IO.File]::ReadAllText($configPath)
	foreach ($v in $variants) {
		# the dark theme: the current settings, Natural, Grayscale, Very high contrast, GDI with ClearType
		if ($theme -eq 'Pyre Night' -and -not ($v.Note -or ($v.M -eq 1) -or ($v.T -eq 1 -and $v.A -eq 3 -and $v.M -eq 0) -or ($v.C -eq 3) -or ($v.T -eq 0 -and $v.A -eq 1))) { continue }
		$config = $base -replace 'writeTechnologyEngine="\d+"', "writeTechnologyEngine=`"$($v.T)`"" -replace ' smoothFont="[^"]*"', ''
		$config = $config -replace 'fontAntialiasing="\d+"', "fontAntialiasing=`"$($v.A)`"" -replace 'fontRenderingMode="\d+"', "fontRenderingMode=`"$($v.M)`"" -replace 'fontContrast="\d+"', "fontContrast=`"$($v.C)`""
		[IO.File]::WriteAllText($configPath, $config, $utf8)
		$p = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$settings", "`"$sample`"" -PassThru
		for ($i = 0; $i -lt 100 -and $p.MainWindowHandle -eq 0; $i++) { Start-Sleep -Milliseconds 100; $p.Refresh() }
		Start-Sleep -Milliseconds 1500
		$main = $p.MainWindowHandle
		[void][RS.U]::MoveWindow($main, 30, 30, 1200, 500, $true); Start-Sleep -Milliseconds 500
		$sc = [IntPtr]::Zero; $h = [IntPtr]::Zero
		while (($h = [RS.U]::FindWindowEx($main, $h, 'Scintilla', [NullString]::Value)) -ne [IntPtr]::Zero) { if ($sc -eq [IntPtr]::Zero -and [RS.U]::IsWindowVisible($h)) { $sc = $h } }
		[void](Send $sc 2025 (Send $sc 2006)); [void](Send $sc 2076 0); Start-Sleep -Milliseconds 300 # the caret at the end (off the sample's lines), no blinking
		$rm = [RS.U+RECT]::new(); [void][RS.U]::GetWindowRect($main, [ref]$rm)
		$o = [RS.U+POINT]::new(); [void][RS.U]::ClientToScreen($sc, [ref]$o)
		$bmp = [Drawing.Bitmap]::new($rm.Right - $rm.Left, $rm.Bottom - $rm.Top); $g = [Drawing.Graphics]::FromImage($bmp); $hdc = $g.GetHdc(); [void][RS.U]::PrintWindow($main, $hdc, 2); $g.ReleaseHdc($hdc); $g.Dispose()
		$x0 = $o.X - $rm.Left + (Send $sc 2164 0 0); $y0 = $o.Y - $rm.Top + (Send $sc 2165 0 0); $lh = Send $sc 2279 0
		$crop = $bmp.Clone([Drawing.Rectangle]::new([int]$x0, [int]$y0, 900, [int](4 * $lh)), $bmp.PixelFormat)
		$crop.Save((Join-Path $OutDir "crop-$n.png"))
		# the detail: "0O 1lI|" at the end of line 1, 4x
		$at = $line1.IndexOf('0O')
		$dx = $o.X - $rm.Left + (Send $sc 2164 0 $at); $dw = (Send $sc 2164 0 ($at + 7)) - (Send $sc 2164 0 $at) + 2
		$detail = $bmp.Clone([Drawing.Rectangle]::new([int]($dx - 1), [int]$y0, [int]$dw, [int]$lh), $bmp.PixelFormat)
		$big = [Drawing.Bitmap]::new([int]($dw * 4), [int]($lh * 4)); $gb = [Drawing.Graphics]::FromImage($big); $gb.InterpolationMode = 'NearestNeighbor'; $gb.PixelOffsetMode = 'Half'
		$gb.DrawImage($detail, 0, 0, $big.Width, $big.Height); $gb.Dispose(); $big.Save((Join-Path $OutDir "detail-$n.png"))
		$big.Dispose(); $detail.Dispose(); $crop.Dispose(); $bmp.Dispose()
		$label = if ($v.T -eq 0) { "GDI, antialiasing $($aaNames[$v.A])" } else { "DirectWrite, $($modeNames[$v.M]), antialiasing $($aaNames[$v.A]), contrast $($contrastNames[$v.C])" }
		$manifest.Add([pscustomobject]@{ N = $n; Theme = $theme; Label = $label; Note = $v.Note; Technology = $v.T; Antialiasing = $v.A; Mode = $v.M; Contrast = $v.C })
		Stop-Process -Id $p.Id -Force; [void]$p.WaitForExit(5000)
		$n++
	}
	Remove-Item -LiteralPath $settings -Recurse -Force
}
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $OutDir 'sheet.json') -Encoding utf8
"$n captures in $OutDir"
