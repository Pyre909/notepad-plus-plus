# App-level test (review harness): the main menu's colour samples (Search > Jump Up/Down and the style menus' first items,
# View > Tab > Apply Color) made again 100 times, as the Style Configurator does after each colour change and on Cancel
# (WM_UPDATEMAINMENUBITMAPS): no GDI object more, every item keeps its bitmap, the same bitmap for the same colour.
# Upstream made 11 new bitmaps each time and never deleted the previous ones (the context menus share them): 1,100 GDI
# objects leaked over 100 updates (measured on 2026-10-20); with the fix they're cached by colour (branch
# menu-colour-bitmaps_20261020, pyre since 2026-10-20). This leak is upstream's: other branches fail this test.
# Contract of review\tests: -Exe <notepad++.exe>; PASS/FAIL lines; last line "<n> checks, <m> failed".
param([Parameter(Mandatory)] [string] $Exe, [int] $Count = 100)
$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices;
public static class MB {
	[StructLayout(LayoutKind.Sequential)] public struct MENUITEMINFO {
		public uint cbSize, fMask, fType, fState, wID; public IntPtr hSubMenu, hbmpChecked, hbmpUnchecked, dwItemData, dwTypeData; public uint cch; public IntPtr hbmpItem;
	}
	[DllImport("user32.dll")] public static extern IntPtr GetMenu(IntPtr h);
	[DllImport("user32.dll")] public static extern bool GetMenuItemInfo(IntPtr hMenu, uint item, bool byPosition, ref MENUITEMINFO mii);
	[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
	[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
	[DllImport("user32.dll")] public static extern uint GetGuiResources(IntPtr hProcess, uint flags);
	public static IntPtr CheckedBitmap(IntPtr hMenu, uint id) {
		var mii = new MENUITEMINFO(); mii.cbSize = (uint)Marshal.SizeOf(typeof(MENUITEMINFO)); mii.fMask = 0x8; // MIIM_CHECKMARKS
		return GetMenuItemInfo(hMenu, id, false, ref mii) ? mii.hbmpChecked : IntPtr.Zero;
	}
}
'@
$WM_CLOSE = 0x0010; $WM_UPDATEMAINMENUBITMAPS = 0x0400 + 5000 + 2   # WORDSTYLE_USER + 2
# IDM_SEARCH_GONEXTMARKER1-5 and _DEF (one bitmap each, shared with their style's other items), IDM_VIEW_TAB_COLOUR_1-5
$items = [ordered]@{}; 1..5 | ForEach-Object { $items["Jump to style $_"] = 43038 + $_ }; $items['Jump to default style'] = 43044
1..5 | ForEach-Object { $items["Tab colour $_"] = 44110 + $_ }

$results = [Collections.Generic.List[string]]::new(); $fails = 0
function Check([string] $name, [bool] $ok, [string] $detail = '') {
	if (-not $ok) { $script:fails++ }
	$results.Add(("{0}  {1}{2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $(if ($detail) { "  [$detail]" } else { '' })))
}
function Get-Bitmaps { $m = [ordered]@{}; foreach ($k in $items.Keys) { $m[$k] = [MB]::CheckedBitmap($script:menu, [uint32]$items[$k]) }; $m }
function Gdi { $script:proc.Refresh(); [MB]::GetGuiResources($script:proc.Handle, 0) }

$settings = Join-Path ([IO.Path]::GetTempPath()) ('npp-review\menu-colour-bitmaps-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force $settings | Out-Null
$script:proc = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$settings", '-titleAdd=REVIEW-TEST' -PassThru
try {
	for ($i = 0; $i -lt 100 -and $script:proc.MainWindowHandle -eq 0; $i++) { Start-Sleep -Milliseconds 100; $script:proc.Refresh() }
	$main = $script:proc.MainWindowHandle; Start-Sleep -Milliseconds 1500
	$script:menu = [MB]::GetMenu($main)
	$before = Get-Bitmaps
	$missing = @($before.Keys | Where-Object { $before[$_] -eq [IntPtr]::Zero })
	Check 'at start: every colour item has its bitmap' ($missing.Count -eq 0) $(if ($missing) { 'none: ' + ($missing -join ', ') } else { "$($items.Count) items" })

	$r = [IntPtr]::Zero
	[void][MB]::SendMessageTimeout($main, $WM_UPDATEMAINMENUBITMAPS, [IntPtr]::Zero, [IntPtr]::Zero, 2, 5000, [ref]$r)   # first update: the cache filled
	$gdi0 = Gdi
	for ($i = 0; $i -lt $Count; $i++) { [void][MB]::SendMessageTimeout($main, $WM_UPDATEMAINMENUBITMAPS, [IntPtr]::Zero, [IntPtr]::Zero, 2, 5000, [ref]$r) }
	$gdi1 = Gdi
	Check "$Count updates: no GDI object more" (($gdi1 - $gdi0) -le 2) "GDI objects $gdi0 -> $gdi1"

	$after = Get-Bitmaps
	$missing = @($after.Keys | Where-Object { $after[$_] -eq [IntPtr]::Zero })
	Check 'after the updates: every colour item has its bitmap' ($missing.Count -eq 0) $(if ($missing) { 'none: ' + ($missing -join ', ') } else { "$($items.Count) items" })
	$changed = @($after.Keys | Where-Object { $after[$_] -ne $before[$_] })
	Check 'the same bitmap for the same colour (cached)' ($changed.Count -eq 0) $(if ($changed) { 'new: ' + ($changed -join ', ') } else { "$($items.Count) items" })
}
finally {
	if (-not $script:proc.HasExited) { [void][MB]::PostMessage($script:proc.MainWindowHandle, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero); if (-not $script:proc.WaitForExit(10000)) { Stop-Process -Id $script:proc.Id -Force } }
	$results
	"settings folder: $settings"
	"{0} checks, {1} failed" -f $results.Count, $fails
}
