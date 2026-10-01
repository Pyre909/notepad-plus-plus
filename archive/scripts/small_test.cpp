// Standalone check (not project code): same header order as scintilla/win32/ScintillaWin.cxx
#define NOMINMAX
#define _WIN32_WINNT 0x0A00
#define WINVER 0x0A00
#define WIN32_LEAN_AND_MEAN 1
#include <windows.h>
#include <ole2.h>
#include <d2d1_1.h>
#include <dwrite_1.h>
int f(int variant) {
	const bool small = variant & 2;
	return small ? 1 : 0;
}
