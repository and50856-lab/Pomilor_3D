class_name Loading
extends Control
# Экран загрузки: линия сначала чёрная и по мере загрузки заполняется белым.

var value: float = 0.0
var status: String = ""
var _font: Font


func _ready() -> void:
    UI.full_rect(self)
    mouse_filter = Control.MOUSE_FILTER_STOP
    _font = ThemeDB.fallback_font


func set_progress(v: float, text: String = "") -> void:
    value = clampf(v, 0.0, 1.0)
    if text != "":
        status = text
    queue_redraw()


func _draw() -> void:
    var s: Vector2 = size
    draw_rect(Rect2(Vector2.ZERO, s), Color(0.09, 0.09, 0.1))
    draw_string(_font, Vector2(0, s.y * 0.38), "POMILOR 3D", HORIZONTAL_ALIGNMENT_CENTER, s.x, 64, Color(1, 1, 1))
    var bw: float = minf(s.x * 0.6, 760.0)
    var bx: float = (s.x - bw) * 0.5
    var by: float = s.y * 0.62
    draw_rect(Rect2(bx - 2, by - 2, bw + 4, 12), Color(1, 1, 1, 0.25))
    draw_rect(Rect2(bx, by, bw, 8), Color(0, 0, 0))
    draw_rect(Rect2(bx, by, bw * value, 8), Color(1, 1, 1))
    draw_string(_font, Vector2(0, by + 44.0), "%d%%" % int(round(value * 100.0)), HORIZONTAL_ALIGNMENT_CENTER, s.x, 26, Color(1, 1, 1))
    draw_string(_font, Vector2(0, by + 78.0), status, HORIZONTAL_ALIGNMENT_CENTER, s.x, 18, Color(1, 1, 1, 0.55))
