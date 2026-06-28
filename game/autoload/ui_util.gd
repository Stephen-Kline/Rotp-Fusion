class_name UIUtil
extends RefCounted

# ── Color palette ─────────────────────────────────────────────────────────────
const COL_NAVY    := Color(0.06, 0.10, 0.22)
const COL_ORANGE  := Color(0.92, 0.48, 0.12)
const COL_CREAM   := Color(0.94, 0.90, 0.80)
const COL_CYAN    := Color(0.20, 0.82, 0.90)
const COL_DIM     := Color(0.38, 0.45, 0.58)
const COL_GREEN   := Color(0.30, 0.85, 0.40)
const COL_WARN    := Color(1.00, 0.28, 0.10)
const COL_ERROR   := Color(1.00, 0.35, 0.35)
const COL_SUCCESS := Color(0.20, 0.90, 0.20)
const COL_AMBER   := Color(1.00, 0.90, 0.10)
const COL_MUTED   := Color(0.60, 0.60, 0.60)


# ── StyleBox factories ────────────────────────────────────────────────────────

static func panel_style(bg: Color, border_color: Color = Color.TRANSPARENT,
		border_px: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	if border_px > 0:
		s.border_width_left = border_px
		s.border_color = border_color
	return s


# ── Label factory ─────────────────────────────────────────────────────────────

static func make_label(text: String, size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	return lbl


# ── Container factories ───────────────────────────────────────────────────────

static func make_hbox(sep: int = 4) -> HBoxContainer:
	var c := HBoxContainer.new()
	c.add_theme_constant_override("separation", sep)
	return c


static func make_vbox(sep: int = 4) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", sep)
	return c


# ── Distance formatters ───────────────────────────────────────────────────────

static func fmt_km(km: float) -> String:
	if km >= 1_000_000.0:
		return "%.2f M km" % (km / 1_000_000.0)
	var k := int(km)
	if k >= 1000:
		return "%d,%03d km" % [k / 1000, k % 1000]
	return "%d km" % k


static func fmt_au(au: float) -> String:
	return "%.3f AU" % au if au < 10.0 else "%.1f AU" % au
