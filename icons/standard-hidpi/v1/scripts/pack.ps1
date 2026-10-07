# Packs png\<name>-<size>.png into ico\<name>.ico, and png\<name>_dis-<size>.png into ico\<name>_dis.ico (PNG-compressed
# entries, Windows Vista and later), each icon of svg\.
param([int[]] $Sizes = @(16, 20, 24, 32, 40, 48))
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force "$PSScriptRoot\ico" | Out-Null
$total = 0
$names = @(Get-ChildItem "$PSScriptRoot\svg" -Filter *.svg | Sort-Object Name | ForEach-Object BaseName)
foreach ($base in $names + ($names | ForEach-Object { "$($_)_dis" })) {
	if (-not (Test-Path "$PSScriptRoot\png\$base-$($Sizes[0]).png")) { continue }
	$pngs = $Sizes | ForEach-Object { , [IO.File]::ReadAllBytes("$PSScriptRoot\png\$base-$_.png") }
	$ms = New-Object IO.MemoryStream; $w = New-Object IO.BinaryWriter $ms
	$w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]$Sizes.Count)   # ICONDIR: reserved, type icon, count
	$offset = 6 + 16 * $Sizes.Count
	for ($i = 0; $i -lt $Sizes.Count; $i++) {
		$n = $Sizes[$i]; $b = [byte]($n % 256)                                 # 256 is written 0
		$w.Write($b); $w.Write($b); $w.Write([byte]0); $w.Write([byte]0)          # width, height, palette, reserved
		$w.Write([uint16]1); $w.Write([uint16]32)                                 # planes, bits per pixel
		$w.Write([uint32]$pngs[$i].Length); $w.Write([uint32]$offset)
		$offset += $pngs[$i].Length
	}
	foreach ($p in $pngs) { $w.Write($p) }
	$w.Flush(); [IO.File]::WriteAllBytes("$PSScriptRoot\ico\$base.ico", $ms.ToArray()); $total += $ms.Length
}
"{0} icons, {1:N1} KB in all" -f (Get-ChildItem "$PSScriptRoot\ico" -Filter *.ico).Count, ($total / 1KB)
