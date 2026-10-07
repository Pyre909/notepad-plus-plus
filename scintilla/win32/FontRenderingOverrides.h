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

	[[nodiscard]] bool Any() const noexcept {
		return std::any_of(values.cbegin(), values.cend(), [](int value) noexcept { return value != SC_FONTRENDERING_DEFAULT; });
	}

	// The FontQuality bits of the measuring: like GDI for the GDI classic mode, so that the glyphs are on whole pixels when
	// measured and drawn. GDI-compatible layouts use 1 pixel per DIP, so not while GDI scaling draws at a larger scale.
	[[nodiscard]] int MeasuringBits(float deviceScaleFactor) const noexcept {
		return ((values[SC_FONTRENDERING_RENDERINGMODE] == SC_RENDERINGMODE_GDICLASSIC) && (deviceScaleFactor == 1.0f)) ?
			fontQualityMeasuringGdiClassic : 0;
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
