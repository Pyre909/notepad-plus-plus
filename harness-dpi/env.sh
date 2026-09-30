# Common environment for the harness scripts (sourced).
# WINEPREFIX can be overridden (e.g. a copy per concurrent run); it is created on first use.
HARNESS=${HARNESS:-/tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad/harness}
export WINEPREFIX=${WINEPREFIX:-$HARNESS/wineprefix}
export WINEDEBUG=${WINEDEBUG:--all}
export WINEARCH=win64
# no Mono / Gecko install prompts
export WINEDLLOVERRIDES=${WINEDLLOVERRIDES:-mscoree,mshtml=}
WINE=${WINE:-/usr/lib/wine/wine64}
WINESERVER=${WINESERVER:-/usr/lib/wine/wineserver}
[ -x "$WINE" ] || WINE=$(command -v wine64 || command -v wine)
[ -x "$WINESERVER" ] || WINESERVER=$(command -v wineserver)
XVFB_SCREEN=${XVFB_SCREEN:-1280x1024x24}
# Python with PIL (the /usr/local python may lack it)
PY=${PY:-/usr/bin/python3}

# Ensure the prefix exists and has the harness registry settings.
# Also takes an exclusive lock on the prefix for the rest of the calling script: two runs sharing a
# prefix would share one wineserver (and the scripts kill it between runs), so runs are serialised.
harness_prefix() {
  mkdir -p "$WINEPREFIX"
  exec 9>"$WINEPREFIX.lock"
  if ! flock -n 9; then
    echo "waiting for another harness run using $WINEPREFIX ..." >&2
    flock -w 3600 9 || { echo "could not lock $WINEPREFIX" >&2; exit 75; }
  fi
  if [ ! -f "$WINEPREFIX/system.reg" ]; then
    echo "creating WINEPREFIX $WINEPREFIX" >&2
    "$WINE" wineboot -i >/dev/null 2>&1 || true
    "$WINESERVER" -w
  fi
  if [ ! -f "$WINEPREFIX/.harness_reg_v3" ]; then
    # ClearType (subpixel RGB) system font smoothing, contrast 1400 (SPI_GETFONTSMOOTHINGCONTRAST),
    # so the default Scintilla quality exercises the ClearType path of UpdateRenderingParams.
    # No crash dialog (a crash must end the process, not block it). Courier New (Notepad++'s default
    # editor font) and Consolas map to installed monospace fonts (GDI only; DirectWrite ignores them).
    # Unmanaged X11 windows: there is no window manager on Xvfb, so Wine draws captions/frames itself.
    cat > "$WINEPREFIX/harness.reg" <<'EOF'
REGEDIT4

[HKEY_CURRENT_USER\Control Panel\Desktop]
"FontSmoothing"="2"
"FontSmoothingType"=dword:00000002
"FontSmoothingGamma"=dword:00000578
"FontSmoothingOrientation"=dword:00000001

[HKEY_CURRENT_USER\Software\Wine\WineDbg]
"ShowCrashDialog"=dword:00000000

[HKEY_CURRENT_USER\Software\Wine\X11 Driver]
"Managed"="N"

[HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion\FontSubstitutes]
"Courier New"="Liberation Mono"
"Consolas"="DejaVu Sans Mono"
EOF
    "$WINE" regedit /S "$(to_win "$WINEPREFIX/harness.reg")" >/dev/null 2>&1 || true
    "$WINESERVER" -w
    touch "$WINEPREFIX/.harness_reg_v3"
  fi
}

to_win() {  # unix path -> Windows path (Z: drive)
  printf 'Z:%s' "$(printf '%s' "$1" | sed 's#/#\\#g')"
}
