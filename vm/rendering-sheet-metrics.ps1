param([Parameter(Mandatory)] [string] $Dir)
# Measures of the 4th line of each capture ("The quick brown fox jumps over the lazy dog", the default colour): colour
# fringing (the ink pixels' mean spread between their R, G and B, 0-255), solid ink (the share of the ink in pixels at
# least 90% covered: crisper stems), ink (the total coverage, to the first capture of the theme: weight)
Add-Type -AssemblyName System.Drawing
$rows = Get-Content -LiteralPath (Join-Path $Dir 'sheet.json') -Raw | ConvertFrom-Json
$first = @{}
foreach ($r in $rows) {
	$bmp = [Drawing.Bitmap]::new((Join-Path $Dir "crop-$($r.N).png"))
	$lh = [int]($bmp.Height / 4)
	$bg = $bmp.GetPixel($bmp.Width - 3, 3 * $lh + 2)
	$bgL = 0.2126 * $bg.R + 0.7152 * $bg.G + 0.0722 * $bg.B
	$fgL = if ($bgL -gt 128) { 0.2126 * 25 + 0.7152 * 30 + 0.0722 * 40 } else { 0.2126 * 0xDB + 0.7152 * 0xD5 + 0.0722 * 0xC9 }
	$ink = 0.0; $solid = 0.0; $chroma = 0.0; $count = 0
	for ($y = 3 * $lh; $y -lt 4 * $lh; $y++) {
		for ($x = 0; $x -lt 540; $x++) {
			$c = $bmp.GetPixel($x, $y)
			$cov = [Math]::Min(1.0, [Math]::Max(0.0, (0.2126 * $c.R + 0.7152 * $c.G + 0.0722 * $c.B - $bgL) / ($fgL - $bgL)))
			if ($cov -gt 0.05) {
				$ink += $cov; $count++
				if ($cov -ge 0.9) { $solid += $cov }
				$chroma += ([Math]::Max($c.R, [Math]::Max($c.G, $c.B)) - [Math]::Min($c.R, [Math]::Min($c.G, $c.B)))
			}
		}
	}
	$bmp.Dispose()
	if (-not $first.ContainsKey($r.Theme)) { $first[$r.Theme] = $ink }
	[pscustomobject]@{ N = $r.N + 1; Theme = $r.Theme; Setting = $r.Label; Fringing = [Math]::Round($chroma / $count, 1); Solid = [Math]::Round(100 * $solid / $ink); Ink = [Math]::Round(100 * $ink / $first[$r.Theme]) }
}
