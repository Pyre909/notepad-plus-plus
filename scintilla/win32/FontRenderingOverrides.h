// Scintilla source code edit control
/** @file FontRenderingOverrides.h
 ** N++ (Pyre909 build): the DirectWrite text rendering overrides of SCI_SETFONTRENDERINGPARAMETER
 ** (ScintillaFontRendering.h), applied on top of the rendering parameters ScintillaWin makes as upstream does.
 ** Header only (no build file to change), included by SurfaceD2D.h.
 **/

#ifndef FONTRENDERINGOVERRIDES_H
#define FONTRENDERINGOVERRIDES_H

#include <algorithm>
#include <array>
#include <string_view>
#include <vector>

#include <wrl/client.h>

#include "ScintillaFontRendering.h"

namespace Scintilla::Internal {

// Text is drawn with the rendering parameters of its variant: light text gets a higher gamma, which makes it heavier (and
// dark text lighter)
constexpr int renderingVariantLight = 1;
constexpr int renderingVariants = 2;
// The text colour intensity from which text is light, as weighted by DirectWrite's grayscale gamma correction which makes
// text heavier above 0.5 and lighter below
constexpr float lightTextMinIntensity = 0.5f;

// The FontQuality bit above FontQuality::QualityMask that has DirectWrite measure text like GDI, for the GDI classic
// rendering mode, so that its fonts are realised and cached apart
constexpr int fontQualityMeasuringGdiClassic = 0x10;
static_assert((fontQualityMeasuringGdiClassic & static_cast<int>(FontQuality::QualityMask)) == 0);
// The FontQuality bit that has DirectWrite lay out text without the fonts' ligatures (SC_FONTRENDERING_LIGATURES 0)
constexpr int fontQualityNoLigatures = 0x20;
static_assert((fontQualityNoLigatures & (static_cast<int>(FontQuality::QualityMask) | fontQualityMeasuringGdiClassic)) == 0);
// The FontQuality bits of the overrides (see FontBits)
constexpr int fontQualityOverrideBits = fontQualityMeasuringGdiClassic | fontQualityNoLigatures;

// The OpenType features of a font, none if it draws its default ones: with a typography, DirectWrite leaves out the
// features it otherwise applies by default (Cascadia Code's ligatures went with "dlig" alone), so those come first, on;
// without ligatures, the standard and contextual ligatures and the contextual alternates off (coding fonts such as
// Cascadia Code and Fira Code make their ligatures with them); then those of SCI_SETFONTFEATURES's list, a later one
// replacing an earlier of the same tag
constexpr size_t maxFontFeatures = 64;
inline std::vector<DWRITE_FONT_FEATURE> FontFeatures(std::string_view list, bool noLigatures) {
	std::vector<DWRITE_FONT_FEATURE> features;
	if (!noLigatures && (list.find_first_not_of(" \t,;") == std::string_view::npos))
		return features;
	const auto set = [&features](DWRITE_FONT_FEATURE_TAG tag, UINT32 value) {
		const auto it = std::find_if(features.begin(), features.end(),
			[tag](const DWRITE_FONT_FEATURE &feature) noexcept { return feature.nameTag == tag; });
		if (it != features.end())
			it->parameter = value;
		else if (features.size() < maxFontFeatures)
			features.push_back(DWRITE_FONT_FEATURE{ tag, value });
	};
	for (const DWRITE_FONT_FEATURE_TAG tag : { DWRITE_FONT_FEATURE_TAG_STANDARD_LIGATURES,
		DWRITE_FONT_FEATURE_TAG_CONTEXTUAL_LIGATURES, DWRITE_FONT_FEATURE_TAG_CONTEXTUAL_ALTERNATES,
		DWRITE_FONT_FEATURE_TAG_KERNING }) {
		set(tag, 1);
	}
	if (noLigatures) {
		for (const DWRITE_FONT_FEATURE_TAG tag : { DWRITE_FONT_FEATURE_TAG_STANDARD_LIGATURES,
			DWRITE_FONT_FEATURE_TAG_CONTEXTUAL_LIGATURES, DWRITE_FONT_FEATURE_TAG_CONTEXTUAL_ALTERNATES }) {
			set(tag, 0);
		}
	}
	size_t start = 0;
	while (start < list.length()) {
		size_t end = list.find_first_of(" \t,;", start);
		if (end == std::string_view::npos)
			end = list.length();
		std::string_view token = list.substr(start, end - start);
		start = end + 1;
		if (token.empty())
			continue;
		UINT32 value = 1;
		if ((token.front() == '+') || (token.front() == '-')) {
			value = (token.front() == '-') ? 0 : 1;
			token.remove_prefix(1);
		}
		const size_t equals = token.find('=');
		const std::string_view tag = token.substr(0, equals);
		if (equals != std::string_view::npos) {
			const std::string_view number = token.substr(equals + 1);
			if (number.empty() || (number.length() > 5) ||
				!std::all_of(number.begin(), number.end(), [](char ch) noexcept { return (ch >= '0') && (ch <= '9'); }))
				continue;
			value = 0;
			for (const char ch : number)
				value = value * 10 + (ch - '0');
			if (value > 0xFFFF)
				continue;
		}
		if (tag.empty() || (tag.length() > 4) || !std::all_of(tag.begin(), tag.end(), [](char ch) noexcept {
			return ((ch >= 'a') && (ch <= 'z')) || ((ch >= 'A') && (ch <= 'Z')) || ((ch >= '0') && (ch <= '9')) || (ch == '_');
		}))
			continue;
		std::array<char, 4> padded{ ' ', ' ', ' ', ' ' };
		std::copy(tag.begin(), tag.end(), padded.begin());
		set(static_cast<DWRITE_FONT_FEATURE_TAG>(DWRITE_MAKE_OPENTYPE_TAG(padded[0], padded[1], padded[2], padded[3])), value);
	}
	return features;
}

static_assert((DWRITE_RENDERING_MODE_CLEARTYPE_GDI_CLASSIC == SC_RENDERINGMODE_GDICLASSIC) &&
	(DWRITE_RENDERING_MODE_CLEARTYPE_NATURAL == SC_RENDERINGMODE_NATURAL) &&
	(DWRITE_RENDERING_MODE_CLEARTYPE_NATURAL_SYMMETRIC == SC_RENDERINGMODE_NATURALSYMMETRIC));

using FontRenderingParams = Microsoft::WRL::ComPtr<IDWriteRenderingParams1>;

// The rendering parameters with the overrides: those of each variant for the default antialiasing (and grayscale) and
// for ClearType (SC_EFF_QUALITY_LCD_OPTIMIZED), and the monitor's ones for aliased text; all empty without overrides
struct FontRenderingSets {
	FontRenderingParams monitor;
	std::array<FontRenderingParams, renderingVariants> defaults;
	std::array<FontRenderingParams, renderingVariants> customs;
};

class FontRenderingOverrides {
	std::array<int, SC_FONTRENDERING_PARAMETERS> values;

