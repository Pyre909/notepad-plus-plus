# Screenshot of the Notepad++ toolbar with the standard icons (light mode), for a build. Windows PowerShell 5.1.
param([Parameter(Mandatory)] [string] $Exe, [Parameter(Mandatory)] [string] $Out, [string] $Dir)
$ErrorActionPreference = 'Stop'
if (-not $Dir) { $Dir = Join-Path $env:TEMP ('npp-tbshot-' + [IO.Path]::GetFileNameWithoutExtension($Out)) }
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System; using System.Text; using System.Drawing; using System.Runtime.InteropServices;
public static class Tb {
	[DllImport("user32.dll")] static extern bool SetProcessDpiAwarenessContext(IntPtr v);
	delegate bool EnumProc(IntPtr h, IntPtr l);
	[DllImport("user32.dll")] static extern bool EnumWindows(EnumProc f, IntPtr l);
	[DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr p, EnumProc f, IntPtr l);
	[DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
	[DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
	[DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
	[DllImport("user32.dll")] static extern bool GetClientRect(IntPtr h, out RECT r);
	[DllImport("user32.dll")] static extern bool PrintWindow(IntPtr h, IntPtr dc, uint f);
	[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
	[DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
	struct RECT { public int L, T, R, B; }
	public static void Aware() { SetProcessDpiAwarenessContext(new IntPtr(-4)); }
	public static IntPtr Top(uint pid) {
		IntPtr found = IntPtr.Zero;
		EnumWindows((h, l) => { uint p; GetWindowThreadProcessId(h, out p); var sb = new StringBuilder(64); GetClassName(h, sb, 64);
			if (p == pid && sb.ToString() == "Notepad++" && IsWindowVisible(h)) { found = h; return false; } return true; }, IntPtr.Zero);
		return found;
	}
	public static IntPtr Child(IntPtr top, string cls) {
		IntPtr found = IntPtr.Zero;
		EnumChildWindows(top, (h, l) => { var sb = new StringBuilder(64); GetClassName(h, sb, 64);
			if (sb.ToString() == cls && IsWindowVisible(h)) { found = h; return false; } return true; }, IntPtr.Zero);
		return found;
	}
	public static void Shot(IntPtr h, string path) {
		RECT r; GetClientRect(h, out r);
		using (var bmp = new Bitmap(r.R - r.L, r.B - r.T)) {
			using (var g = Graphics.FromImage(bmp)) { IntPtr dc = g.GetHdc(); PrintWindow(h, dc, 1 | 2); g.ReleaseHdc(dc); }
			bmp.Save(path, System.Drawing.Imaging.ImageFormat.Png);
		}
	}
}
'@
[Tb]::Aware()
New-Item -ItemType Directory -Force $Dir | Out-Null
function Run-Npp {
	$p = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$Dir" -PassThru
	for ($i = 0; $i -lt 60; $i++) { Start-Sleep -Milliseconds 250; $t = [Tb]::Top([uint32]$p.Id); if ($t -ne [IntPtr]::Zero) { break } }
	Start-Sleep -Milliseconds 1500
	return @{ P = $p; T = $t }
}
function Stop-Npp($n) { [void][Tb]::PostMessage($n.T, 0x10, [IntPtr]0, [IntPtr]0); $n.P.WaitForExit(15000) | Out-Null; if (-not $n.P.HasExited) { $n.P.Kill() } }

$cfg = Join-Path $Dir 'config.xml'
if (-not (Test-Path $cfg)) { Stop-Npp (Run-Npp) }
[xml]$x = Get-Content -Raw $cfg
$gc = $x.NotepadPlus.GUIConfigs.GUIConfig
($gc | Where-Object { $_.name -eq 'ToolBar' }).InnerText = 'standard'
$dm = $gc | Where-Object { $_.name -eq 'DarkMode' }
if ($dm) { $dm.SetAttribute('enable', 'no'); $dm.SetAttribute('lightToolBarIconSet', '4') }
$x.Save($cfg)

$n = Run-Npp
$tb = [Tb]::Child($n.T, 'ToolbarWindow32')
"dpi $([Tb]::GetDpiForWindow($n.T))"
[Tb]::Shot($tb, $Out)
Stop-Npp $n
"-> $Out"
