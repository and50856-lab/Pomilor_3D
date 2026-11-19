class_name UI
extends RefCounted
# Мелкие помощники для интерфейса.

const ACCENT: Color = Color(0.96, 0.55, 0.1)
const BG: Color = Color(0.07, 0.08, 0.1)


static func style(bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = 10, bw: int = 0) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = border
    s.set_border_width_all(bw)
    s.set_corner_radius_all(radius)
    s.content_margin_left = 14.0
    s.content_margin_right = 14.0
    s.content_margin_top = 8.0
    s.content_margin_bottom = 8.0
    return s


static func button(text: String, min_size: Vector2 = Vector2(280, 64), font_size: int = 26) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = min_size
    b.focus_mode = Control.FOCUS_NONE
    b.add_theme_font_size_override("font_size", font_size)
    b.add_theme_stylebox_override("normal", style(Color(0.15, 0.16, 0.2), Color(1, 1, 1, 0.12), 10, 1))
    b.add_theme_stylebox_override("hover", style(Color(0.22, 0.23, 0.28), ACCENT, 10, 2))
    b.add_theme_stylebox_override("pressed", style(ACCENT, ACCENT, 10, 2))
    b.add_theme_stylebox_override("focus", style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 10, 0))
    b.add_theme_color_override("font_color", Color(1, 1, 1))
    b.add_theme_color_override("font_pressed_color", Color(0, 0, 0))
    return b


static func label(text: String, font_size: int = 22, col: Color = Color(1, 1, 1)) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", font_size)
    l.add_theme_color_override("font_color", col)
    l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    return l


static func full_rect(c: Control) -> void:
    c.set_anchors_preset(Control.PRESET_FULL_RECT)
    c.offset_left = 0.0
    c.offset_top = 0.0
    c.offset_right = 0.0
    c.offset_bottom = 0.0
