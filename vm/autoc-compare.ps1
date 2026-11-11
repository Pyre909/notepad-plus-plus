param([Parameter(Mandatory)] [string] $Exe)
# The auto-completion lists of a few cases, item by item: each item inserted (SCI_AUTOCCOMPLETE after moving down to it),
# read back from the document, undone. Prints "case: item1|item2|...". Compare two builds' outputs (2026-11-10: the scan
# without moving the gap, the same lists as before). Now and then a list is read before it's complete or one word is read
# wrong, in either build: run each build twice and compare the runs that agree.
Add-Type -Namespace AC -Name U -MemberDefinition @'
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr p, IntPtr after, string cls, string title);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
'@
function Send([IntPtr] $h, [int] $m, [long] $w = 0, [long] $l = 0) { $r = [IntPtr]::Zero; [void][AC.U]::SendMessageTimeout($h, $m, [IntPtr]$w, [IntPtr]$l, 2, 20000, [ref]$r); $r.ToInt64() }
$SCI = @{ GOTOPOS = 2025; GETCHARAT = 2007; AUTOCACTIVE = 2102; AUTOCCOMPLETE = 2104; AUTOCCANCEL = 2101; LINEDOWN = 2300; UNDO = 2176; GETCURRENTPOS = 2008
	AUTOCGETCURRENT = 2445; WORDSTARTPOSITION = 2266; WORDENDPOSITION = 2267; BEGINUNDOACTION = 2078; ENDUNDOACTION = 2079; GETLENGTH = 2006; POSITIONFROMLINE = 2167 }
$dir = Join-Path $env:TEMP ('npp-ac-' + [guid]::NewGuid().ToString('N').Substring(0, 6)); New-Item -ItemType Directory $dir | Out-Null
# words before and after the places typed at; a long word and a non-ASCII one
$words = 'compute computeAll computer compound complete complex component compress Comparator compile caf' + [char]0xE9 + 'Latte'
$text = (1..400 | ForEach-Object { "int $_ = compute(a) + computeAll(b); // complete the component, compress, compile" }) -join "`r`n"
$cpp = Join-Path $dir 'words.cpp'; [IO.File]::WriteAllText($cpp, "// $words`r`n" + $text + "`r`n// tail: computerize compiler componentWise`r`n", [Text.UTF8Encoding]::new($false))
$sql = Join-Path $dir 'words.sql'; [IO.File]::WriteAllText($sql, ((1..200 | ForEach-Object { "SELECT Name, NameFirst FROM Names WHERE namespace = 'x' -- NAMEtag $_" }) -join "`r`n") + "`r`n", [Text.UTF8Encoding]::new($false))
$settings = Join-Path $dir 'settings'; New-Item -ItemType Directory $settings | Out-Null
$p = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$settings", "`"$cpp`"", "`"$sql`"" -PassThru
for ($i = 0; $i -lt 100 -and $p.MainWindowHandle -eq 0; $i++) { Start-Sleep -Milliseconds 100; $p.Refresh() }
Start-Sleep -Milliseconds 2000
$m = $p.MainWindowHandle
function View { $v = [IntPtr]::Zero; $h = [IntPtr]::Zero; while (($h = [AC.U]::FindWindowEx($m, $h, 'Scintilla', [NullString]::Value)) -ne [IntPtr]::Zero) { if ($v -eq [IntPtr]::Zero -and [AC.U]::IsWindowVisible($h)) { $v = $h } }; $v }
function Word([IntPtr] $v, [long] $pos) { $s = Send $v $SCI.WORDSTARTPOSITION $pos 1; $e = Send $v $SCI.WORDENDPOSITION $pos 1; $b = [byte[]]@($s..($e - 1) | ForEach-Object { [byte]((Send $v $SCI.GETCHARAT $_) -band 0xFF) }); [Text.Encoding]::UTF8.GetString($b) }
# the list shown after typing $typed at $pos: its items (from the top: SCI_LINEUP to the first, then down to each), each
# inserted, read, undone
function Show-List([IntPtr] $v, [long] $pos, [string] $typed) {
	[void](Send $v $SCI.GOTOPOS $pos); [void](Send $v $SCI.BEGINUNDOACTION)
	foreach ($ch in $typed.ToCharArray()) { [void](Send $v 0x0102 ([int]$ch)) }
	[void](Send $v $SCI.ENDUNDOACTION)
	if ((Send $v $SCI.AUTOCACTIVE) -eq 0) { return $false }
	foreach ($k in 1..200) { [void](Send $v 2302) } # SCI_LINEUP: the first item
	$true
}
function Get-List([IntPtr] $v, [long] $pos, [string] $typed) {
	if (-not (Show-List $v $pos $typed)) { [void](Send $v $SCI.UNDO); return '(no list)' }
	$count = 1; $last = Send $v $SCI.AUTOCGETCURRENT
	while ($count -lt 200) { [void](Send $v $SCI.LINEDOWN); $now = Send $v $SCI.AUTOCGETCURRENT; if ($now -eq $last) { break }; $last = $now; $count++ }
	[void](Send $v $SCI.AUTOCCANCEL); [void](Send $v $SCI.UNDO)
	# the word read back starts with what the caret's word started with (a completion sent before the list was ready reads
	# another word: tried again)
	$start = (Send $v $SCI.WORDSTARTPOSITION $pos 1); $stem = $typed.Trim()
	$items = foreach ($index in 0..($count - 1)) {
		$word = ''
		foreach ($attempt in 1..4) {
			[void](Show-List $v $pos $typed)
			foreach ($k in 1..$index) { if ($index -gt 0) { [void](Send $v $SCI.LINEDOWN) } }
			[void](Send $v $SCI.AUTOCCOMPLETE)
			$word = Word $v ((Send $v $SCI.GETCURRENTPOS) - 1)
			[void](Send $v $SCI.UNDO); [void](Send $v $SCI.UNDO)
			if ($word -match '^[A-Za-z_\u00C0-\uFFFF]') { break }
			Start-Sleep -Milliseconds 100
		}
		$word
	}
	"$count items: " + ($items -join '|')
}
[void](Send $m (0x0400 + 1000 + 28) 0 0); Start-Sleep -Milliseconds 500; $v = View # the C++ file
$line = Send $v $SCI.POSITIONFROMLINE 200
"end of a word, mid-file: " + (Get-List $v ($line) ' comp')
"in a word (the caret inside 'compute'): " + (Get-List $v ($line + 14) 'u')
"before the tail words: " + (Get-List $v ((Send $v $SCI.GETLENGTH) - 40) ' compu')
[void](Send $m (0x0400 + 1000 + 28) 0 1); Start-Sleep -Milliseconds 500; $v = View # the SQL file: its API ignores case
"SQL, ignoring case: " + (Get-List $v (Send $v $SCI.POSITIONFROMLINE 100) ' nam')
Stop-Process -Id $p.Id -Force; [void]$p.WaitForExit(5000)
Remove-Item -LiteralPath $dir -Recurse -Force
