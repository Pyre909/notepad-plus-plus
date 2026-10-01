import sys
sys.path.insert(0, '/tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad')
from edit import rep
f = 'scintilla/win32/SurfaceD2D.cxx'
rep(f, '''// The weight of the typographic family drawing a weight of a GDI family name, relative to the name's weight
// (at most extra black: heavier weights are refused by some DirectWrite implementations, drawing nothing)
DWRITE_FONT_WEIGHT RelativeWeight(const GdiFamilyMatch &match, int weight) noexcept {
	return static_cast<DWRITE_FONT_WEIGHT>(std::clamp(static_cast<int>(match.weight) + weight - static_cast<int>(FontWeight::Normal), 1,
		static_cast<int>(DWRITE_FONT_WEIGHT_EXTRA_BLACK)));
}''', '''// The weight of the typographic family drawing a weight of a GDI family name, relative to the name's weight
// (at most extra black: heavier weights are refused by some DirectWrite implementations, drawing nothing;
// the weight asked is first limited to the GDI range so the sum can't overflow)
DWRITE_FONT_WEIGHT RelativeWeight(const GdiFamilyMatch &match, int weight) noexcept {
	constexpr int maxGdiWeight = 1000;
	return static_cast<DWRITE_FONT_WEIGHT>(std::clamp(static_cast<int>(match.weight) + std::clamp(weight, 1, maxGdiWeight) -
		static_cast<int>(FontWeight::Normal), 1, static_cast<int>(DWRITE_FONT_WEIGHT_EXTRA_BLACK)));
}''')
rep(f, '''		const std::optional<GdiFamilyMatch> match = MatchGdiFamilyName(lf.lfFaceName);''', '''		const std::optional<GdiFamilyMatch> match = MatchGdiFamilyName(std::wstring(lf.lfFaceName, ::wcsnlen(lf.lfFaceName, LF_FACESIZE)));''')
rep(f, '''		const HRESULT hr = pTextFormat->GetFontFamilyName(lf.lfFaceName, LF_FACESIZE);''', '''		if (!pTextFormat) {
			return {};	// N++: the font couldn't be created (a weight or stretch refused by DirectWrite)
		}
		const HRESULT hr = pTextFormat->GetFontFamilyName(lf.lfFaceName, LF_FACESIZE);''')
f = 'scintilla/win32/SurfaceGDI.cxx'
rep(f, '''		const LONG weight = (lf.lfWeight == FW_DONTCARE) ? FW_NORMAL : lf.lfWeight;
		const bool heavierFont''', '''		const LONG weight = (lf.lfWeight == FW_DONTCARE) ? FW_NORMAL : std::clamp(lf.lfWeight, 1L, 1000L);	// the sum below can't overflow
		const bool heavierFont''')
