# Benchmarks of Notepad++ builds, and the training run of a PGO-instrumented build (pgo.ps1, the Pyre909 release; the
# performance program of 2026-10-20, see the tooling branch's STATUS.md). One fresh process per build and round, in a settings folder of its own, with generated
# files of 10 languages (%TEMP%\npp-bench\files, made once): startup with all of them open, full lexing of each,
# scrolling, word wrap of 300,000 long lines, typing, Replace All, Mark All, folding, the Document Map, the Style
# Configurator and Preferences opened. With several -Exe (and -Names), the builds alternate inside each round (the VM's
# speed drifts between runs); the table gives each operation's median per build and the ratio to the first build.
# -Train: one pass through every operation (each Notepad++ feature they reach becomes "hot" for PGO), then Notepad++
# closed normally: an instrumented build writes its .pgc file at exit. Compare copies of the builds in plain folders:
# a build path UMDH records stacks for (review\umdh-scope.ps1) runs slower.
param(
	[Parameter(Mandatory)] [string[]] $Exe,
	[string[]] $Names = @(),
	[int] $Rounds = 5,
	[switch] $Train,
	[string[]] $Ops = @(),
	[string] $WorkDir = (Join-Path $env:TEMP 'npp-bench')
)
$ErrorActionPreference = 'Stop'
Add-Type -Namespace NB -Name U -MemberDefinition @'
public delegate bool EnumProc(IntPtr h, IntPtr l);
[DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
[DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EnumProc f, IntPtr l);
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, System.Text.StringBuilder s, int n);
[DllImport("user32.dll", CharSet=CharSet.Unicode, EntryPoint="SendMessageW")] public static extern IntPtr SendMessageStr(IntPtr h, uint m, IntPtr w, string l);
[DllImport("user32.dll", CharSet=CharSet.Unicode, EntryPoint="SendMessageW")] public static extern IntPtr SendMessageSb(IntPtr h, uint m, IntPtr w, System.Text.StringBuilder l);
[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
[DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h, int id);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
[DllImport("user32.dll")] public static extern bool InvalidateRect(IntPtr h, IntPtr r, bool erase);
[DllImport("user32.dll")] public static extern bool UpdateWindow(IntPtr h);
'@

$WM_CLOSE = 0x0010; $WM_COMMAND = 0x0111; $WM_CHAR = 0x0102; $WM_SETTEXT = 0x000C; $WM_GETTEXT = 0x000D; $IDCANCEL = 2
$NPPMSG = 0x0400 + 1000; $NPPM_GETNBOPENFILES = $NPPMSG + 7; $NPPM_ACTIVATEDOC = $NPPMSG + 28
$SCI = @{ GOTOPOS = 2025; GETLENGTH = 2006; DOCUMENTEND = 2318; PAGEDOWN = 2322; PAGEUP = 2320; GETLINECOUNT = 2154
	SETWRAPMODE = 2268; ENSUREVISIBLE = 2232; COLOURISE = 4003; CLEARDOCUMENTSTYLE = 2005; UNDO = 2176; SETSEL = 2160
	EMPTYUNDOBUFFER = 2175; SETSAVEPOINT = 2014; SETFIRSTVISIBLELINE = 2613; WORDSTARTPOSITION = 2266; WORDENDPOSITION = 2267
	GOTOLINE = 2024; NEWLINE = 2329 }
$IDM = @{ FILE_NEW = 41001; VIEW_WRAP = 44022; VIEW_FOLDALL = 44010; VIEW_UNFOLDALL = 44029; VIEW_DOC_MAP = 44080
	VIEW_FUNC_LIST = 44084; SEARCH_REPLACE = 43003; SEARCH_MARKALLEXT1 = 43022; SEARCH_CLEARALLMARKS = 43032
	LANGSTYLE_CONFIG_DLG = 46001; SETTING_PREFERENCE = 48011; VIEW_CLONE_TO_ANOTHER_VIEW = 10002; LANG_CPP = 46003 }

function Send([IntPtr] $h, [int] $m, [long] $w = 0, [long] $l = 0) { $r = [IntPtr]::Zero; [void][NB.U]::SendMessageTimeout($h, $m, [IntPtr]$w, [IntPtr]$l, 0, 600000, [ref]$r); $r.ToInt64() }
function Paint([IntPtr] $h) { [void][NB.U]::InvalidateRect($h, [IntPtr]::Zero, $false); [void][NB.U]::UpdateWindow($h) }
function Time([scriptblock] $b) { $sw = [Diagnostics.Stopwatch]::StartNew(); & $b; [math]::Round($sw.Elapsed.TotalMilliseconds, 1) }
function Get-Cls([IntPtr] $h) { $sb = [Text.StringBuilder]::new(64); [void][NB.U]::GetClassName($h, $sb, 64); $sb.ToString() }
function Get-Text([IntPtr] $h) { $sb = [Text.StringBuilder]::new(256); [void][NB.U]::SendMessageSb($h, $WM_GETTEXT, [IntPtr]256, $sb); $sb.ToString() }
function Get-Tops([uint32] $procId) { $script:tops = [Collections.Generic.List[IntPtr]]::new(); [void][NB.U]::EnumWindows({ param($h, $l) $p = 0; [void][NB.U]::GetWindowThreadProcessId($h, [ref]$p); if ($p -eq $procId) { $script:tops.Add($h) }; $true }, [IntPtr]::Zero); $script:tops.ToArray() }
function Find-Dialog([uint32] $procId, [string] $title) {
	for ($i = 0; $i -lt 400; $i++) {
		$d = Get-Tops $procId | Where-Object { (Get-Cls $_) -eq '#32770' -and [NB.U]::IsWindowVisible($_) -and (Get-Text $_) -eq $title } | Select-Object -First 1
		if ($d) { return $d }
		Start-Sleep -Milliseconds 25
	}
	throw "no dialog '$title'"
}
# the main view (the visible Scintilla child of the main window)
function Get-View([IntPtr] $main) {
	$script:kids = [Collections.Generic.List[IntPtr]]::new(); [void][NB.U]::EnumChildWindows($main, { param($h, $l) $script:kids.Add($h); $true }, [IntPtr]::Zero)
	$script:kids | Where-Object { (Get-Cls $_) -eq 'Scintilla' -and [NB.U]::IsWindowVisible($_) -and [NB.U]::GetParent($_) -eq $main } | Select-Object -First 1
}

# --- the files, made once: deterministic, lexer-rich (comments, strings, numbers, keywords, nesting, embedded languages)
$files = Join-Path $WorkDir 'files'
$fileNames = 'code.cpp', 'code.py', 'script.js', 'page.html', 'data.json', 'doc.xml', 'readme.md', 'style.css', 'query.sql', 'events.log', 'wrap.txt'
function New-File([string] $name, [int] $count, [scriptblock] $line, [string] $head = '', [string] $tail = '') {
	$sb = [Text.StringBuilder]::new($count * 64)
	if ($head) { [void]$sb.Append($head) }
	for ($i = 1; $i -le $count; $i++) { [void]$sb.Append((& $line $i)).Append("`r`n") }
	if ($tail) { [void]$sb.Append($tail) }
	[IO.File]::WriteAllText((Join-Path $files $name), $sb.ToString(), [Text.UTF8Encoding]::new($false))
}
if (-not (Test-Path (Join-Path $files 'done-v1'))) {
	New-Item -ItemType Directory -Force $files | Out-Null
	New-File 'code.cpp' 60000 { param($i) switch ($i % 10) {
		0 { "// Function $i computes the value of item $i (TODO: check the bounds)" }
		1 { "static int f$i(int a, const char* s) { return a * $i + (s ? 1 : 0); } /* block $i */" }
		2 { "namespace n$($i % 97) { constexpr double d$i = $i.5e-3; constexpr auto h$i = 0x$('{0:X}' -f $i); }" }
		3 { "class C$i : public Base { public: virtual ~C$i() = default; std::string name = `"item $i\n`"; };" }
		4 { "#if defined(FEATURE_$($i % 31)) && FEATURE_LEVEL > $($i % 5)" }
		5 { "#define MACRO_$i(x) ((x) << $($i % 8)) // shift" }
		6 { '#endif' }
		7 { "template <typename T> T g$i(T v) { for (auto& e : v) { if (e > $i) continue; else break; } return v; }" }
		8 { "const wchar_t* w$i = L`"wide $i`"; char c$i = 'x'; bool b$i = true && !false;" }
		9 { "int main$i() { std::vector<int> v{1, 2, 3}; return static_cast<int>(v.size()) - $i; }" }
	} } -head "#include <vector>`r`n#include <string>`r`n"
	New-File 'code.py' 30000 { param($i) switch ($i % 8) {
		0 { "def func_$i(a, b=$i, *args, **kwargs):" }
		1 { "    `"`"`"Docstring of ${i}: returns a value.`"`"`"" }
		2 { "    value = f`"item {a} and $i`" + 'single' + r'raw\d+'  # comment $i" }
		3 { "    if a > $i and not b or a is None: return [x ** 2 for x in range($i)]" }
		4 { "@decorator($i)" }
		5 { "class Class$i(Base, metaclass=Meta):" }
		6 { "    attr_${i}: dict[str, int] = {'k': $i, `"v`": 0x$('{0:x}' -f $i)}" }
		7 { "    async def method(self): await self.run($i.5)" }
	} }
	New-File 'script.js' 30000 { param($i) switch ($i % 6) {
		0 { "function fn$i(a, b = $i) { return a.replace(/[a-z]+\d*/gi, ``tpl `${b}``); } // comment" }
		1 { "const obj$i = { key: 'value $i', num: $i.25, ok: true, list: [1, 2, 3] };" }
		2 { "/* block comment $i */ let re$i = /^\s*(\w+)=(.*)$/m;" }
		3 { "class K$i extends Base { constructor() { super(); this.x = $i; } get y() { return this.x * 2; } }" }
		4 { "if (x$($i % 50) === null || typeof y !== 'undefined') { throw new Error(`"bad $i`"); }" }
		5 { "export default async () => { await fetch(`"/api/$i`"); };" }
	} }
	New-File 'page.html' 20000 { param($i) switch ($i % 8) {
		0 { "<div class=`"item item-$i`" id=`"i$i`" data-n=`"$i`"><span>Item $i &amp; more</span></div>" }
		1 { "<!-- comment $i -->" }
		2 { "<script>var v$i = { a: $i, s: 'text' }; function h$i() { return v$i.a * 2; }</script>" }
		3 { "<style>.c$i { color: #$('{0:x6}' -f ($i * 4099 % 16777215)); margin: $($i % 9)px 0; }</style>" }
		4 { "<a href=`"https://example.org/$i?x=1&amp;y=2`" title='link $i'>Link $i</a>" }
		5 { "<table><tr><td>$i</td><td>value</td></tr></table>" }
		6 { "<p>Paragraph $i with <b>bold</b>, <i>italic</i> and <code>code</code>.</p>" }
		7 { "<input type=`"text`" name=`"f$i`" value=`"$i`" disabled>" }
	} } -head "<!DOCTYPE html>`r`n<html><head><title>bench</title></head><body>`r`n" -tail "</body></html>`r`n"
	New-File 'data.json' 30000 { param($i) switch ($i % 6) {
		0 { "  {" }
		1 { "    `"id`": $i, `"name`": `"item é $i`", `"ok`": true," }
		2 { "    `"values`": [1.5, -2e3, $i, null, false]," }
		3 { "    `"nested`": { `"a`": { `"b`": `"$i`" } }," }
		4 { "    `"last`": `"end`"" }
		5 { "  }," }
	} } -head "[`r`n" -tail "  {}`r`n]`r`n"
	New-File 'doc.xml' 30000 { param($i) switch ($i % 6) {
		0 { "  <item id=`"$i`" type='t$($i % 7)'>" }
		1 { "    <name lang=`"en`">Item $i &lt;tag&gt;</name>" }
		2 { "    <!-- comment $i -->" }
		3 { "    <data><![CDATA[raw <data> $i]]></data>" }
		4 { "    <empty attr=`"$i`" />" }
		5 { "  </item>" }
	} } -head "<?xml version=`"1.0`" encoding=`"UTF-8`"?>`r`n<root>`r`n" -tail "</root>`r`n"
	New-File 'readme.md' 10000 { param($i) switch ($i % 8) {
		0 { "## Section $i" }
		1 { "Some *emphasis*, **strong** text, ``inline code`` and a [link $i](https://example.org/$i)." }
		2 { "- list item $i" }
		3 { "1. numbered $i" }
		4 { '```cpp' }
		5 { "int x$i = $i;" }
		6 { '```' }
		7 { "> quote $i" }
	} }
	New-File 'style.css' 10000 { param($i) switch ($i % 4) {
		0 { ".class-$i > a:hover, #id$i::before {" }
		1 { "  color: rgba($($i % 255), 10, 20, 0.5); font: bold $($i % 30)px/1.5 'Segoe UI', sans-serif;" }
		2 { "  margin: 0 auto !important; /* comment $i */" }
		3 { "}" }
	} }
	New-File 'query.sql' 10000 { param($i) switch ($i % 4) {
		0 { "SELECT a.id, b.name, COUNT(*) AS n$i FROM table_$($i % 50) a" }
		1 { "  JOIN other b ON a.id = b.ref AND b.flag = 'yes' -- comment $i" }
		2 { "  WHERE a.value > $i.5 GROUP BY a.id, b.name HAVING COUNT(*) > 1" }
		3 { "  ORDER BY n$i DESC; /* end $i */" }
	} }
	New-File 'events.log' 100000 { param($i) "2026-10-20 12:$('{0:D2}' -f ($i % 60)):$('{0:D2}' -f ($i % 59)).$('{0:D3}' -f ($i % 997)) [$(@('INFO', 'WARN', 'ERROR', 'DEBUG')[$i % 4])] worker-$($i % 16): request $i done in $($i % 1000) ms" }
	New-File 'wrap.txt' 300000 { param($i) "Line $i of a long text: the quick brown fox jumps over the lazy dog, then again and again, $i times, until the line is long enough to wrap in a window of usual width." }
	Set-Content -Path (Join-Path $files 'done-v1') -Value ''
}
# the Function List's training file, small: it parsed 3,000 lines of code.cpp in 14.5 s, the 60,000 in 3 minutes (LTCG,
# 2026-10-20), an instrumented build much slower
$funcList = Join-Path $files 'funclist-1000.cpp'
if (-not (Test-Path $funcList)) { [IO.File]::WriteAllLines($funcList, [string[]](Get-Content (Join-Path $files 'code.cpp') -TotalCount 1000)) }

# --- the operations, each on the open Notepad++ (main window $m, process $p); each returns its time in ms
$codeTabs = 0..8
function Activate([IntPtr] $m, [int] $index) { [void](Send $m $NPPM_ACTIVATEDOC 0 $index); [void](Send $m 0) }
$allOps = [ordered]@{
	'lex: all files, full' = { param($m, $p) $t = 0; foreach ($i in $codeTabs) { Activate $m $i; $v = Get-View $m; [void](Send $v $SCI.CLEARDOCUMENTSTYLE); $t += Time { [void](Send $v $SCI.COLOURISE 0 -1) } }; $t }
	'scroll: C++ 200 pages' = { param($m, $p) Activate $m 0; $v = Get-View $m; [void](Send $v $SCI.GOTOPOS 0); Paint $v; Time { foreach ($i in 1..200) { [void](Send $v $SCI.PAGEDOWN); Paint $v } } }
	'scroll: HTML 200 pages' = { param($m, $p) Activate $m 3; $v = Get-View $m; [void](Send $v $SCI.GOTOPOS 0); Paint $v; Time { foreach ($i in 1..200) { [void](Send $v $SCI.PAGEDOWN); Paint $v } } }
	'wrap: 300,000 lines' = { param($m, $p) Activate $m 10; $v = Get-View $m; $t = Time { [void](Send $v $SCI.SETWRAPMODE 1); [void](Send $v $SCI.ENSUREVISIBLE ((Send $v $SCI.GETLINECOUNT) - 1)); Paint $v }; [void](Send $v $SCI.SETWRAPMODE 0); Paint $v; $t }
	'wrapped scroll: 100 jumps' = { param($m, $p) Activate $m 9; $v = Get-View $m; [void](Send $v $SCI.SETWRAPMODE 1); [void](Send $v $SCI.ENSUREVISIBLE ((Send $v $SCI.GETLINECOUNT) - 1)); $t = Time { foreach ($i in 0..99) { [void](Send $v $SCI.SETFIRSTVISIBLELINE ($i * 997)); Paint $v } }; [void](Send $v $SCI.SETWRAPMODE 0); Paint $v; $t }
	'type: 1500 chars in C++' = { param($m, $p) [void](Send $m $WM_COMMAND $IDM.FILE_NEW); [void](Send $m $WM_COMMAND $IDM.LANG_CPP); $v = Get-View $m; $text = 'int value = compute(a, b) + offset; // note' ; Time { foreach ($k in 1..30) { foreach ($ch in $text.ToCharArray()) { [void](Send $v $WM_CHAR ([int]$ch)) }; [void](Send $v $SCI.NEWLINE); Paint $v } } }
	'replace all: C++ 6,000 matches' = { param($m, $p) Activate $m 0; $v = Get-View $m; [void](Send $v $SCI.GOTOPOS 0)
		[void](Send $m $WM_COMMAND $IDM.SEARCH_REPLACE); $d = Find-Dialog $p.Id 'Replace'
		[void][NB.U]::SendMessageStr([NB.U]::GetDlgItem($d, 1601), $WM_SETTEXT, [IntPtr]::Zero, 'Base')
		[void][NB.U]::SendMessageStr([NB.U]::GetDlgItem($d, 1602), $WM_SETTEXT, [IntPtr]::Zero, 'BaseClass')
		$t = Time { [void](Send $d $WM_COMMAND 1609 ([NB.U]::GetDlgItem($d, 1609)).ToInt64()); Paint $v }
		[void](Send $d $WM_COMMAND $IDCANCEL); [void](Send $v $SCI.UNDO); $t }
	'mark all: a C++ word' = { param($m, $p) Activate $m 0; $v = Get-View $m; [void](Send $v $SCI.GOTOLINE 2); $pos = Send $v 2167 2	# SCI_POSITIONFROMLINE: "static int f1("
		[void](Send $v $SCI.SETSEL $pos ($pos + 6)); $t = Time { [void](Send $m $WM_COMMAND $IDM.SEARCH_MARKALLEXT1); Paint $v }; [void](Send $m $WM_COMMAND $IDM.SEARCH_CLEARALLMARKS); $t }
	'fold all, unfold all: C++, XML, JSON' = { param($m, $p) $t = 0; foreach ($i in 0, 5, 4) { Activate $m $i; $v = Get-View $m; $t += Time { [void](Send $m $WM_COMMAND $IDM.VIEW_FOLDALL); Paint $v; [void](Send $m $WM_COMMAND $IDM.VIEW_UNFOLDALL); Paint $v } }; $t }
	'document map: on, 50 pages, off' = { param($m, $p) Activate $m 0; $v = Get-View $m; [void](Send $v $SCI.GOTOPOS 0); Time { [void](Send $m $WM_COMMAND $IDM.VIEW_DOC_MAP); foreach ($i in 1..50) { [void](Send $v $SCI.PAGEDOWN); Paint $v }; [void](Send $m $WM_COMMAND $IDM.VIEW_DOC_MAP); [void](Send $m 0) } }
	'Style Configurator: open, close' = { param($m, $p) Time { [void][NB.U]::PostMessage($m, $WM_COMMAND, [IntPtr]$IDM.LANGSTYLE_CONFIG_DLG, [IntPtr]::Zero); $d = Find-Dialog $p.Id 'Style Configurator'; [void](Send $d $WM_COMMAND $IDCANCEL) } }
	'Preferences: open, close' = { param($m, $p) Time { [void][NB.U]::PostMessage($m, $WM_COMMAND, [IntPtr]$IDM.SETTING_PREFERENCE, [IntPtr]::Zero); $d = Find-Dialog $p.Id 'Preferences'; [void](Send $d $WM_COMMAND $IDCANCEL) } }
}
# training only (not timed): a clone in the other view (the Function List: Invoke-FunctionListTraining)
$trainOps = [ordered]@{
	'clone to the other view' = { param($m, $p) Activate $m 1; [void](Send $m $WM_COMMAND $IDM.VIEW_CLONE_TO_ANOTHER_VIEW); [void](Send $m 0); 0 }
}
$selected = if ($Ops.Count) { $Ops } else { @($allOps.Keys) }

# closes Notepad++ normally, answering No to "Save?" (the typed document); returns whether it exited
function Close-Npp($p) {
	[void][NB.U]::PostMessage($p.MainWindowHandle, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero)
	for ($i = 0; $i -lt 240 -and -not $p.HasExited; $i++) {
		Start-Sleep -Milliseconds 250
		foreach ($b in @(Get-Tops ([uint32]$p.Id) | Where-Object { (Get-Cls $_) -eq '#32770' -and [NB.U]::IsWindowVisible($_) })) {
			$no = [NB.U]::GetDlgItem($b, 7); if ($no -ne [IntPtr]::Zero) { [void][NB.U]::PostMessage($b, $WM_COMMAND, [IntPtr]7, $no) }
		}
	}
	$p.HasExited
}

# one run: Notepad++ started with every file, the operations in order; the times
function Invoke-Run([string] $exePath, [string] $label) {
	$settings = Join-Path $WorkDir "settings-$label"; New-Item -ItemType Directory -Force $settings | Out-Null
	$paths = $fileNames | ForEach-Object { Join-Path $files $_ }
	$r = [ordered]@{}
	$sw = [Diagnostics.Stopwatch]::StartNew()
	$p = Start-Process $exePath -ArgumentList (@('-multiInst', '-nosession', "-settingsDir=$settings") + $paths) -PassThru
	try {
		# up to 2 minutes (an instrumented build is slower); a process that exits or never shows its window is an error (a
		# DLL not found raises a hard error nobody sees: the process waits with no window)
		while (($p.MainWindowHandle -eq 0) -and -not $p.HasExited -and ($sw.Elapsed.TotalSeconds -lt 120)) { Start-Sleep -Milliseconds 10; $p.Refresh() }
		if ($p.HasExited) { throw ("{0} exited at startup, code 0x{1:X8}" -f $label, $p.ExitCode) }
		if ($p.MainWindowHandle -eq 0) { throw "$label showed no window in 2 minutes" }
		$m = $p.MainWindowHandle
		while (((Send $m $NPPM_GETNBOPENFILES 0 0) -lt $fileNames.Count) -and ($sw.Elapsed.TotalSeconds -lt 240)) { Start-Sleep -Milliseconds 10 }	# the empty "new 1" gives way to the first file
		$r['startup: 11 files open'] = [math]::Round($sw.Elapsed.TotalMilliseconds, 1)
		Start-Sleep -Milliseconds 1000
		# each operation's time, and the CPU time Notepad++ spent during it (all its threads): painting with DirectWrite waits
		# for the display's refresh (a page scrolled and painted is 16.7 ms at 60 Hz whatever the build), the CPU time doesn't
		foreach ($name in $selected) {
			$p.Refresh(); $cpu = $p.TotalProcessorTime
			$r[$name] = & $allOps[$name] $m $p
			$p.Refresh(); $r["$name (CPU)"] = [math]::Round(($p.TotalProcessorTime - $cpu).TotalMilliseconds, 1)
			if ($Train) { Write-Host ("  {0}: {1:N0} ms" -f $name, $r[$name]) }	# the progress of a training run (slow: instrumented)
		}
		if ($Train) { foreach ($name in $trainOps.Keys) { $t = Time { [void](& $trainOps[$name] $m $p) }; Write-Host ("  {0}: {1:N0} ms" -f $name, $t) } }
	}
	finally {
		$closed = (-not $p.HasExited) -and (Close-Npp $p)
		if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force; [void]$p.WaitForExit(10000) }
		if ($Train -and -not $closed) { Write-Warning "$label didn't close normally: no profile written" }
	}
	$r
}

# training only: the Function List on a file of a usual size, in a run of its own (another .pgc)
function Invoke-FunctionListTraining([string] $exePath, [string] $label) {
	$settings = Join-Path $WorkDir "settings-$label-functionlist"; New-Item -ItemType Directory -Force $settings | Out-Null
	$sw = [Diagnostics.Stopwatch]::StartNew()
	$p = Start-Process $exePath -ArgumentList '-multiInst', '-nosession', "-settingsDir=$settings", $funcList -PassThru
	try {
		while (($p.MainWindowHandle -eq 0) -and -not $p.HasExited -and ($sw.Elapsed.TotalSeconds -lt 120)) { Start-Sleep -Milliseconds 10; $p.Refresh() }
		if ($p.MainWindowHandle -eq 0) { throw "$label (Function List run) showed no window" }
		$m = $p.MainWindowHandle; Start-Sleep -Milliseconds 1000
		$t = Time { [void](Send $m $WM_COMMAND $IDM.VIEW_FUNC_LIST) }	# handled synchronously: the file parsed when it returns
		Write-Host ("  function list, 1,000 lines of C++: {0:N0} ms" -f $t)
		[void](Send $m $WM_COMMAND $IDM.VIEW_FUNC_LIST)
	}
	finally {
		$closed = (-not $p.HasExited) -and (Close-Npp $p)
		if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force; [void]$p.WaitForExit(10000) }
		if (-not $closed) { Write-Warning "$label (Function List run) didn't close normally: no profile written" }
	}
}

if (-not $Names.Count) { $Names = 1..$Exe.Count | ForEach-Object { "build$_" } }
if ($Train) {
	foreach ($i in 0..($Exe.Count - 1)) {
		$r = Invoke-Run $Exe[$i] $Names[$i]; "$($Names[$i]): trained ($(@($r.Keys | Where-Object { $_ -notmatch '\(CPU\)$' }).Count) operations)"
		Invoke-FunctionListTraining $Exe[$i] $Names[$i]
	}
	return
}
$rows = foreach ($round in 1..$Rounds) { foreach ($i in 0..($Exe.Count - 1)) {
	$r = Invoke-Run $Exe[$i] $Names[$i]
	foreach ($k in $r.Keys) { [pscustomobject]@{ build = $Names[$i]; round = $round; op = $k; ms = $r[$k] } }
} }
$median = { param($v) $s = @($v | Sort-Object); if ($s.Count % 2) { $s[[int][math]::Floor($s.Count / 2)] } else { ($s[$s.Count / 2 - 1] + $s[$s.Count / 2]) / 2 } }
$table = foreach ($op in ($rows | Select-Object -ExpandProperty op -Unique)) {
	$o = [ordered]@{ operation = $op }
	$base = $null
	foreach ($n in $Names) {
		$med = & $median ($rows | Where-Object { $_.op -eq $op -and $_.build -eq $n } | ForEach-Object ms)
		$o[$n] = [math]::Round($med, 1)
		if ($null -eq $base) { $base = $med } elseif ($base -gt 0) { $o["$n/$($Names[0])"] = '{0:P0}' -f ($med / $base) }
	}
	[pscustomobject]$o
}
"medians of $Rounds rounds, ms; (CPU): Notepad++'s CPU time during the operation, all threads"
$table | Format-Table -AutoSize | Out-String -Width 200
