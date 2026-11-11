# Review sheet: each icon, the current one (its 16 or 11 px frame stretched as Windows does) then the new one, at the sizes
# of 100%, 150% and 200%, enlarged (nearest neighbour) on the editor's cream.
param([string] $Old, [string] $Out, [int] $Zoom = 5)
Add-Type -AssemblyName System.Drawing
$new = Join-Path $PSScriptRoot 'png'
$docs = 'saved', 'unsaved', 'readonly', 'readonly_sys', 'monitoring', 'saved_alt', 'unsaved_alt', 'readonly_alt', 'readonly_sys_alt'
$btns = 'closeTabButton', 'closeTabButton_hoverOnTab', 'closeTabButton_hoverIn', 'closeTabButton_push', 'pinTabButton', 'pinTabButton_pinned'
$rows = @($docs | ForEach-Object { @{ Name = $_; Sizes = 16, 24, 32 } }) + @($btns | ForEach-Object { @{ Name = $_; Sizes = 11, 17, 22 } })
$colW = 32 * $Zoom + 12; $rowH = 32 * $Zoom + 8
$bmp = [Drawing.Bitmap]::new(170 + $colW * 6, $rowH * $rows.Count + 24)
$g = [Drawing.Graphics]::FromImage($bmp); $g.Clear([Drawing.Color]::White)
$g.InterpolationMode = 'NearestNeighbor'; $g.PixelOffsetMode = 'Half'
$font = [Drawing.Font]::new('Segoe UI', 9); $cream = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(0xFC, 0xFC, 0xF9))
$x = 170; foreach ($h in 'now 100%', 'new 100%', 'now 150%', 'new 150%', 'now 200%', 'new 200%') { $g.DrawString($h, $font, [Drawing.Brushes]::Black, $x, 4); $x += $colW }
for ($r = 0; $r -lt $rows.Count; $r++) {
	$row = $rows[$r]; $y = 24 + $r * $rowH
	$g.DrawString($row.Name, $font, [Drawing.Brushes]::Black, 4, $y + 10)
	$col = 0
	foreach ($size in $row.Sizes) {
		$icon = [Drawing.Icon]::new((Join-Path $Old "$($row.Name).ico"), 256, 256); $small = $icon.ToBitmap(); $icon.Dispose()
		$stretched = [Drawing.Bitmap]::new($size, $size); $gs = [Drawing.Graphics]::FromImage($stretched)
		$gs.InterpolationMode = 'HighQualityBicubic'; $gs.DrawImage($small, 0, 0, $size, $size); $gs.Dispose(); $small.Dispose()
		$fresh = [Drawing.Bitmap]::new((Join-Path $new "$($row.Name)-$size.png"))
		foreach ($img in $stretched, $fresh) {
			$x = 170 + $col * $colW
			$g.FillRectangle($cream, $x, $y, $size * $Zoom, $size * $Zoom)
			$g.DrawImage($img, $x, $y, $size * $Zoom, $size * $Zoom)
			$col++
		}
		$stretched.Dispose(); $fresh.Dispose()
	}
}
$g.Dispose(); $bmp.Save($Out); $bmp.Dispose()
