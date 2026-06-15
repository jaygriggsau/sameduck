class_name UI
extends RefCounted
## Small helpers for building Control-based UI in code, with a consistent look.

const PANEL_BG := Color(0.10, 0.12, 0.16, 0.85)
const ACCENT := Color("#4f9dff")

static func full_rect(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

static func label(text: String, size: int = 18, col: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

static func title(text: String) -> Label:
	var l := label(text, 48, Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

static func button(text: String, min_w: int = 220, min_h: int = 44) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, min_h)
	b.add_theme_font_size_override("font_size", 18)
	return b

static func panel(bg: Color = PANEL_BG) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", sb)
	return p

static func center_column(spacing: int = 14) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", spacing)
	return v

static func backdrop(col: Color = Color(0.06, 0.07, 0.10, 1.0)) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	full_rect(r)
	return r