	// Parameters of the monitor's with the overridden values, and the gamma and rendering mode given
	FontRenderingParams Create(IDWriteFactory1 *factory, IDWriteRenderingParams1 *monitor, FLOAT gamma, DWRITE_RENDERING_MODE mode) const noexcept {
		const auto valueOf = [this](int parameter, FLOAT divisor, FLOAT monitorValue) noexcept {
			const int value = values[parameter];
			return (value == SC_FONTRENDERING_DEFAULT) ? monitorValue : static_cast<FLOAT>(value) / divisor;
		};
		FontRenderingParams params;
		const HRESULT hr = factory->CreateCustomRenderingParams(gamma,
			valueOf(SC_FONTRENDERING_ENHANCEDCONTRAST, 100.0f, monitor->GetEnhancedContrast()),
			valueOf(SC_FONTRENDERING_GRAYSCALEENHANCEDCONTRAST, 100.0f, monitor->GetGrayscaleEnhancedContrast()),
			valueOf(SC_FONTRENDERING_CLEARTYPELEVEL, 100.0f, monitor->GetClearTypeLevel()),
			monitor->GetPixelGeometry(), mode, params.GetAddressOf());
		if (FAILED(hr)) {
			return {};
		}
		return params;
	}

public:
	FontRenderingOverrides() noexcept {
		values.fill(SC_FONTRENDERING_DEFAULT);
	}

	static constexpr bool Valid(uptr_t parameter, sptr_t value) noexcept {
		if (value == SC_FONTRENDERING_DEFAULT) {
			return parameter < SC_FONTRENDERING_PARAMETERS;
		}
		switch (parameter) {
		case SC_FONTRENDERING_ENHANCEDCONTRAST:
		case SC_FONTRENDERING_GRAYSCALEENHANCEDCONTRAST:
			return value >= 0 && value <= 1000;
		case SC_FONTRENDERING_CLEARTYPELEVEL:
			return value >= 0 && value <= 100;
		case SC_FONTRENDERING_RENDERINGMODE:
			return value == SC_RENDERINGMODE_GDICLASSIC || value == SC_RENDERINGMODE_NATURAL ||
				value == SC_RENDERINGMODE_NATURALSYMMETRIC;
		case SC_FONTRENDERING_LIGHTTEXTGAMMA:
			// like SPI_GETFONTSMOOTHINGCONTRAST
			return value >= 1000 && value <= 2200;
		case SC_FONTRENDERING_LIGATURES:
			return value == 0;
		default:
			return false;
		}
	}

