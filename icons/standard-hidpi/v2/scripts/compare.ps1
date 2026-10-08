# Two versions of the redrawn icons side by side, in toolbar order: rows <A> and <B> at 24 px (150%) and 32 px (200%),
# drawn at true size and again zoomed. Windows PowerShell 5.1.
param([string] $A = "$PSScriptRoot\..\hidpi-v1\png", [string] $B = "$PSScriptRoot\png", [string] $LabelA = 'v1', [string] $LabelB = 'v2',
	[int] $Zoom = 2, [string] $Out = "$PSScriptRoot\compare.png")
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$order = 'newFile','openFile','saveFile','saveAll','closeFile','closeAll','print','|','cut','copy','paste','|','undo','redo','|','find','findReplace','|','zoomIn','zoomOut','|','syncV','syncH','|','wrap','allChars','indentGuide','|','udl','docMap','docList','funcList','fileBrowser','monitoring','|','startRecord','stopRecord','playRecord','playRecord_m','saveRecord'
$face = [Drawing.Color]::FromArgb(0xF0, 0xF0, 0xF0)
$rows = @(@{ T = "$LabelA 150%"; D = $A; N = 24 }, @{ T = "$LabelB 150%"; D = $B; N = 24 }, @{ T = "$LabelA 200%"; D = $A; N = 32 }, @{ T = "$LabelB 200%"; D = $B; N = 32 })
$icons = @($order | Where-Object { $_ -ne '|' })
$w1 = [int](80 + ($order | ForEach-Object { if ($_ -eq '|') { 10 } else { 42 } } | Measure-Object -Sum).Sum)
$half = [int][math]::Ceiling($icons.Count / 2)
$w2 = [int](80 + $half * (32 * $Zoom + 6))
$width = [int][math]::Max($w1, $w2)
$height = [int]($rows.Count * 44 + 2 * $rows.Count * (32 * $Zoom + 8) + 30)
$sheet = New-Object Drawing.Bitmap $width, $height
$g = [Drawing.Graphics]::FromImage($sheet); $g.Clear($face); $g.InterpolationMode = 'NearestNeighbor'; $g.PixelOffsetMode = 'Half'
$font = New-Object Drawing.Font 'Segoe UI', 9; $pen = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(0xC8, 0xC8, 0xC8))
$y = 4
foreach ($row in $rows) {   # true size
	$g.DrawString($row.T, $font, [Drawing.Brushes]::Black, 4, ($y + 10)); $x = 80
	foreach ($name in $order) {
		if ($name -eq '|') { $g.DrawLine($pen, ($x + 4), ($y + 4), ($x + 4), ($y + 36)); $x += 10; continue }
		$img = [Drawing.Image]::FromFile("$($row.D)\$name-$($row.N).png"); $off = [int]((40 - $row.N) / 2)
		$g.DrawImage($img, ($x + $off - 4), ($y + $off), $row.N, $row.N); $img.Dispose(); $x += 42
	}
	$y += 44
}
$y += 20
foreach ($part in 0, 1) {   # zoomed, in two halves
	$set = if ($part -eq 0) { $icons[0..($half - 1)] } else { $icons[$half..($icons.Count - 1)] }
	foreach ($row in $rows) {
		$g.DrawString("$($row.T) x$Zoom", $font, [Drawing.Brushes]::Black, 4, ($y + 10)); $x = 80
		foreach ($name in $set) {
			$img = [Drawing.Image]::FromFile("$($row.D)\$name-$($row.N).png")
			$g.DrawImage($img, (New-Object Drawing.Rectangle $x, $y, ($row.N * $Zoom), ($row.N * $Zoom)), (New-Object Drawing.Rectangle 0, 0, $row.N, $row.N), 'Pixel')
			$img.Dispose(); $x += 32 * $Zoom + 6
		}
		$y += 32 * $Zoom + 8
	}
}
$g.Dispose(); $sheet.Save($Out, [Drawing.Imaging.ImageFormat]::Png); "-> $Out"
