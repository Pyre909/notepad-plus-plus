#include <windows.h>
#include <dwrite.h>
#include <cstdio>
#include <initializer_list>
#include <cwchar>
int main() {
	IDWriteFactory *f = nullptr;
	DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED, __uuidof(IDWriteFactory), reinterpret_cast<IUnknown **>(&f));
	IDWriteGdiInterop *gi = nullptr; f->GetGdiInterop(&gi);
	for (const wchar_t *name : { L"Fira Code", L"Fira Code Light", L"Fira Code Medium" }) {
		LOGFONTW lf{}; wcscpy(lf.lfFaceName, name); lf.lfWeight = FW_NORMAL; lf.lfCharSet = DEFAULT_CHARSET;
		IDWriteFont *font = nullptr;
		HRESULT hr = gi->CreateFontFromLOGFONT(&lf, &font);
		wprintf(L"CreateFontFromLOGFONT(%ls) hr=%08lx", name, hr);
		if (SUCCEEDED(hr)) wprintf(L" weight=%d", font->GetWeight());
		wprintf(L"\n");
	}
	// WIN32 family names via informational strings
	IDWriteFontCollection *c = nullptr; f->GetSystemFontCollection(&c);
	UINT32 idx; BOOL ex; c->FindFamilyName(L"Fira Code", &idx, &ex);
	IDWriteFontFamily *fam = nullptr; c->GetFontFamily(idx, &fam);
	for (UINT32 i = 0; i < fam->GetFontCount(); ++i) {
		IDWriteFont *font = nullptr; fam->GetFont(i, &font);
		IDWriteLocalizedStrings *s = nullptr; BOOL has = FALSE;
		HRESULT hr = font->GetInformationalStrings(DWRITE_INFORMATIONAL_STRING_WIN32_FAMILY_NAMES, &s, &has);
		wchar_t buf[128] = L"?";
		if (SUCCEEDED(hr) && has && s) s->GetString(0, buf, 128);
		wprintf(L"font %u weight=%d win32family=%ls (hr=%08lx has=%d)\n", i, font->GetWeight(), buf, hr, has);
	}
	return 0;
}
