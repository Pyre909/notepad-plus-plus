# The tab icons' pipeline: gen_tab.py -> svg\<name>-<size>.svg ; Inkscape -> png\ (one process an icon, all its sizes) ;
# oxipng ; ico\<name>.ico (PNG-compressed entries, its sizes).
$ErrorActionPreference = 'Stop'
$ink = 'C:\Program Files\Inkscape\bin\inkscape.com'
$ox = 'C:\Users\stephensamaniego\AppData\Local\Microsoft\WinGet\Packages\Shssoichiro.Oxipng_Microsoft.Winget.Source_8wekyb3d8bbwe\oxipng-10.2.1-x86_64-pc-windows-msvc\oxipng.exe'
Set-Location $PSScriptRoot
foreach ($d in 'svg', 'png', 'ico') { if (Test-Path $d) { Remove-Item -Recurse -Force -LiteralPath (Join-Path $PSScriptRoot $d) } }
New-Item -ItemType Directory png, ico | Out-Null
python gen_tab.py
$byIcon = Get-ChildItem svg -Filter *.svg | Group-Object { $_.BaseName -replace '-\d+$', '' }
foreach ($group in $byIcon) {
	$actions = ($group.Group | ForEach-Object {
		$size = [int]($_.BaseName -replace '^.*-', '')
		"file-open:$($_.FullName);export-width:$size;export-height:$size;export-filename:$PSScriptRoot\png\$($_.BaseName).png;export-do;file-close"
	}) -join ';'
	& $ink --actions="$actions" 2>&1 | Where-Object { $_ -match 'rror' }
}
& $ox -o max --strip all -q -r "$PSScriptRoot\png"
$total = 0
foreach ($group in $byIcon) {
	$files = $group.Group | Sort-Object { [int]($_.BaseName -replace '^.*-', '') }
	$pngs = $files | ForEach-Object { , [IO.File]::ReadAllBytes("$PSScriptRoot\png\$($_.BaseName).png") }
	$sizes = $files | ForEach-Object { [int]($_.BaseName -replace '^.*-', '') }
	$ms = New-Object IO.MemoryStream; $w = New-Object IO.BinaryWriter $ms
	$w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]$sizes.Count)
	$offset = 6 + 16 * $sizes.Count
	for ($i = 0; $i -lt $sizes.Count; $i++) {
		$b = [byte]($sizes[$i] % 256)
		$w.Write($b); $w.Write($b); $w.Write([byte]0); $w.Write([byte]0); $w.Write([uint16]1); $w.Write([uint16]32)
		$w.Write([uint32]$pngs[$i].Length); $w.Write([uint32]$offset); $offset += $pngs[$i].Length
	}
	foreach ($p in $pngs) { $w.Write($p) }
	$w.Flush(); [IO.File]::WriteAllBytes("$PSScriptRoot\ico\$($group.Name).ico", $ms.ToArray()); $total += $ms.Length
}
"{0} icons, {1:N1} KB in all" -f $byIcon.Count, ($total / 1KB)
