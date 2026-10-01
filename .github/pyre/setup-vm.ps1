# Sets up a Windows 10/11 machine (or VM) to work on the Pyre909 build of Notepad++ with Claude Code:
# - installs, with winget: Git for Windows, GitHub CLI, PowerShell 7, 7-Zip, NSIS and the Visual Studio 2022
#   C++ build tools (or the full Visual Studio 2022 Community IDE with -WithVisualStudioIde)
# - installs Claude Code (native installer), unless it's already there
# - clones the fork (branch pyre) and adds the official repository as remote "upstream"
# - adds a worktree per branch you're likely to work on, next to the clone
# - with -Build, builds Notepad++ x64 Release once to check the toolchain
#
# Runs in Windows PowerShell 5.1 (PowerShell 7 isn't needed to start). Download and run it with:
#   irm https://raw.githubusercontent.com/Pyre909/notepad-plus-plus/pyre/.github/pyre/setup-vm.ps1 -OutFile setup-vm.ps1
#   powershell -ExecutionPolicy Bypass -File .\setup-vm.ps1 -Build
# Installers may ask for administrator rights (UAC). Running it again is safe: what's there is kept.

param(
	[string] $Root = (Join-Path $env:USERPROFILE 'src\npp'),
	[string] $RepoUrl = 'https://github.com/Pyre909/notepad-plus-plus.git',
	[string] $UpstreamUrl = 'https://github.com/notepad-plus-plus/notepad-plus-plus.git',
	[string[]] $Worktrees = @('text-rendering_20260925', 'live-rendering-switch_20260930', 'directwrite-font-names_20260930', 'scintilla-upstream_20260930'),
	[switch] $SkipInstall,
	[switch] $SkipClaude,
	[switch] $WithVisualStudioIde,
	[switch] $Build
)

$ErrorActionPreference = 'Stop'

function Write-Step([string] $text) { Write-Host "`n== $text" -ForegroundColor Cyan }

function Update-SessionPath {
	# installers change the machine/user PATH; this session keeps its own until it's refreshed
	$machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
	$user = [Environment]::GetEnvironmentVariable('Path', 'User')
	$env:Path = "$machine;$user;$(Join-Path $env:USERPROFILE '.local\bin')"
}

# The exit code of a native command, its output discarded. Windows PowerShell 5.1 turns a native command's
# redirected stderr into errors, which $ErrorActionPreference = 'Stop' would make fatal.
function Get-ExitCode([scriptblock] $command) {
	$saved = $ErrorActionPreference
	$ErrorActionPreference = 'Continue'
	try { & $command *> $null } finally { $ErrorActionPreference = $saved }
	return $LASTEXITCODE
}

function Install-WingetPackage([string] $id, [string[]] $extra = @()) {
	if ((Get-ExitCode { winget list --id $id --exact --accept-source-agreements }) -eq 0) {
		Write-Host "${id}: already installed"
		return
	}
	Write-Host "${id}: installing"
	& winget install --id $id --exact --silent --accept-source-agreements --accept-package-agreements @extra
	$installCode = $LASTEXITCODE
	if ($installCode -ne 0) {
		# some installers report a pending restart as an error although they installed
		if ((Get-ExitCode { winget list --id $id --exact --accept-source-agreements }) -ne 0) {
			throw "winget could not install $id (exit code $installCode)"
		}
		Write-Host "${id}: installed (exit code ${installCode}, a restart may be needed)" -ForegroundColor Yellow
	}
}

function Invoke-Git {
	& git @args
	if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') failed (exit code $LASTEXITCODE)" }
}

# ---- tools
if (-not $SkipInstall) {
	Write-Step 'Tools (winget)'
	if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
		throw 'winget not found: install "App Installer" from the Microsoft Store, then run this again'
	}
	Install-WingetPackage 'Git.Git'
	Install-WingetPackage 'GitHub.cli'
	Install-WingetPackage 'Microsoft.PowerShell'
	Install-WingetPackage '7zip.7zip'
	Install-WingetPackage 'NSIS.NSIS'
	if ($WithVisualStudioIde) {
		Install-WingetPackage 'Microsoft.VisualStudio.2022.Community' @('--override', '--wait --quiet --add Microsoft.VisualStudio.Workload.NativeDesktop --includeRecommended')
	}
	else {
		Install-WingetPackage 'Microsoft.VisualStudio.2022.BuildTools' @('--override', '--wait --quiet --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended')
	}
	Update-SessionPath
}

