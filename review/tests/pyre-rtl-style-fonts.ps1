# App-level test (review harness), Pyre909 builds only: the style fonts follow the technology of their view. pyre maps a
# font of the font lists for the technology in use ("Bahnschrift Light" is "Bahnschrift" at weight 300 for DirectWrite,
# see FontFamilyNames.cpp). A view that switches technology, with its text direction (right-to-left views are drawn
# with GDI) or with the rendering mode, gets its style fonts mapped again (ScintillaEditView::refreshStyleFonts); else
# DirectWrite would draw a GDI name with a fallback font, and GDI a DirectWrite family at the wrong weight.
# Contract of review\tests: -Exe <notepad++.exe>; PASS/FAIL lines; last line "<n> checks, <m> failed".
param([Parameter(Mandatory)] [string] $Exe)
$ErrorActionPreference = 'Stop'
# a Pyre909 build names itself in its About box (PYRE_BUILD_TAG in AboutDlg.cpp)
if (-not [Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($Exe)).Contains('Pyre909 build')) {
	'INFO  not a Pyre909 build: skipped'; '0 checks, 0 failed'; exit
}
if (-not (Test-Path (Join-Path $env:WINDIR 'Fonts\bahnschrift.ttf'))) { 'INFO  no Bahnschrift font: skipped'; '0 checks, 0 failed'; exit }
Add-Type -Namespace PF -Name U -MemberDefinition @'
public delegate bool EnumProc(IntPtr h, IntPtr l);
[DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
[DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EnumProc f, IntPtr l);
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, System.Text.StringBuilder s, int n);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, System.Text.StringBuilder s, int n);
[DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h, int id);
[DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
[DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int idx);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
[DllImport("kernel32.dll")] static extern IntPtr OpenProcess(uint access, bool inherit, uint pid);
[DllImport("kernel32.dll")] static extern IntPtr VirtualAllocEx(IntPtr h, IntPtr addr, UIntPtr size, uint type, uint protect);
[DllImport("kernel32.dll")] static extern bool VirtualFreeEx(IntPtr h, IntPtr addr, UIntPtr size, uint type);
[DllImport("kernel32.dll")] static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, UIntPtr size, out UIntPtr read);
[DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
// SCI_STYLEGETFONT writes the name into a buffer of the Scintilla's process: one is allocated there, then read back
public static string StyleFont(IntPtr view, uint pid, int style) {
  IntPtr proc = OpenProcess(0x0008 | 0x0010 | 0x0020, false, pid); // PROCESS_VM_OPERATION | VM_READ | VM_WRITE
  if (proc == IntPtr.Zero) return "?";
  IntPtr mem = VirtualAllocEx(proc, IntPtr.Zero, (UIntPtr)256, 0x3000, 0x04); // MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE
  string name = "?";
  if (mem != IntPtr.Zero) {
    IntPtr r;
    SendMessageTimeout(view, 2486, (IntPtr)style, mem, 2, 3000, out r); // SCI_STYLEGETFONT
    byte[] buf = new byte[256]; UIntPtr n;
    if (ReadProcessMemory(proc, mem, buf, (UIntPtr)256, out n)) { int len = Array.IndexOf(buf, (byte)0); name = System.Text.Encoding.UTF8.GetString(buf, 0, len < 0 ? 256 : len); }
    VirtualFreeEx(proc, mem, UIntPtr.Zero, 0x8000); // MEM_RELEASE
  }
  CloseHandle(proc);
  return name;
}
'@
$WM_CLOSE = 0x0010; $WM_COMMAND = 0x0111; $CB_SETCURSEL = 0x014E
$IDM_FILE_NEW = 41001; $IDM_EDIT_RTL = 42026; $IDM_EDIT_LTR = 42027; $IDM_VIEW_TAB1 = 44086; $IDM_VIEW_TAB2 = 44087; $IDM_SETTING_PREFERENCE = 48011
$STYLE_DEFAULT = 32; $STYLE_LINENUMBER = 33

function Get-Cls([IntPtr] $h) { $sb = [Text.StringBuilder]::new(64); [void][PF.U]::GetClassName($h, $sb, 64); $sb.ToString() }
function Get-Txt([IntPtr] $h) { $sb = [Text.StringBuilder]::new(512); [void][PF.U]::GetWindowText($h, $sb, 512); $sb.ToString() }
function Get-Tops { $script:acc = [Collections.Generic.List[IntPtr]]::new(); [void][PF.U]::EnumWindows({ param($h, $l) $p = 0; [void][PF.U]::GetWindowThreadProcessId($h, [ref]$p); if ($p -eq $script:npid) { $script:acc.Add($h) }; $true }, [IntPtr]::Zero); $script:acc.ToArray() }
function Get-Kids([IntPtr] $p) { $script:kids = [Collections.Generic.List[IntPtr]]::new(); [void][PF.U]::EnumChildWindows($p, { param($h, $l) $script:kids.Add($h); $true }, [IntPtr]::Zero); $script:kids.ToArray() }
function Send([IntPtr] $h, [int] $msg, [long] $w = 0, [long] $l = 0) { $r = [IntPtr]::Zero; [void][PF.U]::SendMessageTimeout($h, $msg, [IntPtr]$w, [IntPtr]$l, 2, 5000, [ref]$r); $r.ToInt64() }
function Cmd([int] $id) { [void](Send $script:main $WM_COMMAND $id); Start-Sleep -Milliseconds 300 }
function Select-Mode([int] $idx) {
	[void][PF.U]::SendMessage($script:combo, $CB_SETCURSEL, [IntPtr]$idx, [IntPtr]::Zero)
	[void](Send $script:misc $WM_COMMAND ((1 -shl 16) -bor 6362) $script:combo.ToInt64()); Start-Sleep -Milliseconds 300
}
$script:results = [Collections.Generic.List[string]]::new(); $script:fails = 0
function Check([string] $name, [bool] $ok, [string] $detail = '') {
	if (-not $ok) { $script:fails++ }
	$script:results.Add(("{0}  {1}{2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $(if ($detail) { "  [$detail]" } else { '' })))
}
# the font of the Default Style, the line numbers and an unset lexer style (0), with the technology and direction
function Check-Fonts([string] $name, [string] $expected) {
	$fonts = @($STYLE_DEFAULT, $STYLE_LINENUMBER, 0 | ForEach-Object { [PF.U]::StyleFont($script:view, $script:npid, $_) })
	$state = "technology {0}, {1}" -f (Send $script:view 2631), $(if (([PF.U]::GetWindowLong($script:view, -20) -band 0x00400000) -ne 0) { 'RTL' } else { 'LTR' })
	Check $name (@($fonts | Where-Object { $_ -cne $expected }).Count -eq 0) ("{0}: {1}" -f $state, ($fonts -join ' / '))
}

# a settings folder of its own, its Default Style in "Bahnschrift Light"
$settings = Join-Path ([IO.Path]::GetTempPath()) ('npp-review\pyre-rtl-style-fonts-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force $settings | Out-Null
$model = Join-Path (Split-Path $Exe) 'stylers.model.xml'
$bytes = [IO.File]::ReadAllBytes($model); $hasBom = ($bytes.Length -ge 3) -and ($bytes[0] -eq 0xEF) -and ($bytes[1] -eq 0xBB) -and ($bytes[2] -eq 0xBF)
$stylers = [IO.File]::ReadAllText($model) -replace '(<WidgetStyle name="Default Style" styleID="32"[^>]*?)fontName="[^"]*"', '$1fontName="Bahnschrift Light"'
[IO.File]::WriteAllText((Join-Path $settings 'stylers.xml'), $stylers, [Text.UTF8Encoding]::new($hasBom))
$file = Join-Path $settings 'test.txt'; [IO.File]::WriteAllLines($file, [string[]]@('Bahnschrift Light', 'abc 123'))
$proc = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$settings", '-titleAdd=REVIEW-TEST', $file -PassThru
$script:npid = [uint32]$proc.Id
try {
	for ($i = 0; $i -lt 100; $i++) { $proc.Refresh(); if ($proc.MainWindowHandle -ne 0) { break }; Start-Sleep -Milliseconds 100 }
	$script:main = $proc.MainWindowHandle; Start-Sleep -Milliseconds 800
	$script:view = Get-Kids $script:main | Where-Object { (Get-Cls $_) -eq 'Scintilla' -and [PF.U]::IsWindowVisible($_) -and [PF.U]::GetParent($_) -eq $script:main } | Select-Object -First 1

	Check-Fonts 'start with DirectWrite (fresh settings default): the DirectWrite family' 'Bahnschrift'
	Cmd $IDM_EDIT_RTL; Check-Fonts 'RTL: the view on GDI, the GDI name' 'Bahnschrift Light'
	Cmd $IDM_EDIT_LTR; Check-Fonts 'LTR again: DirectWrite, its family' 'Bahnschrift'

	Cmd $IDM_SETTING_PREFERENCE
	for ($i = 0; $i -lt 50 -and -not $script:misc; $i++) {
		Start-Sleep -Milliseconds 100
		$script:pref = Get-Tops | Where-Object { (Get-Cls $_) -eq '#32770' -and (Get-Txt $_) -eq 'Preferences' } | Select-Object -First 1
		if ($script:pref) { $script:misc = Get-Kids $script:pref | Where-Object { [PF.U]::GetDlgItem($_, 6362) -ne [IntPtr]::Zero } | Select-Object -First 1 }
	}
	$script:combo = [PF.U]::GetDlgItem($script:misc, 6362)
	Check 'rendering mode box found' ($script:combo -ne [IntPtr]::Zero)
	Select-Mode 0; Check-Fonts 'switch to GDI: the GDI name' 'Bahnschrift Light'
	Select-Mode 4; Check-Fonts 'switch to DX11: the DirectWrite family' 'Bahnschrift'
	Select-Mode 1

	# an RTL document in another tab: its view switches technology, and fonts, with the tabs
	Cmd $IDM_FILE_NEW; Cmd $IDM_EDIT_RTL; Check-Fonts 'new RTL document: the GDI name' 'Bahnschrift Light'
	Cmd $IDM_VIEW_TAB1; Check-Fonts 'its LTR neighbour tab: the DirectWrite family' 'Bahnschrift'
	Cmd $IDM_VIEW_TAB2; Check-Fonts 'the RTL tab again: the GDI name' 'Bahnschrift Light'
	Select-Mode 0; Select-Mode 1; Check-Fonts 'GDI and back to DirectWrite, the RTL tab shown: still the GDI name' 'Bahnschrift Light'
	Cmd $IDM_VIEW_TAB1; Check-Fonts 'then its LTR neighbour: the DirectWrite family' 'Bahnschrift'

	# no message on exit; a "Save file?" means a document was modified (maybe by input typed into the test window): answered No
	[void][PF.U]::PostMessage($script:main, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero)
	$boxes = @()
	for ($i = 0; $i -lt 60 -and -not $proc.HasExited; $i++) {
		Start-Sleep -Milliseconds 250
		foreach ($b in @(Get-Tops | Where-Object { (Get-Cls $_) -eq '#32770' -and [PF.U]::IsWindowVisible($_) -and $_ -ne $script:pref })) {
			$boxes += (Get-Txt $b) + ': ' + ((Get-Kids $b | ForEach-Object { Get-Txt $_ } | Where-Object { $_ }) -join ' | ')
			$no = [PF.U]::GetDlgItem($b, 7); if ($no -ne [IntPtr]::Zero) { [void][PF.U]::PostMessage($b, $WM_COMMAND, [IntPtr]7, $no) } else { [void][PF.U]::PostMessage($b, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero) }
		}
	}
	Check 'exit: no message' ($boxes.Count -eq 0) ($boxes -join '; ')
	$exited = $proc.WaitForExit(15000)
	Check 'Notepad++ closes normally' ($exited -and $proc.ExitCode -eq 0) $(if ($exited) { "exit code $($proc.ExitCode)" } else { 'still running' })
}
finally {
	if (-not $proc.HasExited) { [void][PF.U]::PostMessage($script:main, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero); if (-not $proc.WaitForExit(10000)) { Stop-Process -Id $proc.Id -Force } }
	$script:results
	"settings folder: $settings"
	"{0} checks, {1} failed" -f $script:results.Count, $script:fails
}
