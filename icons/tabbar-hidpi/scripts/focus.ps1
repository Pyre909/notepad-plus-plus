# A few icons at their small sizes, enlarged a lot (nearest neighbour) on the editor's cream: a pixel-level look.
param([string[]] $Names, [int[]] $Sizes, [string] $Out, [int] $Zoom = 12)
Add-Type -AssemblyName System.Drawing
$png = Join-Path $PSScriptRoot 'png'
$cell = [int](($Sizes | Measure-Object -Maximum).Maximum * $Zoom + 16)
$bmp = [Drawing.Bitmap]::new($cell * $Sizes.Count, $cell * $Names.Count)
$g = [Drawing.Graphics]::FromImage($bmp); $g.Clear([Drawing.Color]::White)
$g.InterpolationMode = 'NearestNeighbor'; $g.PixelOffsetMode = 'Half'
$cream = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(0xFC, 0xFC, 0xF9))
for ($r = 0; $r -lt $Names.Count; $r++) {
	for ($c = 0; $c -lt $Sizes.Count; $c++) {
		$file = Join-Path $png "$($Names[$r])-$($Sizes[$c]).png"
		if (-not (Test-Path $file)) { continue }
		$img = [Drawing.Bitmap]::new($file)
		$g.FillRectangle($cream, $c * $cell, $r * $cell, $img.Width * $Zoom, $img.Height * $Zoom)
		$g.DrawImage($img, $c * $cell, $r * $cell, $img.Width * $Zoom, $img.Height * $Zoom); $img.Dispose()
	}
}
$g.Dispose(); $bmp.Save($Out); $bmp.Dispose()
