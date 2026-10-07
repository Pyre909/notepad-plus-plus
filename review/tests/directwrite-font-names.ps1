# App-level test (review harness): the fonts of a weight, such as "Bahnschrift Light", drawn by DirectWrite with their
# own font (#12393, FontFamilyNames.cpp). The font lists name them by their GDI family name, which DirectWrite only
# knows as the Light weight of "Bahnschrift": with DirectWrite a style gets "Bahnschrift" at weight 300 (its bold at
# SemiBold, 600), with GDI the name as it is (bold at 700). Run twice: DirectWrite (the default of fresh settings), then
# GDI (writeTechnologyEngine="0" in the config.xml the first run wrote).
# Contract of review\tests: -Exe <notepad++.exe>; PASS/FAIL lines; last line "<n> checks, <m> failed".
param([Parameter(Mandatory)] [string] $Exe)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path (Join-Path $env:WINDIR 'Fonts\bahnschrift.ttf'))) { 'INFO  no Bahnschrift font: skipped'; '0 checks, 0 failed'; exit }
# a Pyre909 build names itself in its About box (PYRE_BUILD_TAG in AboutDlg.cpp)
$isPyre = [Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($Exe)).Contains('Pyre909 build')
Add-Type -Namespace FN -Name U -MemberDefinition @'
public delegate bool EnumProc(IntPtr h, IntPtr l);
[DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
[DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EnumProc f, IntPtr l);
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, System.Text.StringBuilder s, int n);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, System.Text.StringBuilder s, int n);
[DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h, int id);
[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
[DllImport("kernel32.dll")] static extern IntPtr OpenProcess(uint access, bool inherit, uint pid);
[DllImport("kernel32.dll")] static extern IntPtr VirtualAllocEx(IntPtr h, IntPtr addr, UIntPtr size, uint type, uint protect);
[DllImport("kernel32.dll")] static extern bool VirtualFreeEx(IntPtr h, IntPtr addr, UIntPtr size, uint type);
[DllImport("kernel32.dll")] static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, UIntPtr size, out UIntPtr read);
[DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
static long Send(IntPtr h, uint m, long w) { IntPtr r; SendMessageTimeout(h, m, (IntPtr)w, IntPtr.Zero, 2, 3000, out r); return r.ToInt64(); }
// a style's font name (SCI_STYLEGETFONT, into a buffer of the Scintilla's process, read back), weight, stretch and italic
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
  // SCI_STYLEGETWEIGHT, SCI_STYLEGETSTRETCH, SCI_STYLEGETITALIC
  return name + "/" + Send(view, 2064, style) + "/" + Send(view, 2259, style) + "/" + Send(view, 2484, style);
}
'@
$WM_CLOSE = 0x0010; $WM_COMMAND = 0x0111
$STYLE_DEFAULT = 32; $STYLE_LINENUMBER = 33; $SCE_C_WORD = 5 # bold in stylers.model.xml ("INSTRUCTION WORD")

