# Prints a document of a Notepad++ build to Microsoft Print to PDF through the Windows 11 print dialog, in steps, and lists
# the fonts of the PDF. Windows PowerShell 5.1 (UI Automation): powershell -File print-pdf.ps1 -Step <step> [...]
#   open    : a settings folder with the Default Style in -Font, a C++ file, Notepad++ (-Exe) and File > Print
#   inspect : the print dialog's printer list
#   select  : "Microsoft Print to PDF" selected in it, and read back
#   print   : only if the selection reads back "Microsoft Print to PDF": Print, the file name (-Pdf), Save; the PDF's fonts
#   cancel  : the dialog closed without printing
#   close   : Notepad++ closed
# Safety: the machine's default printer is a real printer. Never Print Now (IDM_FILE_PRINTNOW); Print only after the
# selection is checked. Windows manages the VM's default printer: printing to PDF makes the PDF printer the default
# (ask Pyre909 first; they set the real printer back). The open step's settings are in %TEMP%\npp-review.
param([Parameter(Mandatory)] [ValidateSet('open', 'inspect', 'select', 'print', 'cancel', 'close')] [string] $Step,
	[string] $Exe, [string] $Font = 'Segoe UI Light', [string] $Pdf)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
Add-Type -Namespace PP -Name W -MemberDefinition @'
public delegate bool EnumProc(IntPtr h, IntPtr l);
[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string cls, string title);
[DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EnumProc f, IntPtr l);
[DllImport("user32.dll")] public static extern int GetDlgCtrlID(IntPtr h);
[DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h, int id);
[DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, System.Text.StringBuilder s, int n);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, string l);
'@
function Get-ClassName([IntPtr] $h) { $sb = New-Object Text.StringBuilder 64; [void][PP.W]::GetClassName($h, $sb, 64); $sb.ToString() }
$AE = [Windows.Automation.AutomationElement]; $TS = [Windows.Automation.TreeScope]; $CT = [Windows.Automation.ControlType]
$stateFile = Join-Path ([IO.Path]::GetTempPath()) 'npp-review\print-pdf.state' # the Notepad++ of the steps
$pdfName = 'Microsoft Print to PDF'

function Find-ById($parent, [string] $id) {
	$parent.FindFirst($TS::Descendants, (New-Object Windows.Automation.PropertyCondition($AE::AutomationIdProperty, $id)))
}
# the print dialog: the top-level window holding the printer list (printerSelector)
function Find-PrintDialog([int] $seconds = 20) {
	for ($i = 0; $i -lt $seconds * 2; $i++) {
		foreach ($top in $AE::RootElement.FindAll($TS::Children, [Windows.Automation.Condition]::TrueCondition)) {
			if ($top.Current.Name -notmatch 'Print') { continue }
			$combo = Find-ById $top 'printerSelector'
			if ($combo) { return @{ Window = $top; Combo = $combo } }
		}
		Start-Sleep -Milliseconds 500
	}
	return $null
}
function Get-Selection($combo) {
	$pattern = $null
	if ($combo.TryGetCurrentPattern([Windows.Automation.SelectionPattern]::Pattern, [ref]$pattern)) {
		return @($pattern.Current.GetSelection() | ForEach-Object { $_.Current.Name })
	}
	return @()
}
function Invoke-ById($window, [string] $id) {
	$button = Find-ById $window $id
	if (-not $button) { throw "no $id" }
	$button.GetCurrentPattern([Windows.Automation.InvokePattern]::Pattern).Invoke()
}

