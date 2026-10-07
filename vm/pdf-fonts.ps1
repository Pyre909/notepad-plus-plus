# Lists the fonts a PDF embeds by their own names (the TrueType name table and OS/2 weight of each FontFile2 stream:
# Microsoft Print to PDF names them CIDFont+F1...) and the text operators of its pages (font, render mode).
# Windows PowerShell 5.1: powershell -File pdf-fonts.ps1 <file.pdf>
param([Parameter(Mandatory)] [string] $Pdf)
$ErrorActionPreference = 'Stop'
$bytes = [IO.File]::ReadAllBytes($Pdf)
$text = [Text.Encoding]::GetEncoding(28591).GetString($bytes)
function Get-Object([int] $n) { $m = [regex]::Match($text, "(?s)(?<![0-9])$n 0 obj\s*(.*?)\s*endobj"); if ($m.Success) { $m.Groups[1].Value } }
function Get-Stream([System.Text.RegularExpressions.Match] $m) {
	$dict = $m.Groups[2].Value
	$lengthRef = [regex]::Match($dict, '/Length (\d+) 0 R')
	$length = if ($lengthRef.Success) { [int](Get-Object ([int]$lengthRef.Groups[1].Value)).Trim() } else { [int]([regex]::Match($dict, '/Length (\d+)').Groups[1].Value) }
	$start = $m.Index + $m.Length
	if ($dict -notmatch '/FlateDecode') { return ,([byte[]]($bytes[$start..($start + $length - 1)])) }
	$ms = [IO.MemoryStream]::new($bytes, ($start + 2), ($length - 2)) # the zlib header skipped
	$ds = [IO.Compression.DeflateStream]::new($ms, [IO.Compression.CompressionMode]::Decompress)
	$out = [IO.MemoryStream]::new(); $ds.CopyTo($out)
	return ,($out.ToArray())
}
function Read-UInt16([byte[]] $b, [int] $o) { $b[$o] * 256 + $b[$o + 1] }
function Read-UInt32([byte[]] $b, [int] $o) { [uint32](((($b[$o] * 256 + $b[$o + 1]) * 256 + $b[$o + 2]) * 256) + $b[$o + 3]) }

foreach ($m in [regex]::Matches($text, '(?s)(?<![0-9])(\d+) 0 obj\s*<<(.*?)>>\s*stream\r?\n')) {
	$number = $m.Groups[1].Value; $dict = $m.Groups[2].Value
	$data = Get-Stream $m
	if ($dict -match '/Length1') {
		# a TrueType font program: its table directory, name table (Windows English names) and OS/2 weight
		$tables = @{}
		for ($t = 0; $t -lt (Read-UInt16 $data 4); $t++) {
			$o = 12 + 16 * $t
			$tables[[Text.Encoding]::ASCII.GetString($data, $o, 4)] = [int](Read-UInt32 $data ($o + 8))
		}
		$names = @()
		if ($tables.ContainsKey('name')) {
			$off = $tables['name']; $strings = $off + (Read-UInt16 $data ($off + 4))
			for ($r = 0; $r -lt (Read-UInt16 $data ($off + 2)); $r++) {
				$ro = $off + 6 + 12 * $r
				if (((Read-UInt16 $data $ro) -eq 3) -and ((Read-UInt16 $data ($ro + 4)) -eq 0x409) -and ((Read-UInt16 $data ($ro + 6)) -in 1, 2, 4, 16, 17)) {
					$names += "{0}={1}" -f (Read-UInt16 $data ($ro + 6)), [Text.Encoding]::BigEndianUnicode.GetString($data, $strings + (Read-UInt16 $data ($ro + 10)), (Read-UInt16 $data ($ro + 8)))
				}
			}
		}
		$weight = if ($tables.ContainsKey('OS/2')) { Read-UInt16 $data ($tables['OS/2'] + 4) } else { '?' }
		"font program (object $number, $($data.Length) bytes): weight class $weight; names $($names -join '; ')"
	}
	elseif ($dict -notmatch '/Subtype|/Type') {
		# a page's content: its fonts (Tf) and text render modes (Tr: 2 is fill and stroke, a synthetic bold)
		$content = [Text.Encoding]::GetEncoding(28591).GetString($data)
		$fonts = ([regex]::Matches($content, '/(\w+)\s+[\d.]+\s+Tf') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique) -join ', '
		$modes = ([regex]::Matches($content, '(?<![\d.])(\d)\s+Tr\b') | ForEach-Object { $_.Groups[1].Value } | Group-Object | ForEach-Object { "$($_.Name) x$($_.Count)" }) -join ', '
		$widths = ([regex]::Matches($content, '(?<![\d.])([\d.]+)\s+w\b') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique) -join ', '
		"content (object $number, $($data.Length) bytes): fonts $fonts; render modes $modes; line widths $widths"
	}
}
foreach ($m in [regex]::Matches($text, '/FontName\s*/([^\s/\[\]<>()]+)')) { "font name in the PDF: $($m.Groups[1].Value)" }
