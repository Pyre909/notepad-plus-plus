// fontprobe: how GDI and DirectWrite see the fonts whose names contain a text (default "MonoLisa").
// Usage: fontprobe.exe [text]   - the report is printed and written to fontprobe.txt next to the exe.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <dwrite_3.h>
#include <wrl/client.h>
#include <cstdio>
#include <cwchar>
#include <string>
#include <vector>
#include <set>
#include <algorithm>
#include <initializer_list>

using Microsoft::WRL::ComPtr;
static FILE *g_out = nullptr;
static void out(const wchar_t *fmt, ...) {
	va_list ap; va_start(ap, fmt);
	wchar_t buf[4096]; vswprintf(buf, 4096, fmt, ap); va_end(ap);
	fputws(buf, stdout);
	if (g_out) fputws(buf, g_out);
}
static std::wstring lower(std::wstring s) { for (auto &c : s) c = static_cast<wchar_t>(towlower(c)); return s; }
static std::wstring g_text;
static bool contains(const std::wstring &s) { return lower(s).find(lower(g_text)) != std::wstring::npos; }

static std::wstring allStrings(IDWriteLocalizedStrings *s) {
	std::wstring r;
	if (!s) return r;
	for (UINT32 i = 0; i < s->GetCount(); ++i) {
		UINT32 n = 0, ln = 0; s->GetStringLength(i, &n); s->GetLocaleNameLength(i, &ln);
		std::wstring v(n + 1, 0), l(ln + 1, 0);
		s->GetString(i, v.data(), n + 1); s->GetLocaleName(i, l.data(), ln + 1);
		v.resize(n); l.resize(ln);
		if (!r.empty()) r += L" | ";
		r += v + L" [" + l + L"]";
	}
	return r;
}
static std::wstring info(IDWriteFont *font, DWRITE_INFORMATIONAL_STRING_ID id) {
	ComPtr<IDWriteLocalizedStrings> s; BOOL ex = FALSE;
	if (FAILED(font->GetInformationalStrings(id, s.GetAddressOf(), &ex)) || !ex) return L"-";
	return allStrings(s.Get());
}
static std::wstring axes(IDWriteFont *font) {
	ComPtr<IDWriteFontFace> face;
	if (FAILED(font->CreateFontFace(face.GetAddressOf()))) return L"";
	ComPtr<IDWriteFontFace5> face5;
	if (FAILED(face.As(&face5))) return L" (no IDWriteFontFace5)";
	if (!face5->HasVariations()) return L" static";
	const UINT32 n = face5->GetFontAxisValueCount();
	std::vector<DWRITE_FONT_AXIS_VALUE> v(n);
	face5->GetFontAxisValues(v.data(), n);
	std::wstring r = L" VARIABLE axes:";
	for (auto &a : v) {
		const UINT32 t = a.axisTag;
		wchar_t tag[5] = { wchar_t(t & 0xFF), wchar_t((t >> 8) & 0xFF), wchar_t((t >> 16) & 0xFF), wchar_t(t >> 24), 0 };
		wchar_t b[64]; swprintf(b, 64, L" %ls=%g", tag, a.value); r += b;
	}
	return r;
}
static void describeFont(IDWriteFont *font, const wchar_t *indent) {
	ComPtr<IDWriteLocalizedStrings> faceNames; font->GetFaceNames(faceNames.GetAddressOf());
	out(L"%lsface=\"%ls\" weight=%d stretch=%d style=%d simulations=%d%ls\n", indent, allStrings(faceNames.Get()).c_str(),
		font->GetWeight(), font->GetStretch(), font->GetStyle(), font->GetSimulations(), axes(font).c_str());
	out(L"%ls  win32 family=%ls  win32 subfamily=%ls\n", indent,
		info(font, DWRITE_INFORMATIONAL_STRING_WIN32_FAMILY_NAMES).c_str(), info(font, DWRITE_INFORMATIONAL_STRING_WIN32_SUBFAMILY_NAMES).c_str());
	out(L"%ls  typographic family=%ls  subfamily=%ls  full=%ls\n", indent,
		info(font, DWRITE_INFORMATIONAL_STRING_PREFERRED_FAMILY_NAMES).c_str(), info(font, DWRITE_INFORMATIONAL_STRING_PREFERRED_SUBFAMILY_NAMES).c_str(),
		info(font, DWRITE_INFORMATIONAL_STRING_FULL_NAME).c_str());
}

struct GdiEntry { std::wstring face, full, style; LONG weight; BYTE italic; DWORD type; };
static std::vector<GdiEntry> g_gdi;
static int CALLBACK enumProc(const LOGFONTW *lf, const TEXTMETRICW *, DWORD type, LPARAM) {
	const auto *elf = reinterpret_cast<const ENUMLOGFONTEXW *>(lf);
	if (!contains(lf->lfFaceName) && !contains(elf->elfFullName)) return 1;
	GdiEntry e{ lf->lfFaceName, elf->elfFullName, elf->elfStyle, lf->lfWeight, lf->lfItalic, type };
	for (auto &x : g_gdi) if (x.face == e.face && x.full == e.full && x.style == e.style) return 1;
	g_gdi.push_back(e);
	return 1;
}

