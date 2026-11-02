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
'@
$script:results = [Collections.Generic.List[string]]::new(); $script:fails = 0
function Check([string] $name, [bool] $ok, [string] $detail = '') {
	if (-not $ok) { $script:fails++ }
	$script:results.Add(("{0}  {1}{2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $(if ($detail) { "  [$detail]" } else { '' })))
}
function Send([IntPtr] $h, [int] $msg, [long] $w = 0, [long] $l = 0) { $r = [IntPtr]::Zero; [void][PB.U]::SendMessageTimeout($h, $msg, [IntPtr]$w, [IntPtr]$l, 2, 5000, [ref]$r); $r.ToInt64() }
$root = Join-Path ([IO.Path]::GetTempPath()) ('npp-review\plugin-api-bounds-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$script:n = 0
function Start-Npp([string[]] $extra = @()) {
	$settings = Join-Path $root ("s{0}" -f ++$script:n); New-Item -ItemType Directory -Force $settings | Out-Null
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
$NPPM_SETCURRENTLANGTYPE = 2024 + 6; $L_PHP = 1; $L_EXTERNAL = 114; $IDM_LANG_EXTERNAL = 46165
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
}
finally {
	foreach ($q in @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $Exe -and $_.MainWindowTitle -match 'REVIEW-TEST' })) { Stop-Process -Id $q.Id -Force }
	$script:results
	"settings folders: $root"
	"{0} checks, {1} failed" -f $script:results.Count, $script:fails
}
