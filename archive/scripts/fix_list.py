import sys
sys.path.insert(0, '/tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad')
from edit import rep
f = 'scintilla/win32/ScintillaWin.cxx'
rep(f, '''	bool UpdateRenderingParams(bool force) noexcept;
''', '''	bool UpdateRenderingParams(bool force) noexcept;
	void SetListRenderingParams() noexcept;	// N++
''')
rep(f, '''	// N++: the autocompletion list draws its text with the same parameters
	if (ISetRenderingParams *setListParams = dynamic_cast<ISetRenderingParams *>(ac.lb.get())) {
		setListParams->SetRenderingParams(renderingParams);
	}
	return true;
}
''', '''	SetListRenderingParams();	// N++
	return true;
}

// N++: the autocompletion list draws its text with the editor's parameters once the text rendering is
// customised (font quality or overrides), else as upstream (without parameters, grayscale antialiasing)
void ScintillaWin::SetListRenderingParams() noexcept {
	ISetRenderingParams *setListParams = dynamic_cast<ISetRenderingParams *>(ac.lb.get());
	if (!setListParams) {
		return;
	}
	const bool defaultQuality = (static_cast<int>(vs.extraFontFlag) & static_cast<int>(FontQuality::QualityMask)) ==
		static_cast<int>(FontQuality::QualityDefault);
	setListParams->SetRenderingParams((defaultQuality && !FontRenderingOverridden()) ? nullptr : renderingParams);
}
''')
rep(f, '''	// N++: DirectWrite text rendering overrides
	case Message::SetFontRenderingParameter:
		SetFontRenderingParameter(wParam, lParam);
		break;
''', '''	// N++: the autocompletion list follows the font quality (see SetListRenderingParams)
	case Message::SetFontQuality:
		ScintillaBase::WndProc(iMessage, wParam, lParam);
#if defined(USE_D2D)
		SetListRenderingParams();
#endif
		break;

	// N++: DirectWrite text rendering overrides
	case Message::SetFontRenderingParameter:
		SetFontRenderingParameter(wParam, lParam);
		break;
''')
rep(f, '''		case Message::SetTechnology:
		case Message::SetFontRenderingParameter:	// N++
''', '''		case Message::SetTechnology:
		case Message::SetFontQuality:	// N++
		case Message::SetFontRenderingParameter:	// N++
''')
f = 'scintilla/win32/ListBox.cxx'
rep(f, '''// N++: the editor's rendering parameters, applied when the line surface is next allocated
void ListBoxX::SetRenderingParams''', '''// N++: the editor's rendering parameters (none: drawn as upstream), applied when the line surface is next allocated
void ListBoxX::SetRenderingParams''')
rep(f, '''		// N++: opaque (alpha ignored) so text can be ClearType. Draw fills every pixel that is
		// copied to the list before drawing text and the bitmap is only copied with SRCCOPY.
		const D2D1_RENDER_TARGET_PROPERTIES drtp = D2D1::RenderTargetProperties(
			D2D1_RENDER_TARGET_TYPE_DEFAULT,
			{ DXGI_FORMAT_B8G8R8A8_UNORM, D2D1_ALPHA_MODE_IGNORE },
			dpiTarget, dpiTarget);
''', '''		// N++: opaque (alpha ignored) with the editor's rendering parameters so text can be ClearType.
		// Draw fills every pixel that is copied to the list before drawing text and the bitmap is only copied with SRCCOPY.
		const D2D1_RENDER_TARGET_PROPERTIES drtp = D2D1::RenderTargetProperties(
			D2D1_RENDER_TARGET_TYPE_DEFAULT,
			{ DXGI_FORMAT_B8G8R8A8_UNORM, renderingParams ? D2D1_ALPHA_MODE_IGNORE : D2D1_ALPHA_MODE_PREMULTIPLIED },
			dpiTarget, dpiTarget);
''')
