# A contact sheet of the current tab icons (their largest frame, enlarged without smoothing), on white and on the
# editor's cream, each named.
param([string] $Dir, [string] $Out, [int] $Zoom = 6)
Add-Type -AssemblyName System.Drawing
$names = 'saved', 'unsaved', 'readonly', 'readonly_sys', 'monitoring', 'saved_alt', 'unsaved_alt', 'readonly_alt', 'readonly_sys_alt',
	'closeTabButton', 'closeTabButton_hoverOnTab', 'closeTabButton_hoverIn', 'closeTabButton_push', 'pinTabButton', 'pinTabButton_pinned'
$cell = 16 * $Zoom + 20
$bmp = [Drawing.Bitmap]::new($cell * 5, ($cell + 18) * 3)
$g = [Drawing.Graphics]::FromImage($bmp); $g.Clear([Drawing.Color]::White)
$g.InterpolationMode = 'NearestNeighbor'; $g.PixelOffsetMode = 'Half'
$font = [Drawing.Font]::new('Segoe UI', 8)
for ($i = 0; $i -lt $names.Count; $i++) {
	$x = ($i % 5) * $cell; $y = [Math]::Floor($i / 5) * ($cell + 18)
	$icon = [Drawing.Icon]::new((Join-Path $Dir "$($names[$i]).ico"), 256, 256)
	$b = $icon.ToBitmap()
	$g.FillRectangle([Drawing.Brushes]::Beige, $x + 4, $y + 4, $b.Width * $Zoom, $b.Height * $Zoom)
	$g.DrawImage($b, $x + 4, $y + 4, $b.Width * $Zoom, $b.Height * $Zoom)
	$g.DrawString("$($names[$i]) ($($b.Width))", $font, [Drawing.Brushes]::Black, $x + 2, $y + $cell - 2)
	$b.Dispose(); $icon.Dispose()
}
$g.Dispose(); $bmp.Save($Out); $bmp.Dispose()
