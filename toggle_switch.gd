class_name ToggleSwitch
extends Control
# Ползунок-переключатель: серый и слева — выключено, цветной и справа — включено.

signal toggled(on: bool)

var on: bool = false


func _ready() -> void:
    custom_minimum_size = Vector2(76, 40)
    mouse_filter = Control.MOUSE_FILTER_STOP


func set_on(v: bool) -> void:
    on = v
    queue_redraw()


func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mb: InputEventMouseButton = event
        if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
            if Rect2(Vector2.ZERO, size).has_point(mb.position):
                on = not on
                toggled.emit(on)
                queue_redraw()
                accept_event()


func _draw() -> void:
    var bg: Color = UI.ACCENT if on else Color(0.3, 0.3, 0.34)
    draw_style_box(UI.style(bg, Color(1, 1, 1, 0.2), 20, 1), Rect2(Vector2.ZERO, size))
    var kx: float = size.x - 22.0 if on else 22.0
    draw_circle(Vector2(kx, size.y * 0.5), 14.0, Color(1, 1, 1, 0.95) if on else Color(0.75, 0.75, 0.78))
