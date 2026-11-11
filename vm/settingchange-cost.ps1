param([Parameter(Mandatory)] [string] $Exe, [string] $File = "$env:TEMP\npp-bench\files\code.cpp", [int] $Times = 5)
# The CPU Notepad++ spends after a WM_SETTINGCHANGE broadcast that doesn't concern Scintilla (lParam "Policy"), a large
# file wrapped and the Document Map shown: the process's CPU time over the 4 s after each, less an idle 4 s
Add-Type -Namespace SC -Name U -MemberDefinition @'
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, string l, uint flags, uint timeout, out IntPtr result);
[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
'@
$settings = Join-Path $env:TEMP ('npp-sc-' + [guid]::NewGuid().ToString('N').Substring(0, 6)); New-Item -ItemType Directory $settings | Out-Null
$p = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$settings", "`"$File`"" -PassThru
for ($i = 0; $i -lt 100 -and $p.MainWindowHandle -eq 0; $i++) { Start-Sleep -Milliseconds 100; $p.Refresh() }
Start-Sleep -Milliseconds 1500
$r = [IntPtr]::Zero
[void][SC.U]::SendMessageTimeout($p.MainWindowHandle, 0x0111, [IntPtr]44022, [IntPtr]::Zero, 2, 20000, [ref]$r) # word wrap
[void][SC.U]::SendMessageTimeout($p.MainWindowHandle, 0x0111, [IntPtr]44080, [IntPtr]::Zero, 2, 20000, [ref]$r) # Document Map
Start-Sleep -Seconds 6
function Cpu { $p.Refresh(); $p.TotalProcessorTime.TotalMilliseconds }
$c0 = Cpu; Start-Sleep -Seconds 4; $idle = (Cpu) - $c0
$costs = foreach ($i in 1..$Times) {
	$c0 = Cpu
	[void][SC.U]::SendMessageTimeout($p.MainWindowHandle, 0x001A, [IntPtr]::Zero, 'Policy', 2, 20000, [ref]$r) # WM_SETTINGCHANGE
	Start-Sleep -Seconds 4
	(Cpu) - $c0 - $idle
}
"idle 4 s: {0:N0} ms CPU; after a ""Policy"" WM_SETTINGCHANGE: {1} ms CPU (median {2:N0})" -f $idle, (($costs | ForEach-Object { '{0:N0}' -f $_ }) -join ', '), ($costs | Sort-Object)[[int]($Times / 2)]
Stop-Process -Id $p.Id -Force; [void]$p.WaitForExit(5000)
Remove-Item -LiteralPath $settings -Recurse -Force