switch ($Step) {
	'open' {
		$settings = Join-Path ([IO.Path]::GetTempPath()) ('npp-review\print-pdf-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
		New-Item -ItemType Directory -Force $settings | Out-Null
		$model = Join-Path (Split-Path $Exe) 'stylers.model.xml'
		$bytes = [IO.File]::ReadAllBytes($model); $hasBom = ($bytes.Length -ge 3) -and ($bytes[0] -eq 0xEF)
		$stylers = [IO.File]::ReadAllText($model) -replace '(<WidgetStyle name="Default Style" styleID="32"[^>]*?)fontName="[^"]*"', ('$1fontName="' + $Font + '"')
		[IO.File]::WriteAllText((Join-Path $settings 'stylers.xml'), $stylers, (New-Object Text.UTF8Encoding($hasBom)))
		$file = Join-Path $settings 'print-test.cpp'
		[IO.File]::WriteAllLines($file, [string[]]@("// Printed in $Font with DirectWrite on screen", 'int main()', '{', '	return 0; // int and return are bold keywords', '}'))
		$proc = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$settings", '-titleAdd=PRINT-TEST', $file -PassThru
		for ($i = 0; $i -lt 100; $i++) { $proc.Refresh(); if ($proc.MainWindowHandle -ne 0) { break }; Start-Sleep -Milliseconds 100 }
		Start-Sleep -Milliseconds 1200
		"$($proc.Id)`t$($proc.MainWindowHandle.ToInt64())`t$settings" | Set-Content -LiteralPath $stateFile
		[void][PP.W]::PostMessage($proc.MainWindowHandle, 0x0111, [IntPtr]41010, [IntPtr]::Zero) # IDM_FILE_PRINT: the Print dialog
		$dialog = Find-PrintDialog
		if (-not $dialog) { throw 'no print dialog' }
		$owner = Get-Process -Id $dialog.Window.Current.ProcessId -ErrorAction SilentlyContinue
		"Notepad++ $($proc.Id), print dialog '$($dialog.Window.Current.Name)' in process $($owner.ProcessName) ($($dialog.Window.Current.ProcessId))"
		"selected printer: $((Get-Selection $dialog.Combo) -join ', ')"
	}
	'inspect' {
		$dialog = Find-PrintDialog 5
		if (-not $dialog) { throw 'no print dialog' }
		$combo = $dialog.Combo
		"combo: '$($combo.Current.Name)', selection: $((Get-Selection $combo) -join ', ')"
		$combo.GetCurrentPattern([Windows.Automation.ExpandCollapsePattern]::Pattern).Expand()
		Start-Sleep -Milliseconds 1200
		foreach ($item in $combo.FindAll($TS::Descendants, (New-Object Windows.Automation.PropertyCondition($AE::ControlTypeProperty, $CT::ListItem)))) {
			"  item: '$($item.Current.Name)' id '$($item.Current.AutomationId)'"
		}
		$combo.GetCurrentPattern([Windows.Automation.ExpandCollapsePattern]::Pattern).Collapse()
	}
	'select' {
		$dialog = Find-PrintDialog 5
		if (-not $dialog) { throw 'no print dialog' }
		$combo = $dialog.Combo
		$combo.GetCurrentPattern([Windows.Automation.ExpandCollapsePattern]::Pattern).Expand()
		Start-Sleep -Milliseconds 1200
		$item = $combo.FindFirst($TS::Descendants, (New-Object Windows.Automation.AndCondition(
			(New-Object Windows.Automation.PropertyCondition($AE::ControlTypeProperty, $CT::ListItem)),
			(New-Object Windows.Automation.PropertyCondition($AE::NameProperty, $pdfName)))))
		if (-not $item) { $combo.GetCurrentPattern([Windows.Automation.ExpandCollapsePattern]::Pattern).Collapse(); throw "$pdfName not in the list" }
		$item.GetCurrentPattern([Windows.Automation.SelectionItemPattern]::Pattern).Select()
		Start-Sleep -Milliseconds 800
		try { $combo.GetCurrentPattern([Windows.Automation.ExpandCollapsePattern]::Pattern).Collapse() } catch { }
		Start-Sleep -Milliseconds 2500 # the dialog loads the printer's settings and preview
		"selected printer: $((Get-Selection $combo) -join ', ')"
	}
	'print' {
		$dialog = Find-PrintDialog 5
		if (-not $dialog) { throw 'no print dialog' }
		$selected = @(Get-Selection $dialog.Combo) # @(): a single name stays an array
		if (($selected.Count -ne 1) -or ($selected[0] -ne $pdfName)) { throw "selected printer '$($selected -join ', ')': not printing" }
		if (Test-Path -LiteralPath $Pdf) { Remove-Item -LiteralPath $Pdf }
		"printing to $($selected[0])"
		Invoke-ById $dialog.Window 'PrintButton'
		# the PDF printer's Save dialog is a Win32 dialog of Notepad++'s process, whose file name box UI Automation
		# doesn't expose: the Edit 1001 of its first combo box, set with WM_SETTEXT, then the Save button (1)
		$state = (Get-Content -LiteralPath $stateFile) -split "`t"
		$save = [IntPtr]::Zero
		for ($i = 0; ($i -lt 120) -and ($save -eq [IntPtr]::Zero); $i++) { Start-Sleep -Milliseconds 500; $save = [PP.W]::FindWindowEx([IntPtr]::Zero, [IntPtr]::Zero, '#32770', 'Save Print Output As') }
		if ($save -eq [IntPtr]::Zero) { throw 'no Save Print Output As dialog' }
		$owner = 0; [void][PP.W]::GetWindowThreadProcessId($save, [ref]$owner)
		if ($owner -ne [int]$state[0]) { throw "the Save dialog belongs to process $owner, not Notepad++ $($state[0])" }
		Start-Sleep -Milliseconds 1000
		$script:children = [Collections.Generic.List[IntPtr]]::new()
		[void][PP.W]::EnumChildWindows($save, { param($h, $l) $script:children.Add($h); $true }, [IntPtr]::Zero)
		$nameEdit = $script:children | Where-Object { ((Get-ClassName $_) -eq 'Edit') -and ([PP.W]::GetDlgCtrlID($_) -eq 1001) -and ((Get-ClassName ([PP.W]::GetParent($_))) -eq 'ComboBox') } | Select-Object -First 1
		if (-not $nameEdit) { throw 'no file name box' }
		[void][PP.W]::SendMessage($nameEdit, 0x000C, [IntPtr]::Zero, $Pdf) # WM_SETTEXT
		[void][PP.W]::PostMessage([PP.W]::GetDlgItem($save, 1), 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) # BM_CLICK on Save
		$size = -1
		for ($i = 0; $i -lt 120; $i++) {
			Start-Sleep -Milliseconds 500
			if (Test-Path -LiteralPath $Pdf) { $now = (Get-Item -LiteralPath $Pdf).Length; if (($now -gt 0) -and ($now -eq $size)) { break }; $size = $now }
		}
		if (-not (Test-Path -LiteralPath $Pdf)) { throw 'no PDF written' }
		"PDF: $Pdf ($((Get-Item -LiteralPath $Pdf).Length) bytes)"
		& (Join-Path $PSScriptRoot 'pdf-fonts.ps1') -Pdf $Pdf
	}
	'cancel' {
		$dialog = Find-PrintDialog 5
		if ($dialog) { Invoke-ById $dialog.Window 'CloseButton'; 'print dialog closed' } else { 'no print dialog' }
	}
	'close' {
		$state = (Get-Content -LiteralPath $stateFile) -split "`t"
		$proc = Get-Process -Id ([int]$state[0]) -ErrorAction SilentlyContinue
		if ($proc) { [void][PP.W]::PostMessage([IntPtr][long]$state[1], 0x0010, [IntPtr]::Zero, [IntPtr]::Zero); if (-not $proc.WaitForExit(10000)) { Stop-Process -Id $proc.Id -Force }; 'Notepad++ closed' }
	}
}