if (-not $SkipClaude) {
	Write-Step 'Claude Code'
	if (Get-Command claude -ErrorAction SilentlyContinue) {
		Write-Host 'claude: already installed'
	}
	else {
		Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
		Update-SessionPath
	}
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
	throw 'git not found: install Git for Windows (or run without -SkipInstall), open a new terminal, run this again'
}

# ---- clone (pyre) and upstream remote
Write-Step "Repository: $Root"
if (Test-Path (Join-Path $Root '.git')) {
	Write-Host 'already cloned: fetching'
	Invoke-Git -C $Root fetch origin
}
else {
	New-Item -ItemType Directory -Force (Split-Path $Root -Parent) | Out-Null
	# Notepad++ keeps CRLF and LF files as they are: no line ending conversion, or every LF file shows as changed
	Invoke-Git clone -c core.autocrlf=false -c core.longpaths=true $RepoUrl $Root
}
Invoke-Git -C $Root config core.autocrlf false
Invoke-Git -C $Root config core.longpaths true
if (@(& git -C $Root remote) -notcontains 'upstream') { Invoke-Git -C $Root remote add upstream $UpstreamUrl }
Invoke-Git -C $Root fetch upstream master
if ((Get-ExitCode { git -C $Root rev-parse --verify --quiet refs/heads/pyre }) -ne 0) { Invoke-Git -C $Root branch --track pyre origin/pyre }
Invoke-Git -C $Root switch pyre

# ---- worktrees, next to the clone: <Root>.worktrees\<branch>
$worktreeRoot = "$Root.worktrees"
foreach ($branch in $Worktrees) {
	$path = Join-Path $worktreeRoot $branch
	if (Test-Path $path) {
		Write-Host "worktree ${branch}: already there ($path)"
		continue
	}
	if ((Get-ExitCode { git -C $Root rev-parse --verify --quiet "refs/remotes/origin/$branch" }) -ne 0) {
		Write-Host "worktree ${branch}: no such branch on origin, skipped" -ForegroundColor Yellow
		continue
	}
	if ((Get-ExitCode { git -C $Root rev-parse --verify --quiet "refs/heads/$branch" }) -eq 0) { Invoke-Git -C $Root worktree add $path $branch }
	else { Invoke-Git -C $Root worktree add --track -b $branch $path "origin/$branch" }
	Write-Host "worktree ${branch}: $path"
}

# ---- optional build check
if ($Build) {
	Write-Step 'Build check (x64 Release)'
	$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
	if (-not (Test-Path $vswhere)) { throw 'vswhere.exe not found: are the Visual Studio build tools installed?' }
	$msbuild = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild -find 'MSBuild\**\Bin\MSBuild.exe' | Select-Object -First 1
	if (-not $msbuild) { throw 'MSBuild not found by vswhere' }
	& $msbuild (Join-Path $Root 'PowerEditor\visual.net\notepadPlus.sln') /m /nologo /verbosity:minimal /p:configuration=Release /p:platform=x64
	if ($LASTEXITCODE -ne 0) { throw "the build failed (exit code $LASTEXITCODE)" }
	$exe = Join-Path $Root 'PowerEditor\bin64\Notepad++.exe'
	Write-Host "built: $exe ($((Get-Item $exe).VersionInfo.ProductVersion))"
}

# ---- what's next
Write-Step 'Done'
if ((Get-ExitCode { git config --global user.name }) -ne 0) {
	Write-Host 'Set your git identity before committing: git config --global user.name "..." and user.email' -ForegroundColor Yellow
}
if (-not (Get-Command gh -ErrorAction SilentlyContinue) -or (Get-ExitCode { gh auth status }) -ne 0) {
	Write-Host 'Sign in to GitHub (to push and watch the workflows): gh auth login' -ForegroundColor Yellow
}
Write-Host @"
Clone (pyre): $Root
Worktrees:    $worktreeRoot\<branch>
Open a NEW terminal (so the PATH changes apply), then:
  cd $Root
  claude
First prompt, for example: Read CLAUDE.md and STATUS.md (tooling branch), then help me with the Windows testing checklist.
"@
