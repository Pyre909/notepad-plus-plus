// gdiweight: the GDI font this Scintilla asks for regular (400), bold (700) and italic of font list names
#include <windows.h>
#include <cstdio>
#include <cwchar>
namespace Scintilla::Internal { void GdiLogFont(LOGFONTW &lf) noexcept; }
static void show(const wchar_t *face, LONG weight, BYTE italic) {
	LOGFONTW lf{}; wcsncpy(lf.lfFaceName, face, LF_FACESIZE - 1); lf.lfWeight = weight; lf.lfItalic = italic;
	Scintilla::Internal::GdiLogFont(lf);
	wprintf(L"  %ls%ls -> \"%ls\" %ld%ls", weight > 400 ? L"bold" : L"regular", italic ? L" italic" : L"", lf.lfFaceName, lf.lfWeight, lf.lfItalic ? L" italic" : L"");
}
int wmain(int argc, wchar_t **argv) {
	for (int i = 1; i < argc; ++i) {
		wprintf(L"%-20ls", argv[i]); show(argv[i], 400, 0); show(argv[i], 700, 0); show(argv[i], 400, 1); wprintf(L"\n");
	}
	return 0;
}
