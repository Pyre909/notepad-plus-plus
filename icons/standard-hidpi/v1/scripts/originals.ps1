# The standard toolbar icons enlarged (nearest neighbour) with their names, a grid of $PerRow. Windows PowerShell 5.1.
param([string] $IconDir, [string] $Out, [int] $Zoom = 10, [int] $PerRow = 8, [string[]] $Only)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$files = @(Get-ChildItem $IconDir -Filter *.bmp | Where-Object { $_.BaseName -ne 'playRecord_m' } | Sort-Object Name)
if ($Only) { $files = @($files | Where-Object { $Only -contains $_.BaseName }) }
$cell = 16 * $Zoom + 12; $lab = 16
$rows = [math]::Ceiling($files.Count / $PerRow)
$sheet = New-Object Drawing.Bitmap ($PerRow * $cell), ($rows * ($cell + $lab))
$g = [Drawing.Graphics]::FromImage($sheet); $g.Clear([Drawing.Color]::FromArgb(0xF0, 0xF0, 0xF0))
$g.InterpolationMode = 'NearestNeighbor'; $g.PixelOffsetMode = 'Half'
$font = New-Object Drawing.Font 'Segoe UI', 9
for ($i = 0; $i -lt $files.Count; $i++) {
	$x = ($i % $PerRow) * $cell; $y = [math]::Floor($i / $PerRow) * ($cell + $lab)
	$b = New-Object Drawing.Bitmap $files[$i].FullName
	$g.DrawImage($b, (New-Object Drawing.Rectangle ($x + 6), ($y + $lab), (16 * $Zoom), (16 * $Zoom)), (New-Object Drawing.Rectangle 0, 0, 16, 16), 'Pixel')
	$b.Dispose()
	$g.DrawString($files[$i].BaseName, $font, [Drawing.Brushes]::Black, ($x + 4), $y)
}
$g.Dispose(); $sheet.Save($Out, [Drawing.Imaging.ImageFormat]::Png); "$($files.Count) -> $Out"
