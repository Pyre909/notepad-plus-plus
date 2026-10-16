# UMDH (Debugging Tools for Windows) lists the heap allocations of a process with the call stack that made each, which
# needs Windows to record those stacks: the user-mode stack trace database, GlobalFlag 0x1000 (FLG_USER_STACK_TRACE_DB,
# "gflags +ust") in Image File Execution Options. "gflags /i notepad++.exe +ust" would set it for every notepad++.exe,
# the installed one too; this script sets it only for the test builds, by full path (IFEO's UseFilter and FilterFullPath).
# Run as administrator (HKLM):
#   pwsh -File umdh-scope.ps1            the test builds' paths (the clone's, the worktrees' binarm64\Notepad++.exe)
#   pwsh -File umdh-scope.ps1 -Remove    everything this script set, back as before
#   pwsh -File umdh-scope.ps1 -List      what is set (no administrator needed)
param([switch] $Remove, [switch] $List, [string[]] $Exe = @())
$ErrorActionPreference = 'Stop'
$Exe = @($Exe | ForEach-Object { $_ -split '[,;]' } | Where-Object { $_ })  # pwsh -File passes a list as one string
$key = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\notepad++.exe'
$prefix = 'npp-umdh-'  # the subkeys this script makes; anything else under the key is left alone
$FLG_USER_STACK_TRACE_DB = 0x1000
# on Windows 11 ARM64 Notepad++'s heaps are segment heaps (signature ddeeddee), which record no stacks: the test builds
# get the NT heap instead (FrontEndHeapDebugOptions bit 0x4 disables the segment heap)
$NO_SEGMENT_HEAP = 0x4
$traceDbMB = 512  # Windows' default database fills up while Notepad++ starts ("gflags /tracedb")

if ($List) {
	if (-not (Test-Path $key)) { 'nothing set for notepad++.exe'; return }
	"UseFilter = $((Get-ItemProperty $key).UseFilter), StackTraceDatabaseSizeInMb = $((Get-ItemProperty $key).StackTraceDatabaseSizeInMb)"
	Get-ChildItem $key | ForEach-Object { $p = Get-ItemProperty $_.PSPath; '{0}: GlobalFlag 0x{1:X}, {2} MB, FrontEndHeapDebugOptions {3}, {4}' -f $_.PSChildName, $p.GlobalFlag, $p.StackTraceDatabaseSizeInMb, $p.FrontEndHeapDebugOptions, $p.FilterFullPath }
	return
}

if ($Remove) {
	if (-not (Test-Path $key)) { 'nothing to remove'; return }
	Get-ChildItem $key | Where-Object { $_.PSChildName -like "$prefix*" } | ForEach-Object { Remove-Item $_.PSPath -Recurse; "removed $($_.PSChildName)" }
	if (@(Get-ChildItem $key).Count -eq 0) {
		$values = @((Get-Item $key).GetValueNames() | Where-Object { $_ -notin 'UseFilter', 'StackTraceDatabaseSizeInMb' })
		if ($values.Count -eq 0) { Remove-Item $key; 'removed the notepad++.exe key (it held only this setting)' }
		else { Remove-ItemProperty $key -Name UseFilter, StackTraceDatabaseSizeInMb -ErrorAction SilentlyContinue; 'UseFilter and the size removed, the key kept (other values)' }
	}
	return
}

if ($Exe.Count -eq 0) {
	# the test builds: the clone and every worktree of it, binarm64 (the AddressSanitizer build is left out: its own
	# allocator replaces the heap UMDH reads)
	$roots = @(& git -C $PSScriptRoot worktree list --porcelain | Where-Object { $_ -like 'worktree *' } | ForEach-Object { $_.Substring(9) })
	$Exe = @($roots | Where-Object { (Split-Path $_ -Leaf) -ne 'asan' } | ForEach-Object { Join-Path ($_ -replace '/', '\') 'PowerEditor\binarm64\Notepad++.exe' })
}
if (-not (Test-Path $key)) { New-Item $key | Out-Null }
Set-ItemProperty $key -Name UseFilter -Value 1 -Type DWord
# the size is read from the image's key, not the filter's subkey; it only sizes the database, on for the paths below
Set-ItemProperty $key -Name StackTraceDatabaseSizeInMb -Value $traceDbMB -Type DWord
$i = 0
foreach ($path in $Exe) {
	$sub = Join-Path $key ('{0}{1}' -f $prefix, $i++)
	if (-not (Test-Path $sub)) { New-Item $sub | Out-Null }
	Set-ItemProperty $sub -Name FilterFullPath -Value $path -Type String
	Set-ItemProperty $sub -Name GlobalFlag -Value $FLG_USER_STACK_TRACE_DB -Type DWord
	Set-ItemProperty $sub -Name StackTraceDatabaseSizeInMb -Value $traceDbMB -Type DWord
	Set-ItemProperty $sub -Name FrontEndHeapDebugOptions -Value $NO_SEGMENT_HEAP -Type DWord
	"stack trace database on for $path"
}
