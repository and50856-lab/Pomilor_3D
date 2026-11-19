extends Node
# Ввод: сюда пишут сенсорные кнопки (HUD) и клавиатура. Читают игрок и машина.

signal action(name: String)

var t_move: Vector2 = Vector2.ZERO
var t_run: bool = false
var t_fire: bool = false
var t_left: bool = false
var t_right: bool = false
var t_gas: bool = false
var t_rev: bool = false
var t_hand: bool = false

var move: Vector2 = Vector2.ZERO
var run: bool = false
var fire: bool = false
var steer: float = 0.0
var gas: float = 0.0
var rev: float = 0.0
var handbrake: bool = false
var look: Vector2 = Vector2.ZERO

var _rmb: bool = false


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS


func take_look() -> Vector2:
    var v: Vector2 = look
    look = Vector2.ZERO
    return v


func _process(_delta: float) -> void:
    var kb: Vector2 = Vector2.ZERO
    if Input.is_physical_key_pressed(KEY_W):
        kb.y -= 1.0
    if Input.is_physical_key_pressed(KEY_S):
        kb.y += 1.0
    if Input.is_physical_key_pressed(KEY_A):
        kb.x -= 1.0
    if Input.is_physical_key_pressed(KEY_D):
        kb.x += 1.0
    move = t_move if t_move.length() > 0.05 else kb
    run = t_run or Input.is_physical_key_pressed(KEY_SHIFT)
    var pc_fire: bool = false
    if not DisplayServer.is_touchscreen_available():
        pc_fire = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
    fire = t_fire or pc_fire
    var s: float = 0.0
    if t_left or Input.is_physical_key_pressed(KEY_A):
        s -= 1.0
    if t_right or Input.is_physical_key_pressed(KEY_D):
        s += 1.0
    steer = s
    gas = 1.0 if (t_gas or Input.is_physical_key_pressed(KEY_W)) else 0.0
    rev = 1.0 if (t_rev or Input.is_physical_key_pressed(KEY_S)) else 0.0
    handbrake = t_hand or Input.is_physical_key_pressed(KEY_SPACE)


func _unhandled_input(event: InputEvent) -> void:
    if DisplayServer.is_touchscreen_available():
        return
    if event is InputEventMouseButton:
        var mb: InputEventMouseButton = event
        if mb.button_index == MOUSE_BUTTON_RIGHT:
            _rmb = mb.pressed
    elif event is InputEventMouseMotion:
        var mm: InputEventMouseMotion = event
        if _rmb:
            look += mm.relative
    elif event is InputEventKey:
        var k: InputEventKey = event
        if k.pressed and not k.echo:
            match k.physical_keycode:
                KEY_E:
                    action.emit("interact")
                KEY_R:
                    action.emit("reload")
                KEY_V:
                    action.emit("cam")
                KEY_SPACE:
                    action.emit("jump")
                KEY_G:
                    action.emit("drop")
                KEY_H:
                    action.emit("horn")
                KEY_TAB:
                    action.emit("items")
                KEY_ESCAPE:
                    action.emit("pause")
