// mapprobe: prints getScintillaFont for font list names (both technologies, regular and bold)
#include <windows.h>
#include <cstdio>
#include "FontFamilyNames.h"
int wmain(int argc, wchar_t **argv) {
	for (int i = 1; i < argc; ++i)
		for (int tech : { SC_TECHNOLOGY_DEFAULT, SC_TECHNOLOGY_DIRECTWRITE })
			for (bool bold : { false, true }) {
				const ScintillaFont f = getScintillaFont(argv[i], bold, false, tech);
				wprintf(L"%-28ls %-3ls %-7ls -> \"%ls\" weight %d stretch %d italic %d\n", argv[i], tech ? L"DW" : L"GDI", bold ? L"bold" : L"regular",
					f._name.c_str(), f._weight, f._stretch, f._isItalic);
			}
	return 0;
}
