# The standard toolbar in its order at true size: now (BMP stretched as LoadImage does) and redrawn, at 150% and 200%.
param([string] $Orig = 'C:\Users\stephensamaniego\src\npp\PowerEditor\src\icons\standard\toolbar', [string] $Out = "$PSScriptRoot\strip.png")
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$order = 'newFile','openFile','saveFile','saveAll','closeFile','closeAll','print','|','cut','copy','paste','|','undo','redo','|','find','findReplace','|','zoomIn','zoomOut','|','syncV','syncH','|','wrap','allChars','indentGuide','|','udl','docMap','docList','funcList','fileBrowser','monitoring','|','startRecord','stopRecord','playRecord','playRecord_m','saveRecord'
$face = [Drawing.Color]::FromArgb(0xF0, 0xF0, 0xF0)
function Old([string] $name, [int] $n) {
	$b = New-Object Drawing.Bitmap (Join-Path $Orig "$name.bmp"); $key = $b.GetPixel(0, 0).ToArgb()
	$o = New-Object Drawing.Bitmap $n, $n
	for ($y = 0; $y -lt $n; $y++) { for ($x = 0; $x -lt $n; $x++) {
		$c = $b.GetPixel([int][math]::Floor($x * 16 / $n), [int][math]::Floor($y * 16 / $n))
		if ($c.ToArgb() -eq $key -or ($c.R -eq 192 -and $c.G -eq 192 -and $c.B -eq 192)) { $c = $face }
		$o.SetPixel($x, $y, $c) } }
	$b.Dispose(); return $o
}
$rows = @(@{ T = 'now, 150%'; N = 24; New = $false }, @{ T = 'redrawn, 150%'; N = 24; New = $true }, @{ T = 'now, 200%'; N = 32; New = $false }, @{ T = 'redrawn, 200%'; N = 32; New = $true })
$width = [int] 110 + [int] ($order | ForEach-Object { if ($_ -eq '|') { 10 } else { 32 + 10 } } | Measure-Object -Sum).Sum
$sheet = New-Object Drawing.Bitmap ([int]$width), ([int]($rows.Count * 46 + 4))
$g = [Drawing.Graphics]::FromImage($sheet); $g.Clear($face)
$font = New-Object Drawing.Font 'Segoe UI', 9; $pen = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(0xC8, 0xC8, 0xC8))
for ($r = 0; $r -lt $rows.Count; $r++) {
	$row = $rows[$r]; $y = 4 + $r * 46; $x = 110
	$g.DrawString($row.T, $font, [Drawing.Brushes]::Black, 4, ($y + 10))
	foreach ($name in $order) {
		if ($name -eq '|') { $g.DrawLine($pen, ($x + 4), ($y + 4), ($x + 4), ($y + 36)); $x += 10; continue }
		$img = if ($row.New) { [Drawing.Image]::FromFile("$PSScriptRoot\png\$name-$($row.N).png") } else { Old $name $row.N }
		$off = [int]((40 - $row.N) / 2)
		$g.DrawImage($img, ($x + $off - 4), ($y + $off), $row.N, $row.N); $img.Dispose()
		$x += 42
	}
}
$g.Dispose(); $sheet.Save($Out, [Drawing.Imaging.ImageFormat]::Png); "-> $Out"

