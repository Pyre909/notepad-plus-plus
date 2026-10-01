# Testing the Pyre909 build packaging locally

The release workflow on `pyre` runs `.github/pyre/package.ps1` and `.github/pyre/installer.ps1` on a Windows
runner. Both also run on Linux, to test changes without a workflow run:

```sh
# tools: PowerShell 7 (tarball from github.com/PowerShell/PowerShell/releases), NSIS 3 and 7-Zip
apt-get install -y --no-install-recommends nsis p7zip-full
# official release files, so nothing is downloaded by the scripts
curl -LO https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/v8.9.8.1/npp.8.9.8.1.portable.x64.zip
curl -LO https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/v8.9.8.1/npp.8.9.8.1.Installer.x64.exe
# in a pyre checkout, with a MinGW build (xbuild.sh) as the exe
pwsh -File .github/pyre/package.ps1 -Exe PowerEditor/gcc/bin.gcc.x86_64/notepad++.exe -OutDir out \
     -OfficialZip npp.8.9.8.1.portable.x64.zip
PATH=<this folder>:$PATH pwsh -File .github/pyre/installer.ps1 -Exe PowerEditor/gcc/bin.gcc.x86_64/notepad++.exe \
     -OutDir out -OfficialInstaller npp.8.9.8.1.Installer.x64.exe
```

- `sign-installers.bat` here stands in for `PowerEditor/installer/sign-installers.bat`, which `nppSetup.nsi` runs
  to sign the uninstaller: Linux can't run a .bat. On Windows the real one skips signing without `SIGN=1`.
- The installer script stages files in the git-ignored `PowerEditor/bin64`, `PowerEditor/bin/updater`,
  `PowerEditor/bin/*.model.xml` and `PowerEditor/installer/build`; delete them afterwards.
- `7z x <installer>.exe` unpacks an NSIS installer, to compare its files with the official one.
- `pkgcheck.cpp` (MinGW, run under Wine with `harness/env.sh`): starts an unpacked portable build without
  `-settingsDir`, prints the Debug Info text, the About box bitness label (and checks it fits), and the Plugins
  menu. Notepad++ dialogs' text isn't captured under Wine (official builds included), so the About capture is blank.
- The installer can't run under a 64-bit-only Wine (NSIS installers are 32-bit): test it on Windows.