int wmain(int argc, wchar_t **argv) {
	g_text = argc > 1 ? argv[1] : L"MonoLisa";
	wchar_t path[MAX_PATH]; GetModuleFileNameW(nullptr, path, MAX_PATH);
	std::wstring outPath(path); outPath = outPath.substr(0, outPath.find_last_of(L"\\/") + 1) + L"fontprobe.txt";
	g_out = _wfopen(outPath.c_str(), L"w, ccs=UTF-8");
	OSVERSIONINFOW ov{ sizeof(ov) };
	using RtlGetVersionSig = LONG(WINAPI *)(OSVERSIONINFOW *);
	if (auto rtl = reinterpret_cast<RtlGetVersionSig>(reinterpret_cast<void *>(GetProcAddress(GetModuleHandleW(L"ntdll.dll"), "RtlGetVersion")))) rtl(&ov);
	out(L"fontprobe \"%ls\" - Windows %lu.%lu.%lu\n\n", g_text.c_str(), ov.dwMajorVersion, ov.dwMinorVersion, ov.dwBuildNumber);

	out(L"== 1. GDI (EnumFontFamiliesEx: the names in Notepad++'s font lists)\n");
	HDC hdc = GetDC(nullptr); LOGFONTW lf{}; lf.lfCharSet = DEFAULT_CHARSET;
	EnumFontFamiliesExW(hdc, &lf, enumProc, 0, 0); ReleaseDC(nullptr, hdc);
	std::set<std::wstring> gdiNames;
	for (auto &e : g_gdi) {
		out(L"  family=\"%ls\" style=\"%ls\" full=\"%ls\" weight=%ld italic=%d type=%lu\n", e.face.c_str(), e.style.c_str(), e.full.c_str(), e.weight, e.italic, e.type);
		gdiNames.insert(e.face);
	}

	ComPtr<IDWriteFactory> factory;
	DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED, __uuidof(IDWriteFactory), reinterpret_cast<IUnknown **>(factory.GetAddressOf()));
	ComPtr<IDWriteFontCollection> coll; factory->GetSystemFontCollection(coll.GetAddressOf(), FALSE);

	out(L"\n== 2. DirectWrite system font collection (the one Scintilla uses)\n");
	for (UINT32 i = 0; i < coll->GetFontFamilyCount(); ++i) {
		ComPtr<IDWriteFontFamily> fam; coll->GetFontFamily(i, fam.GetAddressOf());
		ComPtr<IDWriteLocalizedStrings> names; fam->GetFamilyNames(names.GetAddressOf());
		const std::wstring famNames = allStrings(names.Get());
		bool match = contains(famNames);
		for (UINT32 j = 0; !match && j < fam->GetFontCount(); ++j) {
			ComPtr<IDWriteFont> font; fam->GetFont(j, font.GetAddressOf());
			match = contains(info(font.Get(), DWRITE_INFORMATIONAL_STRING_WIN32_FAMILY_NAMES));
		}
		if (!match) continue;
		out(L"  FAMILY %ls (%u fonts)\n", famNames.c_str(), fam->GetFontCount());
		for (UINT32 j = 0; j < fam->GetFontCount(); ++j) {
			ComPtr<IDWriteFont> font; fam->GetFont(j, font.GetAddressOf());
			describeFont(font.Get(), L"    ");
		}
	}

	out(L"\n== 3. Each GDI family name seen by DirectWrite\n");
	ComPtr<IDWriteGdiInterop> gi; factory->GetGdiInterop(gi.GetAddressOf());
	for (auto &name : gdiNames) {
		UINT32 idx = 0; BOOL ex = FALSE; coll->FindFamilyName(name.c_str(), &idx, &ex);
		out(L"  \"%ls\": FindFamilyName %ls\n", name.c_str(), ex ? L"FOUND (used as is)" : L"not found");
		LOGFONTW l{}; wcsncpy(l.lfFaceName, name.c_str(), LF_FACESIZE - 1); l.lfWeight = FW_NORMAL; l.lfCharSet = DEFAULT_CHARSET;
		ComPtr<IDWriteFont> font;
		const HRESULT hr = gi->CreateFontFromLOGFONT(&l, font.GetAddressOf());
		if (SUCCEEDED(hr)) {
			ComPtr<IDWriteFontFamily> fam; font->GetFontFamily(fam.GetAddressOf());
			ComPtr<IDWriteLocalizedStrings> fn; fam->GetFamilyNames(fn.GetAddressOf());
			out(L"    CreateFontFromLOGFONT -> family %ls\n", allStrings(fn.Get()).c_str());
			describeFont(font.Get(), L"      ");
		} else {
			out(L"    CreateFontFromLOGFONT failed hr=%08lx\n", static_cast<unsigned long>(hr));
		}
	}

	ComPtr<IDWriteFactory6> f6;
	if (SUCCEEDED(factory.As(&f6))) {
		out(L"\n== 4. Typographic font collection (IDWriteFactory6, variable fonts by axis)\n");
		ComPtr<IDWriteFontCollection2> tc;
		if (SUCCEEDED(f6->GetSystemFontCollection(FALSE, DWRITE_FONT_FAMILY_MODEL_TYPOGRAPHIC, tc.GetAddressOf()))) {
			for (UINT32 i = 0; i < tc->GetFontFamilyCount(); ++i) {
				ComPtr<IDWriteFontFamily2> fam; tc->GetFontFamily(i, fam.GetAddressOf());
				ComPtr<IDWriteLocalizedStrings> names; fam->GetFamilyNames(names.GetAddressOf());
				if (!contains(allStrings(names.Get()))) continue;
				out(L"  FAMILY %ls (%u fonts)\n", allStrings(names.Get()).c_str(), fam->GetFontCount());
				for (UINT32 j = 0; j < fam->GetFontCount(); ++j) {
					ComPtr<IDWriteFont3> font; fam->GetFont(j, font.GetAddressOf());
					describeFont(font.Get(), L"    ");
				}
			}
		}
	} else {
		out(L"\n== 4. IDWriteFactory6 not available\n");
	}
	out(L"\nreport written to %ls\n", outPath.c_str());
	if (g_out) fclose(g_out);
	return 0;
}
