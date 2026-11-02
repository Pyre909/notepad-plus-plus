# App-level test (review harness): values out of range from a plugin, the command line or config.xml don't crash Notepad++.
# - NPPM_SETCURRENTLANGTYPE with a language type out of range, or an external language none is installed for, returns
#   FALSE and leaves the document's language (before: stored, and the next character typed crashed in
#   maintainIndentation, reading _externalLangArray out of its bounds); a valid one still applies; the Language menu's
#   external language commands (IDM_LANG_EXTERNAL..) do nothing without an external lexer (before: the same crash).
# - Strings longer than the arrays they're copied to, which failed fast (0xC0000409 at startup: MSVC's secure overload
#   made wcsncpy with the array's size a wcsncpy_s, without room for the L'\0'; elsewhere wcsncpy left them unterminated):
#   -udl= and -pluginMessage= as long as their CmdLineParamsDTO arrays (MAX_PATH and 2048 characters) or longer, with a
#   file to open; a -udl= name too long for the auto-completion file's path (AutoCompletion::setLanguage, wcscat_s in a
#   MAX_PATH array); config.xml's defaultDirPath and lastUsedDirPath longer than MAX_PATH.
# - The same with wcscpy_s / wcscat_s into fixed arrays (each failed fast before): NPPM_RELOADFILE with a path of MAX_PATH
#   or more (refused; the open file's own path still reloads); a translation (nativeLang.xml in the settings folder) whose
#   Shortcut Mapper column name is too long for BabyGrid's 255 and 1000-character buffers, whose Find in Files progress
#   title is longer than Progress::_header (128), whose Find All result is longer than 1024 characters, whose Folder as
#   Workspace and Function List tooltips are longer than szText (80; shown as tracking tooltips, no mouse moved); a theme
#   language description of 250 characters (Style Configurator's "<language>: <style>" label, 257); a session file's
#   Folder as Workspace root of more than MAX_PATH characters (\\?\, -openSession; shown) and a config.xml project
#   workspace that long (refused; a usual one still opens with its file).
# Contract of review\tests: -Exe <notepad++.exe>; PASS/FAIL lines; last line "<n> checks, <m> failed".
param([Parameter(Mandatory)] [string] $Exe)
$ErrorActionPreference = 'Stop'
Add-Type -Namespace PB -Name U -MemberDefinition @'
public delegate bool EnumProc(IntPtr h, IntPtr l);
[DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EnumProc f, IntPtr l);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, System.Text.StringBuilder s, int n);
[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
[DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
[DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h, int id);
[DllImport("user32.dll", CharSet=CharSet.Unicode, EntryPoint="SendMessageTimeoutW")] public static extern IntPtr SendMessageTimeoutStr(IntPtr h, uint m, IntPtr w, string l, uint flags, uint timeout, out IntPtr result);
[DllImport("kernel32.dll")] public static extern IntPtr VirtualAllocEx(IntPtr p, IntPtr a, IntPtr size, uint type, uint protect);
[DllImport("kernel32.dll")] public static extern bool WriteProcessMemory(IntPtr p, IntPtr a, byte[] b, IntPtr size, out IntPtr n);
[DllImport("kernel32.dll")] public static extern bool ReadProcessMemory(IntPtr p, IntPtr a, byte[] b, IntPtr size, out IntPtr n);
'@
$script:results = [Collections.Generic.List[string]]::new(); $script:fails = 0
function Check([string] $name, [bool] $ok, [string] $detail = '') {
	if (-not $ok) { $script:fails++ }
	$script:results.Add(("{0}  {1}{2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $(if ($detail) { "  [$detail]" } else { '' })))
}
function Send([IntPtr] $h, [int] $msg, [long] $w = 0, [long] $l = 0) { $r = [IntPtr]::Zero; [void][PB.U]::SendMessageTimeout($h, $msg, [IntPtr]$w, [IntPtr]$l, 2, 5000, [ref]$r); $r.ToInt64() }
$root = Join-Path ([IO.Path]::GetTempPath()) ('npp-review\plugin-api-bounds-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$script:n = 0
function New-Settings { $settings = Join-Path $root ("s{0}" -f ++$script:n); New-Item -ItemType Directory -Force $settings | Out-Null; $settings }
function Start-Npp([string[]] $extra = @(), [string] $settings = (New-Settings)) {
	$p = Start-Process $Exe -ArgumentList (@('-multiInst', '-nosession', "-settingsDir=$settings", '-titleAdd=REVIEW-TEST') + $extra) -PassThru
	for ($i = 0; $i -lt 150 -and $p.MainWindowHandle -eq 0 -and -not $p.HasExited; $i++) { Start-Sleep -Milliseconds 100; $p.Refresh() }
	Start-Sleep -Milliseconds 1500; $p.Refresh()
	$p
}
function Stop-Npp($p) { if (-not $p.HasExited) { [void][PB.U]::PostMessage($p.MainWindowHandle, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero); if (-not $p.WaitForExit(10000)) { Stop-Process -Id $p.Id -Force } } }
function Get-MainView($p) {
	$script:sci = [IntPtr]::Zero
	[void][PB.U]::EnumChildWindows($p.MainWindowHandle, { param($h, $l) $sb = [Text.StringBuilder]::new(32); [void][PB.U]::GetClassName($h, $sb, 32); if ($script:sci -eq [IntPtr]::Zero -and $sb.ToString() -eq 'Scintilla' -and [PB.U]::IsWindowVisible($h)) { $script:sci = $h }; $true }, [IntPtr]::Zero)
	$script:sci
}
# a character typed in the current view: alive afterwards (a crash takes Windows a few seconds to end the process), and added
function Test-Typing($p, [string] $name) {
	$sci = Get-MainView $p
	$before = Send $sci 2006 # SCI_GETLENGTH
	[void][PB.U]::PostMessage($sci, 0x0102, [IntPtr][int][char]'a', [IntPtr]1) # WM_CHAR
	Start-Sleep -Seconds 4; $p.Refresh()
	$after = if ($p.HasExited) { -1 } else { Send $sci 2006 }
	Check $name ((-not $p.HasExited) -and ($after -eq $before + 1)) $(if ($p.HasExited) { 'crashed: 0x{0:X8}' -f $p.ExitCode } else { "length $before -> $after" })
}
function SendText([IntPtr] $h, [int] $msg, [long] $w, [string] $text) { $r = [IntPtr]::Zero; [void][PB.U]::SendMessageTimeoutStr($h, $msg, [IntPtr]$w, $text, 2, 5000, [ref]$r); $r.ToInt64() }
function Post([IntPtr] $h, [int] $msg, [long] $w = 0, [long] $l = 0) { [void][PB.U]::PostMessage($h, $msg, [IntPtr]$w, [IntPtr]$l) }
# memory in Notepad++'s process, for the messages whose lParam points to a string or a structure
function Write-Remote($p, [IntPtr] $a, [byte[]] $bytes) { $n = [IntPtr]::Zero; [void][PB.U]::WriteProcessMemory($p.Handle, $a, $bytes, [IntPtr]$bytes.Length, [ref]$n) }
function Read-Remote($p, [IntPtr] $a, [int] $size) { $bytes = [byte[]]::new($size); $n = [IntPtr]::Zero; [void][PB.U]::ReadProcessMemory($p.Handle, $a, $bytes, [IntPtr]$size, [ref]$n); , $bytes }
function New-Remote($p, [byte[]] $bytes) { $a = [PB.U]::VirtualAllocEx($p.Handle, [IntPtr]::Zero, [IntPtr]($bytes.Length + 16), 0x3000, 0x04); Write-Remote $p $a $bytes; $a }
function New-RemoteString($p, [string] $s) { New-Remote $p ([Text.Encoding]::Unicode.GetBytes($s + "`0")) }
# alive after 8 seconds (a fail-fast takes Windows a few seconds to end the process, more after other crashes)
function Test-Alive($p) { $exited = $p.WaitForExit(8000); $p.Refresh(); -not $exited }
function Get-ExitDetail($p) { if ($p.HasExited) { 'crashed: 0x{0:X8}' -f $p.ExitCode } else { 'running' } }
function Get-Descendants([IntPtr] $parent, [string] $class) {
	$script:found = [Collections.Generic.List[IntPtr]]::new()
	[void][PB.U]::EnumChildWindows($parent, { param($h, $l) $sb = [Text.StringBuilder]::new(64); [void][PB.U]::GetClassName($h, $sb, 64); if ($sb.ToString() -eq $class) { $script:found.Add($h) }; $true }, [IntPtr]::Zero)
	, $script:found
}
# the process's top-level dialog that has a control of this id
function Get-Dialog($p, [int] $controlId) {
	$script:dlg = [IntPtr]::Zero
	[void][PB.U]::EnumWindows({ param($h, $l) $procId = 0; [void][PB.U]::GetWindowThreadProcessId($h, [ref]$procId); if ($procId -eq $p.Id -and $script:dlg -eq [IntPtr]::Zero -and [PB.U]::GetDlgItem($h, $controlId) -ne [IntPtr]::Zero) { $script:dlg = $h }; $true }, [IntPtr]::Zero)
	$script:dlg
}
# the docked panel's control of this class: the panels with a tree view (Folder as Workspace, Function List, Project) also have a toolbar
function Get-PanelControl($p, [string] $class) {
	foreach ($h in (Get-Descendants $p.MainWindowHandle $class)) {
		$parent = [PB.U]::GetParent($h)
		if ((Get-Descendants $parent 'SysTreeView32').Count -and (Get-Descendants $parent 'ToolbarWindow32').Count) { return $h }
	}
	[IntPtr]::Zero
}
# a docked panel's toolbar tooltip shown as if hovered, as a tracking tooltip (no mouse moved): the panel gives its text (TTN_GETDISPINFO)
function Show-PanelTip($p, [long] $toolId) {
	$toolbar = Get-PanelControl $p 'ToolbarWindow32'
	if ($toolbar -eq [IntPtr]::Zero) { return $false }
	$tip = [IntPtr](Send $toolbar 0x423) # TB_GETTOOLTIPS
	$a = New-Remote $p ([byte[]]::new(512))
	$count = Send $tip 0x40D # TTM_GETTOOLCOUNT
	for ($k = 0; $k -lt $count; $k++) {
		# TOOLINFOW: cbSize, uFlags @4, hwnd @8, uId @16, rect @24, hinst @40, lpszText @48, lParam @56, lpReserved @64
		$ti = [byte[]]::new(72); [BitConverter]::GetBytes([int]72).CopyTo($ti, 0); [BitConverter]::GetBytes($a.ToInt64() + 256).CopyTo($ti, 48)
		Write-Remote $p $a $ti
		[void](Send $tip 0x43A $k $a.ToInt64()) # TTM_ENUMTOOLSW
		$ti = Read-Remote $p $a 72
		if ([BitConverter]::ToInt64($ti, 16) -ne $toolId) { continue }
		[BitConverter]::GetBytes([BitConverter]::ToInt32($ti, 4) -bor 0xA0).CopyTo($ti, 4) # TTF_TRACK | TTF_ABSOLUTE
		[BitConverter]::GetBytes([long]-1).CopyTo($ti, 48) # LPSTR_TEXTCALLBACKW
		Write-Remote $p $a $ti
		[void](Send $tip 0x436 0 $a.ToInt64()) # TTM_SETTOOLINFOW
		[void](Send $tip 0x412 0 ((300 -shl 16) -bor 300)) # TTM_TRACKPOSITION
		[void](Send $tip 0x411 1 $a.ToInt64()) # TTM_TRACKACTIVATE
		Start-Sleep -Milliseconds 500
		return [PB.U]::IsWindowVisible($tip)
	}
	$false
}
# a translation in the settings folder (not named english.xml: that one is ignored, English being built in)
function Set-NativeLang([string] $settings, [string] $nodes) {
	Set-Content -LiteralPath (Join-Path $settings 'nativeLang.xml') -Encoding utf8 -Value "<?xml version=`"1.0`" encoding=`"utf-8`" ?>`n<NotepadPlus><Native-Langue name=`"Review`" filename=`"review.xml`">$nodes</Native-Langue></NotepadPlus>"
}
$NPPM_SETCURRENTLANGTYPE = 2024 + 6; $L_PHP = 1; $L_EXTERNAL = 114; $IDM_LANG_EXTERNAL = 46165
$NPPM_RELOADFILE = 2024 + 36; $WM_COMMAND = 0x0111; $TVM_GETCOUNT = 0x1105
$IDM_SEARCH_FIND = 43001; $IDM_SEARCH_FINDINFILES = 43013; $IDM_VIEW_PROJECT_PANEL_1 = 44081; $IDM_VIEW_FUNC_LIST = 44084
$IDM_VIEW_FILEBROWSER = 44085; $IDM_LANGSTYLE_CONFIG_DLG = 46001; $IDM_SETTING_SHORTCUT_MAPPER = 48009
$IDFINDWHAT = 1601; $IDC_FINDALL_CURRENTFILE = 1641; $IDD_FINDINFILES_DIR_COMBO = 1653; $IDD_FINDINFILES_FIND_BUTTON = 1656
$IDC_LANGUAGES_COMBO = 2304; $IDM_BABYGRID_MODIFY = 2602; $FB_CMD_AIMFILE = 0; $IDC_SORTBUTTON_FUNCLIST = 3405
try {
	foreach ($case in @(@{ Name = 'out of range (100000)'; Value = 100000 }, @{ Name = 'L_EXTERNAL, no external lexer installed'; Value = $L_EXTERNAL })) {
		$p = Start-Npp
		$r = Send $p.MainWindowHandle $NPPM_SETCURRENTLANGTYPE 0 $case.Value
		Check "NPPM_SETCURRENTLANGTYPE $($case.Name): refused" ($r -eq 0) "returned $r"
		Test-Typing $p '  then a character typed: added, no crash'
		Stop-Npp $p
	}
	$p = Start-Npp
	$r = Send $p.MainWindowHandle $NPPM_SETCURRENTLANGTYPE 0 $L_PHP
	Check 'NPPM_SETCURRENTLANGTYPE L_PHP: still applied' ($r -eq 1) "returned $r"
	Test-Typing $p '  then a character typed: added'
	Stop-Npp $p
	$p = Start-Npp
	[void](Send $p.MainWindowHandle 0x0111 $IDM_LANG_EXTERNAL) # WM_COMMAND, as NPPM_MENUCOMMAND does
	Test-Typing $p 'Language menu, first external language with no external lexer: a character typed then, added, no crash'
	Stop-Npp $p

	# with a file to open: the command line's files are loaded with the DTO (Notepad_plus::loadCommandlineParams)
	$file = Join-Path $root 'file.txt'; Set-Content -LiteralPath $file -Value 'text'
	foreach ($case in @(@{ Name = '-udl= of 220 characters'; Arg = '-udl="' + ('a' * 220) + '"' },
						@{ Name = '-udl= of 260 characters (MAX_PATH)'; Arg = '-udl="' + ('a' * 260) + '"' },
						@{ Name = '-udl= of 400 characters'; Arg = '-udl="' + ('a' * 400) + '"' },
						@{ Name = '-pluginMessage= of 2048 characters'; Arg = '-pluginMessage="' + ('b' * 2048) + '"' },
						@{ Name = '-pluginMessage= of 3000 characters'; Arg = '-pluginMessage="' + ('b' * 3000) + '"' })) {
		$p = Start-Npp @($case.Arg, "`"$file`"")
		Start-Sleep -Seconds 4; $p.Refresh() # a fail-fast takes Windows a few seconds to end the process
		Check "command line $($case.Name), a file: Notepad++ starts" ((-not $p.HasExited) -and $p.MainWindowHandle -ne 0) $(if ($p.HasExited) { 'exited: 0x{0:X8}' -f $p.ExitCode } else { 'running' })
		Stop-Npp $p
	}

	# config.xml's open/save folders longer than their MAX_PATH arrays
	$settings = Join-Path $root 'longdirs'; New-Item -ItemType Directory -Force $settings | Out-Null
	$long = 'C:\' + ('a' * 300)
	Set-Content -LiteralPath (Join-Path $settings 'config.xml') -Encoding utf8 -Value @"
<?xml version="1.0" encoding="UTF-8" ?>
<NotepadPlus><GUIConfigs><GUIConfig name="openSaveDir" value="0" defaultDirPath="$long" lastUsedDirPath="$long" /></GUIConfigs></NotepadPlus>
"@
	$p = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$settings", '-titleAdd=REVIEW-TEST' -PassThru
	for ($i = 0; $i -lt 150 -and $p.MainWindowHandle -eq 0 -and -not $p.HasExited; $i++) { Start-Sleep -Milliseconds 100; $p.Refresh() }
	Start-Sleep -Seconds 4; $p.Refresh()
	Check 'config.xml defaultDirPath and lastUsedDirPath of 303 characters: Notepad++ starts' ((-not $p.HasExited) -and $p.MainWindowHandle -ne 0) $(if ($p.HasExited) { 'exited: 0x{0:X8}' -f $p.ExitCode } else { 'running' })
	Stop-Npp $p

	# a plugin's path longer than any document's: NPPM_RELOADFILE copied it to a MAX_PATH array
	$p = Start-Npp @("`"$file`"")
	$r = Send $p.MainWindowHandle $NPPM_RELOADFILE 0 (New-RemoteString $p ('C:\' + ('a' * 300) + '.txt')).ToInt64()
	$alive = Test-Alive $p
	Check 'NPPM_RELOADFILE, a path of 308 characters: refused, no crash' ($alive -and $r -eq 0) "returned $r, $(Get-ExitDetail $p)"
	if ($alive) {
		$r = Send $p.MainWindowHandle $NPPM_RELOADFILE 0 (New-RemoteString $p $file).ToInt64()
		Check '  the open file''s own path: still reloaded' ($r -eq 1) "returned $r"
	}
	Stop-Npp $p

	# a translation's strings longer than the arrays they're copied to
	$search = Join-Path $root 'search'; New-Item -ItemType Directory -Force $search | Out-Null
	foreach ($name in 'a.txt', 'b.txt') { Set-Content -LiteralPath (Join-Path $search $name) -Value 'text' }
	foreach ($case in @(@{ Name = 'Shortcut Mapper column name of 300 characters (BabyGrid''s line count buffer, 255)'; Nodes = '<Dialog><ShortcutMapper><ColumnName name="' + ('N' * 300) + '"/></ShortcutMapper></Dialog>'; Command = $IDM_SETTING_SHORTCUT_MAPPER; Dialog = $IDM_BABYGRID_MODIFY },
						@{ Name = 'Shortcut Mapper column name of 1000 characters (BabyGrid''s cell buffer, 1000)'; Nodes = '<Dialog><ShortcutMapper><ColumnName name="' + ('N' * 1000) + '"/></ShortcutMapper></Dialog>'; Command = $IDM_SETTING_SHORTCUT_MAPPER; Dialog = $IDM_BABYGRID_MODIFY },
						@{ Name = 'Find in Files progress title of 200 characters (Progress::_header, 128)'; Nodes = '<MiscStrings><discover-file-candidates-title value="' + ('P' * 200) + '"/></MiscStrings>'; Command = $IDM_SEARCH_FINDINFILES; Dialog = $IDD_FINDINFILES_DIR_COMBO; Click = $IDD_FINDINFILES_FIND_BUTTON },
						@{ Name = 'Find All result of 1100 characters (_findAllResultStr, 1024)'; Nodes = '<MiscStrings><find-result-hits value="' + ('H' * 1100) + ' $INT_REPLACE$"/></MiscStrings>'; Command = $IDM_SEARCH_FIND; Dialog = $IDC_FINDALL_CURRENTFILE; Click = $IDC_FINDALL_CURRENTFILE })) {
		$settings = New-Settings; Set-NativeLang $settings $case.Nodes
		$p = Start-Npp @("`"$file`"") $settings
		Post $p.MainWindowHandle $WM_COMMAND $case.Command
		Start-Sleep -Seconds 2
		$dlg = Get-Dialog $p $case.Dialog
		if ($case.Click -and $dlg -ne [IntPtr]::Zero) {
			[void](SendText ([PB.U]::GetDlgItem($dlg, $IDFINDWHAT)) 0x000C 0 'text') # WM_SETTEXT
			[void](SendText ([PB.U]::GetDlgItem($dlg, $IDD_FINDINFILES_DIR_COMBO)) 0x000C 0 $search)
			Post $dlg $WM_COMMAND $case.Click ([PB.U]::GetDlgItem($dlg, $case.Click)).ToInt64()
		}
		Check "translation, $($case.Name): $(if ($case.Click) { 'searched' } else { 'shown' }), no crash" ((Test-Alive $p) -and $dlg -ne [IntPtr]::Zero) "dialog $dlg, $(Get-ExitDetail $p)"
		Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
	}
	foreach ($case in @(@{ Name = 'Folder as Workspace "Locate current file"'; Nodes = '<FolderAsWorkspace><LocateCurrentFileTip name="' + ('T' * 100) + '"/></FolderAsWorkspace>'; Command = $IDM_VIEW_FILEBROWSER; Tool = $FB_CMD_AIMFILE },
						@{ Name = 'Function List "Sort"'; Nodes = '<FunctionList><SortTip name="' + ('T' * 100) + '"/></FunctionList>'; Command = $IDM_VIEW_FUNC_LIST; Tool = $IDC_SORTBUTTON_FUNCLIST })) {
		$settings = New-Settings; Set-NativeLang $settings $case.Nodes
		$p = Start-Npp -settings $settings
		Post $p.MainWindowHandle $WM_COMMAND $case.Command
		Start-Sleep -Seconds 2
		$shown = Show-PanelTip $p $case.Tool
		Check "translation, $($case.Name) tooltip of 100 characters (szText, 80): shown, no crash" ($shown -and (Test-Alive $p)) "tooltip shown: $shown, $(Get-ExitDetail $p)"
		Stop-Npp $p
	}

	# a theme's language description: the Style Configurator's "<language>: <style>" label is 257 characters
	$settings = New-Settings
	$model = Get-Content -Raw -LiteralPath (Join-Path (Split-Path $Exe) 'stylers.model.xml')
	Set-Content -LiteralPath (Join-Path $settings 'stylers.xml') -Encoding utf8 -NoNewline -Value ([regex]'(<LexerType name="[^"]*" desc=")[^"]*').Replace($model, '${1}' + ('D' * 250), 1)
	$p = Start-Npp -settings $settings
	Post $p.MainWindowHandle $WM_COMMAND $IDM_LANGSTYLE_CONFIG_DLG
	Start-Sleep -Seconds 2
	$combo = [PB.U]::GetDlgItem((Get-Dialog $p $IDC_LANGUAGES_COMBO), $IDC_LANGUAGES_COMBO)
	$i = SendText $combo 0x0158 -1 ('D' * 250) # CB_FINDSTRINGEXACT
	[void](Send $combo 0x014E $i) # CB_SETCURSEL
	Post ([PB.U]::GetParent($combo)) $WM_COMMAND ((1 -shl 16) -bor $IDC_LANGUAGES_COMBO) $combo.ToInt64() # CBN_SELCHANGE
	Check 'stylers.xml, a language description of 250 characters selected in the Style Configurator: no crash' (($i -gt 0) -and (Test-Alive $p)) "combo index $i, $(Get-ExitDetail $p)"
	Stop-Npp $p

	# folders longer than MAX_PATH, given with \\?\ (made the same way)
	$longDir = Join-Path $root (('d' * 120) + '\' + ('e' * 120) + '\' + ('f' * 60))
	[void][IO.Directory]::CreateDirectory('\\?\' + $longDir)
	[IO.File]::WriteAllText('\\?\' + (Join-Path $longDir 'a.txt'), 'text')
	$workspace = '<?xml version="1.0" encoding="UTF-8" ?><NotepadPlus><Project name="p"><File name="a.txt" /></Project></NotepadPlus>'
	[IO.File]::WriteAllText('\\?\' + (Join-Path $longDir 'ws.xml'), $workspace)
	$session = Join-Path $root 'long-root-session.xml' # a session needs a file, else its Folder as Workspace roots aren't read
	Set-Content -LiteralPath $session -Encoding utf8 -Value "<?xml version=`"1.0`" encoding=`"UTF-8`" ?>`n<NotepadPlus><Session activeView=`"0`"><mainView activeIndex=`"0`"><File filename=`"$file`" /></mainView><subView activeIndex=`"0`" /><FileBrowser latestSelectedItem=`"`"><root foldername=`"\\?\$longDir`" /></FileBrowser></Session></NotepadPlus>"
	$p = Start-Npp @('-openSession', "`"$session`"")
	$alive = Test-Alive $p
	$items = if ($alive) { Send (Get-PanelControl $p 'SysTreeView32') $TVM_GETCOUNT } else { -1 }
	Check "session file, a Folder as Workspace root of $($longDir.Length + 4) characters: shown, no crash" ($alive -and $items -ge 1) "tree items $items, $(Get-ExitDetail $p)"
	Stop-Npp $p
	$usual = Join-Path $root 'workspace'; New-Item -ItemType Directory -Force $usual | Out-Null
	Set-Content -LiteralPath (Join-Path $usual 'a.txt') -Value 'text'; Set-Content -LiteralPath (Join-Path $usual 'ws.xml') -Encoding utf8 -Value $workspace
	foreach ($case in @(@{ Name = "a project workspace of $($longDir.Length + 11) characters: refused (an empty workspace), no crash"; Path = "\\?\$longDir\ws.xml"; Items = 1; Exact = $true },
						@{ Name = 'a project workspace of a usual length: its project and file shown'; Path = (Join-Path $usual 'ws.xml'); Items = 3 })) {
		$settings = New-Settings
		Set-Content -LiteralPath (Join-Path $settings 'config.xml') -Encoding utf8 -Value "<?xml version=`"1.0`" encoding=`"UTF-8`" ?>`n<NotepadPlus><ProjectPanels><ProjectPanel id=`"0`" workSpaceFile=`"$($case.Path)`" /></ProjectPanels></NotepadPlus>"
		$p = Start-Npp -settings $settings
		Post $p.MainWindowHandle $WM_COMMAND $IDM_VIEW_PROJECT_PANEL_1
		$alive = Test-Alive $p
		$items = if ($alive) { Send (Get-PanelControl $p 'SysTreeView32') $TVM_GETCOUNT } else { -1 }
		Check "config.xml, $($case.Name)" ($alive -and $(if ($case.Exact) { $items -eq $case.Items } else { $items -ge $case.Items })) "tree items $items, $(Get-ExitDetail $p)"
		Stop-Npp $p
	}
}
finally {
	foreach ($q in @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $Exe -and $_.MainWindowTitle -match 'REVIEW-TEST' })) { Stop-Process -Id $q.Id -Force }
	$script:results
	"settings folders: $root"
	"{0} checks, {1} failed" -f $script:results.Count, $script:fails
}
