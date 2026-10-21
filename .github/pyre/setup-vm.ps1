# Sets up a Windows 10/11 machine (or VM) to work on the Pyre909 build of Notepad++ with Claude Code:
# - installs, with winget: Git for Windows, GitHub CLI, PowerShell 7, 7-Zip, NSIS, Python, LLVM (clang-format,
#   clang-tidy), WinDbg, the Sysinternals Suite (Microsoft Store) and the Visual Studio 2026 C++ build tools, ARM64
#   compiler and Clang tools included (or the full Visual Studio 2026 Community IDE with -WithVisualStudioIde)
# - installs MSYS2 with the toolchains of the CI's MSYS2 jobs (MinGW GCC, Clang), to run those builds locally
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
	[string[]] $Worktrees = @('scintilla-upstream_20260930', 'per-monitor-dpi_20260925', 'directwrite-font-names_20260930', 'rtl-views-gdi_20261006',
		'live-rendering-switch_20261005', 'directwrite-font-smoothing_20261006', 'function-list-caret_20261020', 'doclist-column-width_20261020'),
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
	# Python (Scintilla's DepGen.py, the CI's XML check), unless one is there already (py, its launcher)
	if (-not (Get-Command py -ErrorAction SilentlyContinue)) { Install-WingetPackage 'Python.Python.3.14' }
	Install-WingetPackage 'LLVM.LLVM'
	Install-WingetPackage 'Microsoft.WinDbg'
	# the Microsoft Store edition: winget's zip of the suite is replaced in place by Sysinternals, its hash goes stale
	Install-WingetPackage '9P7KNL5RWT25' @('--source', 'msstore')
	# Visual Studio 2026 (toolset v145), with the ARM64 compiler for native builds on ARM64 machines and the Clang tools
	# (clang-cl, /p:PlatformToolset=ClangCL), without keeping the downloaded packages (several GB)
	$vsComponents = @('Microsoft.VisualStudio.Component.VC.Tools.ARM64', 'Microsoft.VisualStudio.Component.VC.Llvm.Clang',
		'Microsoft.VisualStudio.Component.VC.Llvm.ClangToolset')
	$vsOptions = (($vsComponents | ForEach-Object { "--add $_" }) -join ' ') + ' --includeRecommended --nocache'
	if ($WithVisualStudioIde) {
		Install-WingetPackage 'Microsoft.VisualStudio.Community' @('--override', "--wait --quiet --add Microsoft.VisualStudio.Workload.NativeDesktop $vsOptions")
	}
	else {
		Install-WingetPackage 'Microsoft.VisualStudio.BuildTools' @('--override', "--wait --quiet --add Microsoft.VisualStudio.Workload.VCTools $vsOptions")
	}
	# an installation that was already there gets the components it lacks (winget only installs)
	$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
	if (Test-Path $vswhere) {
		$vsPath = & $vswhere -latest -products * -property installationPath
		$missing = @($vsComponents | Where-Object { -not (& $vswhere -latest -products * -requires $_ -property installationPath) })
		if ($vsPath -and $missing) {
			Write-Host "Visual Studio: adding $($missing -join ', ')"
			$vsSetup = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\setup.exe'
			$vsArgs = @('modify', '--installPath', "`"$vsPath`"") + ($missing | ForEach-Object { '--add', $_ }) + @('--quiet', '--norestart', '--nocache')
			$vsModify = Start-Process $vsSetup -ArgumentList $vsArgs -Wait -PassThru
			if ($vsModify.ExitCode -ne 0) { throw "Visual Studio could not add $($missing -join ', ') (exit code $($vsModify.ExitCode))" }
		}
	}
	# MSYS2 with the toolchains of the CI's MSYS2 jobs: MINGW64 GCC and make, CLANG64 Clang and make
	Install-WingetPackage 'MSYS2.MSYS2'
	$msysBash = 'C:\msys64\usr\bin\bash.exe'
	if ((Test-Path $msysBash) -and -not ((Test-Path 'C:\msys64\mingw64\bin\gcc.exe') -and (Test-Path 'C:\msys64\clang64\bin\clang.exe'))) {
		$env:MSYSTEM = 'MSYS'
		$env:CHERE_INVOKING = '1'
		# twice: the first run updates MSYS2's core, the second the rest
		& $msysBash -lc 'pacman -Syuu --noconfirm'
		& $msysBash -lc 'pacman -Syuu --noconfirm'
		& $msysBash -lc 'pacman -S --needed --noconfirm mingw-w64-x86_64-gcc mingw-w64-x86_64-make mingw-w64-clang-x86_64-clang mingw-w64-clang-x86_64-make'
		if ($LASTEXITCODE -ne 0) { throw "MSYS2 could not install the toolchains (exit code $LASTEXITCODE)" }
	}
	Update-SessionPath
}

if (-not $SkipClaude) {
	Write-Step 'Claude Code'
	$claudeBin = Join-Path $env:USERPROFILE '.local\bin'
	if ((Get-Command claude -ErrorAction SilentlyContinue) -or (Test-Path (Join-Path $claudeBin 'claude.exe'))) {
		Write-Host 'claude: already installed'
	}
	else {
		Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
	}
	# the installer can leave its folder off the user PATH: new terminals wouldn't find claude
	$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
	if ((Test-Path (Join-Path $claudeBin 'claude.exe')) -and (($userPath -split ';') -notcontains $claudeBin)) {
		[Environment]::SetEnvironmentVariable('Path', ((@($userPath, $claudeBin) | Where-Object { $_ }) -join ';'), 'User')
		Write-Host "claude: added $claudeBin to your PATH"
	}
	Update-SessionPath
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
