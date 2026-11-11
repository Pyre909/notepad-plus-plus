param([Parameter(Mandatory)] [string] $Exe, [int] $Lines = 100000)
# The bookmarked lines' operations on a file of $Lines lines, every 3rd line bookmarked: Remove Unmarked Lines, Remove
# Bookmarked Lines, Cut Bookmarked Lines (each on a fresh copy of the text, the time of the command), and the text left
# (its length and a hash: the same with every build)
Add-Type -Namespace ML -Name U -MemberDefinition @'
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr p, IntPtr after, string cls, string title);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
'@
function Send([IntPtr] $h, [int] $m, [long] $w = 0, [long] $l = 0) { $r = [IntPtr]::Zero; [void][ML.U]::SendMessageTimeout($h, $m, [IntPtr]$w, [IntPtr]$l, 2, 600000, [ref]$r); $r.ToInt64() }
$dir = Join-Path $env:TEMP ('npp-ml-' + [guid]::NewGuid().ToString('N').Substring(0, 6)); New-Item -ItemType Directory $dir | Out-Null
$file = Join-Path $dir 'marked.log'
[IO.File]::WriteAllLines($file, [string[]](1..$Lines | ForEach-Object { "2026-11-10 12:00:00 [INFO] worker-$($_ % 16): request $_ done in $($_ % 1000) ms" }))
$settings = Join-Path $dir 'settings'; New-Item -ItemType Directory $settings | Out-Null
$p = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$settings", "`"$file`"" -PassThru
for ($i = 0; $i -lt 100 -and $p.MainWindowHandle -eq 0; $i++) { Start-Sleep -Milliseconds 100; $p.Refresh() }
Start-Sleep -Milliseconds 1500
$m = $p.MainWindowHandle
$view = [IntPtr]::Zero; $h = [IntPtr]::Zero
while (($h = [ML.U]::FindWindowEx($m, $h, 'Scintilla', [NullString]::Value)) -ne [IntPtr]::Zero) { if ($view -eq [IntPtr]::Zero -and [ML.U]::IsWindowVisible($h)) { $view = $h } }
$SCI_MARKERADD = 2043; $SCI_UNDO = 2176; $SCI_GETLENGTH = 2006; $SCI_GETLINECOUNT = 2154; $SCI_MARKERDELETEALL = 2045
$commands = [ordered]@{ 'Copy Bookmarked Lines' = 43019; 'Remove Unmarked Lines' = 43051; 'Remove Bookmarked Lines' = 43021; 'Cut Bookmarked Lines' = 43018 } # IDM_SEARCH_*
foreach ($name in $commands.Keys) {
	[void](Send $view $SCI_MARKERDELETEALL 20)
	for ($line = 0; $line -lt $Lines; $line += 3) { [void](Send $view $SCI_MARKERADD $line 20) } # MARK_BOOKMARK
	$sw = [Diagnostics.Stopwatch]::StartNew()
	[void](Send $m 0x0111 $commands[$name])
	$ms = $sw.Elapsed.TotalMilliseconds
	$clip = if ($name -like '*Bookmarked Lines' -and $name -notlike 'Remove*') { $c = Get-Clipboard -Raw; ', clipboard {0:N0} chars {1}' -f $c.Length, ([BitConverter]::ToString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($c))).Substring(0, 11)) } else { '' }
	"{0,-24} {1,9:N0} ms, left: {2:N0} lines, {3:N0} bytes{4}" -f $name, $ms, (Send $view $SCI_GETLINECOUNT), (Send $view $SCI_GETLENGTH), $clip
	if ($name -ne 'Copy Bookmarked Lines') { [void](Send $view $SCI_UNDO) } # the text back, one undo action
	if ((Send $view $SCI_GETLINECOUNT) -ne $Lines + 1) { "  undo left $(Send $view $SCI_GETLINECOUNT) lines" }
}
Stop-Process -Id $p.Id -Force; [void]$p.WaitForExit(5000)
Remove-Item -LiteralPath $dir -Recurse -Force
