param([Parameter(Mandatory)] [string] $Dir)
# The captures of rendering-sheet.ps1 on one sheet a theme: a label, the 1:1 crop (judge sharpness at 100%, inside
# Windows) and the 4x detail of "0O 1lI|" beside it
Add-Type -AssemblyName System.Drawing
$rows = Get-Content -LiteralPath (Join-Path $Dir 'sheet.json') -Raw | ConvertFrom-Json
foreach ($theme in ($rows | Select-Object -ExpandProperty Theme -Unique)) {
	$these = @($rows | Where-Object Theme -eq $theme)
	$images = foreach ($r in $these) { [pscustomobject]@{ Row = $r; Crop = [Drawing.Bitmap]::new((Join-Path $Dir "crop-$($r.N).png")); Detail = [Drawing.Bitmap]::new((Join-Path $Dir "detail-$($r.N).png")) } }
	$labelHeight = 30; $gap = 18
	$width = ($images | ForEach-Object { $_.Crop.Width + 24 + $_.Detail.Width } | Measure-Object -Maximum).Maximum + 32
	$height = 60 + ($images | ForEach-Object { $labelHeight + [Math]::Max($_.Crop.Height, $_.Detail.Height) + $gap } | Measure-Object -Sum).Sum
	$sheet = [Drawing.Bitmap]::new([int]$width, [int]$height)
	$g = [Drawing.Graphics]::FromImage($sheet); $g.Clear([Drawing.Color]::FromArgb(236, 236, 232)); $g.TextRenderingHint = 'ClearTypeGridFit'
	$titleFont = [Drawing.Font]::new('Segoe UI Semibold', 13, [Drawing.GraphicsUnit]::Pixel); $font = [Drawing.Font]::new('Segoe UI', 12, [Drawing.GraphicsUnit]::Pixel)
	$g.DrawString("$theme, MonoLisa Code 10 pt: each Text Rendering setting (Preferences > Editing 1). View at 100% inside Windows; 4x detail on the right.", $titleFont, [Drawing.Brushes]::Black, 16, 18)
	$y = 60
	foreach ($im in $images) {
		$text = "$($im.Row.N + 1). $($im.Row.Label)" + $(if ($im.Row.Note) { "  ($($im.Row.Note))" } else { '' })
		$g.DrawString($text, $font, [Drawing.Brushes]::Black, 16, $y + 8)
		$y += $labelHeight
		$g.DrawImage($im.Crop, 16, $y, $im.Crop.Width, $im.Crop.Height)
		$g.DrawImage($im.Detail, 16 + $im.Crop.Width + 24, $y, $im.Detail.Width, $im.Detail.Height)
		$y += [Math]::Max($im.Crop.Height, $im.Detail.Height) + $gap
	}
	$g.Dispose()
	$out = Join-Path $Dir ("rendering-settings-{0}.png" -f ($theme -replace '\s', '-').ToLower())
	$sheet.Save($out); $sheet.Dispose()
	$images | ForEach-Object { $_.Crop.Dispose(); $_.Detail.Dispose() }
	$out
}
