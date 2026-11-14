class_name VisualTheme
extends RefCounted

const GOLD := Color(0.94, 0.72, 0.30)
const CREAM := Color(0.94, 0.92, 0.80)
const INK := Color(0.035, 0.075, 0.08)
const TEAL := Color(0.07, 0.20, 0.21)

static func panel_style(alpha: float = 0.94, radius: int = 14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.09, 0.095, alpha)
	style.border_color = Color(0.45, 0.63, 0.49, 0.72)
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	style.shadow_size = 12
	style.content_margin_left = 24.0
	style.content_margin_right = 24.0
	style.content_margin_top = 20.0
	style.content_margin_bottom = 20.0
	return style

static func button_style(color: Color, hover := false, pressed := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color.lightened(0.12) if hover else color.darkened(0.10) if pressed else color
	style.border_color = GOLD if hover else color.lightened(0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0
	return style

static func decorate_button(button: Button, accent := false) -> void:
	var base := Color(0.55, 0.31, 0.12) if accent else Color(0.10, 0.27, 0.25)
	button.add_theme_stylebox_override("normal", button_style(base))
	button.add_theme_stylebox_override("hover", button_style(base, true))
	button.add_theme_stylebox_override("pressed", button_style(base, false, true))
	button.add_theme_stylebox_override("focus", button_style(base, true))
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 17)
