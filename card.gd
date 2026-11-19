class_name Card
extends Control
# Карточка предмета (оружие / машина) с рисованной иконкой. Нажатие = выбор.

signal pressed

var kind: String = "weapon"
var item_id: String = ""
var title: String = ""
var sub: String = ""
var marked: bool = false
var _hover: bool = false
var _font: Font


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    _font = ThemeDB.fallback_font
    mouse_entered.connect(_on_enter)
    mouse_exited.connect(_on_exit)


func _on_enter() -> void:
    _hover = true
    queue_redraw()


func _on_exit() -> void:
    _hover = false
    queue_redraw()


func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mb: InputEventMouseButton = event
        if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
            if Rect2(Vector2.ZERO, size).has_point(mb.position):
                pressed.emit()
                accept_event()


func refresh() -> void:
    queue_redraw()


func _draw() -> void:
    var r := Rect2(Vector2.ZERO, size)
    var bg: Color = Color(0.13, 0.14, 0.18)
    var border: Color = Color(1, 1, 1, 0.14)
    if marked:
        border = Color(0.4, 0.9, 0.5, 0.9)
    if _hover:
        border = UI.ACCENT
    draw_style_box(UI.style(bg, border, 12, 2), r)
    var c: Vector2 = Vector2(size.x * 0.5, size.y * 0.38)
    if kind == "weapon":
        Icons.draw_weapon(self, item_id, c, size.x * 0.36, Color(1, 1, 1, 0.95))
    else:
        var col: Color = Color(0.9, 0.9, 0.92)
        var d: Dictionary = VehicleDefs.get_def(item_id)
        var cols: Array = d["colors"]
        col = cols[0]
        if col.get_luminance() < 0.2:
            col = Color(0.55, 0.57, 0.62)
        Icons.draw_car(self, item_id, c, size.x * 0.34, col)
    draw_string(_font, Vector2(8, size.y - 52), title, HORIZONTAL_ALIGNMENT_CENTER, size.x - 16.0, 20, Color(1, 1, 1))
    draw_string(_font, Vector2(8, size.y - 24), sub, HORIZONTAL_ALIGNMENT_CENTER, size.x - 16.0, 15, Color(0.4, 0.9, 0.5) if marked else Color(1, 1, 1, 0.55))
