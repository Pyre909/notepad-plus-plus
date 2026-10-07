# Diagnostic sheets for a critique of the redrawn icons. Windows PowerShell 5.1.
# zoom.png: per icon, the original 16 and the redraw at 16, 20, 24 (each zoomed 4x, pixels visible).
# context.png: the redraw at 24 and 32 at true size on the toolbar colour, on the hover blue, on white, and greyed.
param([string] $Orig = 'C:\Users\stephensamaniego\src\npp\PowerEditor\src\icons\standard\toolbar')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$names = @(Get-ChildItem "$PSScriptRoot\svg" -Filter *.svg | Sort-Object Name | ForEach-Object BaseName)
$face = [Drawing.Color]::FromArgb(0xF0, 0xF0, 0xF0)
$font = New-Object Drawing.Font 'Segoe UI', 8

# zoom.png: 4 columns of icons, each cell: orig16 | new16 | new20 | new24 at 4x
$z = 4; $cellW = (16 + 16 + 20 + 24) * $z + 40; $cellH = 24 * $z + 18; $perRow = 2
$rows = [math]::Ceiling($names.Count / $perRow)
$sheet = New-Object Drawing.Bitmap ([int]($perRow * $cellW)), ([int]($rows * $cellH))
$g = [Drawing.Graphics]::FromImage($sheet); $g.Clear($face); $g.InterpolationMode = 'NearestNeighbor'; $g.PixelOffsetMode = 'Half'
for ($i = 0; $i -lt $names.Count; $i++) {
	$n = $names[$i]; $x = ($i % $perRow) * $cellW; $y = [math]::Floor($i / $perRow) * $cellH
	$g.DrawString("$n  (orig 16 | new 16 | 20 | 24)", $font, [Drawing.Brushes]::Black, $x + 2, $y)
	$o = New-Object Drawing.Bitmap (Join-Path $Orig "$n.bmp")
	$imgs = @($o, [Drawing.Image]::FromFile("$PSScriptRoot\png\$n-16.png"), [Drawing.Image]::FromFile("$PSScriptRoot\png\$n-20.png"), [Drawing.Image]::FromFile("$PSScriptRoot\png\$n-24.png"))
	$cx = $x + 4
	foreach ($im in $imgs) {
		$g.DrawImage($im, (New-Object Drawing.Rectangle $cx, ($y + 14), ($im.Width * $z), ($im.Height * $z)), (New-Object Drawing.Rectangle 0, 0, $im.Width, $im.Height), 'Pixel')
		$cx += $im.Width * $z + 10; $im.Dispose()
	}
}
$g.Dispose(); $sheet.Save("$PSScriptRoot\zoom.png", [Drawing.Imaging.ImageFormat]::Png)

# context.png: rows = backgrounds; within a row all icons at 24 then all at 32
$bgs = @(@{ T = 'toolbar'; C = $face; Grey = $false }, @{ T = 'hover'; C = [Drawing.Color]::FromArgb(0xCC, 0xE8, 0xFF); Grey = $false },
	@{ T = 'white'; C = [Drawing.Color]::White; Grey = $false }, @{ T = 'greyed'; C = $face; Grey = $true })
$w = 70 + $names.Count * 28 + 20 + $names.Count * 36
$ctx = New-Object Drawing.Bitmap ([int]$w), ([int]($bgs.Count * 42))
$g = [Drawing.Graphics]::FromImage($ctx); $g.Clear([Drawing.Color]::FromArgb(0xD8, 0xD8, 0xD8))
$cm = New-Object Drawing.Imaging.ColorMatrix
$cm.Matrix00 = 0.3; $cm.Matrix01 = 0.3; $cm.Matrix02 = 0.3; $cm.Matrix10 = 0.59; $cm.Matrix11 = 0.59; $cm.Matrix12 = 0.59
$cm.Matrix20 = 0.11; $cm.Matrix21 = 0.11; $cm.Matrix22 = 0.11; $cm.Matrix33 = 0.45; $cm.Matrix44 = 1
$grey = New-Object Drawing.Imaging.ImageAttributes; $grey.SetColorMatrix($cm)
for ($r = 0; $r -lt $bgs.Count; $r++) {
	$b = $bgs[$r]; $y = $r * 42
	$g.FillRectangle((New-Object Drawing.SolidBrush $b.C), 0, $y, $w, 40)
	$g.DrawString($b.T, $font, [Drawing.Brushes]::Black, 2, $y + 14)
	$x = 70
	foreach ($size in 24, 32) {
		foreach ($n in $names) {
			$im = [Drawing.Image]::FromFile("$PSScriptRoot\png\$n-$size.png")
			$dst = New-Object Drawing.Rectangle $x, ($y + [int]((40 - $size) / 2)), $size, $size
			if ($b.Grey) { $g.DrawImage($im, $dst, 0, 0, $size, $size, 'Pixel', $grey) } else { $g.DrawImage($im, $dst) }
			$im.Dispose(); $x += $size + 4
		}
		$x += 20
	}
}
$g.Dispose(); $ctx.Save("$PSScriptRoot\context.png", [Drawing.Imaging.ImageFormat]::Png)
'zoom.png, context.png'