	// Whether the value is set: valid and other than the one set
	bool Set(uptr_t parameter, sptr_t value) noexcept {
		if (!Valid(parameter, value) || (values[parameter] == value)) {
			return false;
		}
		values[parameter] = static_cast<int>(value);
		return true;
	}

	[[nodiscard]] int Get(uptr_t parameter) const noexcept {
		return (parameter < values.size()) ? values[parameter] : SC_FONTRENDERING_DEFAULT;
	}

	// Whether a rendering parameter is overridden (the font features are not rendering parameters)
	static_assert(SC_FONTRENDERING_LIGATURES == SC_FONTRENDERING_PARAMETERS - 1, "the rendering parameters come first");
	[[nodiscard]] bool Any() const noexcept {
		return std::any_of(values.cbegin(), values.cbegin() + SC_FONTRENDERING_LIGATURES, [](int value) noexcept { return value != SC_FONTRENDERING_DEFAULT; });
	}

	// The FontQuality bits of the measuring: like GDI for the GDI classic mode, so that the glyphs are on whole pixels when
	// measured and drawn. GDI-compatible layouts use 1 pixel per DIP, so not while GDI scaling draws at a larger scale.
	[[nodiscard]] int MeasuringBits(float deviceScaleFactor) const noexcept {
		return ((values[SC_FONTRENDERING_RENDERINGMODE] == SC_RENDERINGMODE_GDICLASSIC) && (deviceScaleFactor == 1.0f)) ?
			fontQualityMeasuringGdiClassic : 0;
	}

	// The FontQuality bits of the overrides, which have the fonts realised and cached apart: the measuring and the features
	[[nodiscard]] int FontBits(float deviceScaleFactor) const noexcept {
		return MeasuringBits(deviceScaleFactor) | ((values[SC_FONTRENDERING_LIGATURES] == 0) ? fontQualityNoLigatures : 0);
	}

	// Replaces the default and custom (ClearType) parameters made as upstream does, from the monitor's ones and the gamma of
	// the ClearType Tuner, with overridden ones, and makes those of the variants; without overrides, they're kept
	void Apply(IDWriteFactory1 *factory, FontRenderingParams &defaultParams, FontRenderingParams &customParams,
		FontRenderingSets &sets, float deviceScaleFactor) const noexcept {
		sets = {};
		if (!Any() || !factory || !defaultParams) {
			return;
		}
		sets.monitor = defaultParams;
		IDWriteRenderingParams1 *monitor = sets.monitor.Get();
		const FLOAT monitorGamma = monitor->GetGamma();

		const int modeOverride = values[SC_FONTRENDERING_RENDERINGMODE];
		DWRITE_RENDERING_MODE mode = monitor->GetRenderingMode();
		if ((modeOverride == SC_RENDERINGMODE_NATURAL) || (modeOverride == SC_RENDERINGMODE_NATURALSYMMETRIC) ||
			((modeOverride == SC_RENDERINGMODE_GDICLASSIC) && (MeasuringBits(deviceScaleFactor) != 0))) {
			mode = static_cast<DWRITE_RENDERING_MODE>(modeOverride);
		}
		// light text: at least the monitor's gamma and the one asked, as a higher gamma makes it heavier
		const int lightTextGamma = values[SC_FONTRENDERING_LIGHTTEXTGAMMA];
		const FLOAT lightTextMinGamma = std::max(monitorGamma, static_cast<FLOAT>(lightTextGamma) / 1000.0f);

		for (const bool isCustom : { false, true }) {
			// without the ClearType Tuner's gamma (no custom parameters), ClearType uses the default ones, as upstream
			FontRenderingParams &base = isCustom ? customParams : defaultParams;
			if (!base) {
				continue;
			}
			const FLOAT baseGamma = base->GetGamma();
			std::array<FontRenderingParams, renderingVariants> &variants = isCustom ? sets.customs : sets.defaults;
			for (int variant = 0; variant < renderingVariants; variant++) {
				const bool isLight = (variant & renderingVariantLight) && (lightTextGamma != SC_FONTRENDERING_DEFAULT);
				if (variant && !isLight) {
					variants[variant] = variants[0]; // a variant that doesn't apply has the parameters of the one made before
					continue;
				}
				variants[variant] = Create(factory, monitor, isLight ? std::max(baseGamma, lightTextMinGamma) : baseGamma, mode);
				if (!variants[variant]) {
					variants[variant] = variant ? variants[0] : base; // couldn't be made: as without the variant, or the override
				}
			}
			base = variants[0];
		}
	}
};

}

#endif
