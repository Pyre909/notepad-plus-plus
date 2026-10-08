# A few icons up close: the original 16x16 bitmap, then the redraw at each size, each zoomed to the same cell, with the
# pixel grid's centre lines marked. Windows PowerShell 5.1.
param([string[]] $Names = @('startRecord','stopRecord','playRecord','playRecord_m','saveRecord','wrap','find','findReplace'),
	[string] $Dir = "$PSScriptRoot\png", [int] $Cell = 144, [string] $Out = "$PSScriptRoot\focus.png",
	[string] $Orig = 'C:\Users\stephensamaniego\src\npp\PowerEditor\src\icons\standard\toolbar')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$sizes = 16, 20, 24, 32, 40, 48
$face = [Drawing.Color]::FromArgb(0xF0, 0xF0, 0xF0)
$cols = 1 + $sizes.Count; $rowH = $Cell + 22
$sheet = New-Object Drawing.Bitmap ([int](110 + $cols * ($Cell + 8))), ([int]($Names.Count * $rowH + 20))
$g = [Drawing.Graphics]::FromImage($sheet); $g.Clear($face); $g.InterpolationMode = 'NearestNeighbor'; $g.PixelOffsetMode = 'Half'
$font = New-Object Drawing.Font 'Segoe UI', 8
$pen = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(110, 255, 0, 255)), 1
$x = 110
foreach ($t in @('orig 16') + ($sizes | ForEach-Object { "$_" })) { $g.DrawString($t, $font, [Drawing.Brushes]::Black, $x, 2); $x += $Cell + 8 }
for ($r = 0; $r -lt $Names.Count; $r++) {
	$n = $Names[$r]; $y = 20 + $r * $rowH
	$g.DrawString($n, $font, [Drawing.Brushes]::Black, 2, $y + $Cell / 2)
	$imgs = @()
	$bmp = New-Object Drawing.Bitmap (Join-Path $Orig "$n.bmp"); $o = New-Object Drawing.Bitmap 16, 16; $key = $bmp.GetPixel(0, 0).ToArgb()
	for ($yy = 0; $yy -lt 16; $yy++) { for ($xx = 0; $xx -lt 16; $xx++) { $c = $bmp.GetPixel($xx, $yy); if ($c.ToArgb() -eq $key -or ($c.R -eq 192 -and $c.G -eq 192 -and $c.B -eq 192)) { $c = $face }; $o.SetPixel($xx, $yy, $c) } }
	$bmp.Dispose(); $imgs += ,$o
	foreach ($s in $sizes) {
		$src = [Drawing.Image]::FromFile("$Dir\$n-$s.png"); $b = New-Object Drawing.Bitmap $s, $s
		$gg = [Drawing.Graphics]::FromImage($b); $gg.Clear($face); $gg.DrawImage($src, 0, 0, $s, $s); $gg.Dispose(); $src.Dispose(); $imgs += ,$b
	}
	$x = 110
	foreach ($im in $imgs) {
		$g.DrawImage($im, (New-Object Drawing.Rectangle $x, $y, $Cell, $Cell), (New-Object Drawing.Rectangle 0, 0, $im.Width, $im.Height), 'Pixel')
		$g.DrawLine($pen, $x + $Cell / 2, $y, $x + $Cell / 2, $y + $Cell); $g.DrawLine($pen, $x, $y + $Cell / 2, $x + $Cell, $y + $Cell / 2)
		$x += $Cell + 8; $im.Dispose()
	}
}
$g.Dispose(); $sheet.Save($Out, [Drawing.Imaging.ImageFormat]::Png); "-> $Out"
