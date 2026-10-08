# The whole pipeline: gen.py -> src16\, src20\, src24\, src32\ ; Inkscape: plain SVG -> svg16\, svg20\, svg24\, svg\ (the
# 32 grid) ; PNGs: each size from its grid, 40 and 48 from the 20 and 24 grids doubled -> png\ ; oxipng ; pack.ps1 -> ico\.
$ErrorActionPreference = 'Stop'
$ink = 'C:\Program Files\Inkscape\bin\inkscape.com'
$ox = 'C:\Users\stephensamaniego\AppData\Local\Microsoft\WinGet\Packages\Shssoichiro.Oxipng_Microsoft.Winget.Source_8wekyb3d8bbwe\oxipng-10.2.1-x86_64-pc-windows-msvc\oxipng.exe'
Set-Location $PSScriptRoot
python gen.py
foreach ($d in 'svg16', 'svg20', 'svg24', 'svg', 'png', 'ico') { if (Test-Path $d) { Remove-Item -Recurse -Force $d }; New-Item -ItemType Directory $d | Out-Null }
$masters = @{ 16 = @{ Src = 'src16'; Out = 'svg16'; Sizes = @(16) }; 20 = @{ Src = 'src20'; Out = 'svg20'; Sizes = @(20, 40) };
	24 = @{ Src = 'src24'; Out = 'svg24'; Sizes = @(24, 48) }; 32 = @{ Src = 'src32'; Out = 'svg'; Sizes = @(32) } }
foreach ($g in 16, 20, 24, 32) {
	$m = $masters[$g]
	foreach ($f in Get-ChildItem $m.Src -Filter *.svg) {
		$plain = Join-Path $PSScriptRoot "$($m.Out)\$($f.Name)"
		& $ink --export-plain-svg --export-text-to-path --export-filename="$plain" $f.FullName 2>&1 | Where-Object { $_ -match 'rror' }
		$actions = ($m.Sizes | ForEach-Object { "export-width:$_;export-height:$_;export-filename:$PSScriptRoot\png\$($f.BaseName)-$_.png;export-do" }) -join ';'
		& $ink --actions="$actions" $plain 2>&1 | Where-Object { $_ -match 'rror' }
	}
}
& "$PSScriptRoot\disabled.ps1"
& $ox -o max --strip all -q -r "$PSScriptRoot\png"
& "$PSScriptRoot\pack.ps1"
'texts left in the final SVGs: ' + @(Select-String -Path "svg\*.svg", "svg16\*.svg", "svg20\*.svg", "svg24\*.svg" -Pattern '<text').Count