function Get-Cls([IntPtr] $h) { $sb = [Text.StringBuilder]::new(64); [void][FN.U]::GetClassName($h, $sb, 64); $sb.ToString() }
function Get-Txt([IntPtr] $h) { $sb = [Text.StringBuilder]::new(512); [void][FN.U]::GetWindowText($h, $sb, 512); $sb.ToString() }
function Get-Tops { $script:acc = [Collections.Generic.List[IntPtr]]::new(); [void][FN.U]::EnumWindows({ param($h, $l) $p = 0; [void][FN.U]::GetWindowThreadProcessId($h, [ref]$p); if ($p -eq $script:npid) { $script:acc.Add($h) }; $true }, [IntPtr]::Zero); $script:acc.ToArray() }
function Get-Kids([IntPtr] $p) { $script:kids = [Collections.Generic.List[IntPtr]]::new(); [void][FN.U]::EnumChildWindows($p, { param($h, $l) $script:kids.Add($h); $true }, [IntPtr]::Zero); $script:kids.ToArray() }
function Send([IntPtr] $h, [int] $msg, [long] $w = 0, [long] $l = 0) { $r = [IntPtr]::Zero; [void][FN.U]::SendMessageTimeout($h, $msg, [IntPtr]$w, [IntPtr]$l, 2, 5000, [ref]$r); $r.ToInt64() }
$script:results = [Collections.Generic.List[string]]::new(); $script:fails = 0
function Check([string] $name, [bool] $ok, [string] $detail = '') {
	if (-not $ok) { $script:fails++ }
	$script:results.Add(("{0}  {1}{2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $(if ($detail) { "  [$detail]" } else { '' })))
}
function Check-Font([string] $name, [int] $style, [string] $expected) {
	$font = [FN.U]::StyleFont($script:view, $script:npid, $style)
	Check $name ($font -ceq $expected) "style ${style}: $font"
}

# Notepad++ with the settings folder, the main view in $script:view; on exit no message (a "Save file?" answered No)
function Start-Npp {
	$script:proc = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$settings", '-titleAdd=REVIEW-TEST', $file -PassThru
	$script:npid = [uint32]$script:proc.Id
	for ($i = 0; $i -lt 100; $i++) { $script:proc.Refresh(); if ($script:proc.MainWindowHandle -ne 0) { break }; Start-Sleep -Milliseconds 100 }
	$script:main = $script:proc.MainWindowHandle; Start-Sleep -Milliseconds 800
	$script:view = Get-Kids $script:main | Where-Object { (Get-Cls $_) -eq 'Scintilla' -and [FN.U]::IsWindowVisible($_) -and [FN.U]::GetParent($_) -eq $script:main } | Select-Object -First 1
}
function Stop-Npp([string] $run) {
	[void][FN.U]::PostMessage($script:main, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero)
	$boxes = @()
	for ($i = 0; $i -lt 60 -and -not $script:proc.HasExited; $i++) {
		Start-Sleep -Milliseconds 250
		foreach ($b in @(Get-Tops | Where-Object { (Get-Cls $_) -eq '#32770' -and [FN.U]::IsWindowVisible($_) })) {
			$boxes += (Get-Txt $b) + ': ' + ((Get-Kids $b | ForEach-Object { Get-Txt $_ } | Where-Object { $_ }) -join ' | ')
			$no = [FN.U]::GetDlgItem($b, 7); if ($no -ne [IntPtr]::Zero) { [void][FN.U]::PostMessage($b, $WM_COMMAND, [IntPtr]7, $no) } else { [void][FN.U]::PostMessage($b, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero) }
		}
	}
	Check "${run}: exit without message" ($boxes.Count -eq 0) ($boxes -join '; ')
	$exited = $script:proc.WaitForExit(15000)
	Check "${run}: Notepad++ closes normally" ($exited -and $script:proc.ExitCode -eq 0) $(if ($exited) { "exit code $($script:proc.ExitCode)" } else { 'still running' })
}

# a settings folder of its own, its Default Style in "Bahnschrift Light"; a C++ file for a bold style
$settings = Join-Path ([IO.Path]::GetTempPath()) ('npp-review\directwrite-font-names-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force $settings | Out-Null
$model = Join-Path (Split-Path $Exe) 'stylers.model.xml'
$bytes = [IO.File]::ReadAllBytes($model); $hasBom = ($bytes.Length -ge 3) -and ($bytes[0] -eq 0xEF) -and ($bytes[1] -eq 0xBB) -and ($bytes[2] -eq 0xBF)
$stylers = [IO.File]::ReadAllText($model) -replace '(<WidgetStyle name="Default Style" styleID="32"[^>]*?)fontName="[^"]*"', '$1fontName="Bahnschrift Light"'
[IO.File]::WriteAllText((Join-Path $settings 'stylers.xml'), $stylers, [Text.UTF8Encoding]::new($hasBom))
$file = Join-Path $settings 'test.cpp'; [IO.File]::WriteAllLines($file, [string[]]@('int main() { return 0; } // Bahnschrift Light'))
try {
	Start-Npp
	Check 'DirectWrite run: the view uses DirectWrite' ((Send $script:view 2631) -ne 0) "technology $(Send $script:view 2631)"
	Check-Font 'Default Style: the DirectWrite family at weight Light' $STYLE_DEFAULT 'Bahnschrift/300/5/0'
	Check-Font 'a style without a font of its own: the same' 0 'Bahnschrift/300/5/0'
	Check-Font 'line numbers: the same' $STYLE_LINENUMBER 'Bahnschrift/300/5/0'
	Check-Font 'a bold style: bold relative to Light, SemiBold' $SCE_C_WORD 'Bahnschrift/600/5/0'
	Stop-Npp 'DirectWrite run'

	$config = Join-Path $settings 'config.xml'
	$configText = [IO.File]::ReadAllText($config)
	Check 'config.xml names the rendering technology' ($configText -match 'writeTechnologyEngine="\d"')
	[IO.File]::WriteAllText($config, ($configText -replace 'writeTechnologyEngine="\d"', 'writeTechnologyEngine="0"'), [Text.UTF8Encoding]::new($false))

	Start-Npp
	Check 'GDI run: the view uses GDI' ((Send $script:view 2631) -eq 0) "technology $(Send $script:view 2631)"
	if ($isPyre) {
		# a Pyre909 build draws the bold of a font of a weight with the font DirectWrite draws, under GDI too
		Check-Font 'Default Style: the GDI name at the weight GDI knows it by (Pyre909 build)' $STYLE_DEFAULT 'Bahnschrift Light/300/5/0'
		Check-Font 'a bold style: the GDI family of the SemiBold font (Pyre909 build)' $SCE_C_WORD 'Bahnschrift SemiBold/600/5/0'
	}
	else {
		Check-Font 'Default Style: the GDI name as it is' $STYLE_DEFAULT 'Bahnschrift Light/400/5/0'
		Check-Font 'a bold style: the GDI name, bold' $SCE_C_WORD 'Bahnschrift Light/700/5/0'
	}
	Stop-Npp 'GDI run'
}
finally {
	if ($script:proc -and -not $script:proc.HasExited) { [void][FN.U]::PostMessage($script:main, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero); if (-not $script:proc.WaitForExit(10000)) { Stop-Process -Id $script:proc.Id -Force } }
	$script:results
	"settings folder: $settings"
	"{0} checks, {1} failed" -f $script:results.Count, $script:fails
}
