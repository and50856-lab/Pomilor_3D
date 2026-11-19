class_name Hud
extends Control
# Сенсорный интерфейс: адаптивный джойстик слева, кнопки справа, круговое меню оружия.
# Всё рисуется и обрабатывается вручную (мультитач: можно двигаться и жать кнопки одновременно).

signal open_items
signal open_pause

const JOY_R: float = 80.0

var run_on: bool = false
var wheel_open: bool = false

var _font: Font
var _btns: Array = []
var _touch_btn: Dictionary = {}
var _joy_idx: int = -1
var _joy_c: Vector2 = Vector2.ZERO
var _joy_p: Vector2 = Vector2.ZERO
var _look_idx: int = -1
var _wheel_hover: int = -1
var _toasts: Array = []
var _flash_t: float = 0.0
var _car_mode: bool = false
var _last_size: Vector2 = Vector2.ZERO


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_preset(Control.PRESET_FULL_RECT)
    _font = ThemeDB.fallback_font
    Game.toast.connect(_on_toast)


func _exit_tree() -> void:
    if wheel_open:
        Game.set_slowmo(false)
    _release_all()


func flash() -> void:
    _flash_t = 1.0


func _on_toast(text: String) -> void:
    _toasts.append({"t": text, "age": 0.0})
    if _toasts.size() > 3:
        _toasts.pop_front()


# ---------- раскладка ----------

func _add(id: String, c: Vector2, r: float, label: String) -> void:
    _btns.append({"id": id, "c": c, "r": r, "label": label})


func _build_layout() -> void:
    _btns.clear()
    var w: float = size.x
    var h: float = size.y
    _add("fire", Vector2(w - 215.0, h - 190.0), 64.0, "ОГОНЬ")
    _add("jump", Vector2(w - 95.0, h - 120.0), 50.0, "ПРЫЖОК")
    _add("run", Vector2(w - 215.0, h - 70.0), 38.0, "БЕГ")
    _add("reload", Vector2(w - 335.0, h - 115.0), 34.0, "ПЕРЕЗ.")
    _add("drop", Vector2(w - 95.0, h - 250.0), 32.0, "БРОСИТЬ")
    _add("interact", Vector2(w - 340.0, h - 235.0), 46.0, "ДА")
    _add("cam", Vector2(w - 50.0, 52.0), 28.0, "ВИД")
    _add("pause", Vector2(w - 112.0, 52.0), 28.0, "")
    _add("items", Vector2(w - 174.0, 52.0), 28.0, "ВЕЩИ")
    _add("wheel", Vector2(w - 248.0, 52.0), 34.0, "")
    _add("left", Vector2(110.0, h - 95.0), 64.0, "")
    _add("right", Vector2(280.0, h - 95.0), 64.0, "")
    _add("gas", Vector2(w - 105.0, h - 135.0), 76.0, "ГАЗ")
    _add("rev", Vector2(w - 250.0, h - 80.0), 52.0, "НАЗАД")
    _add("hand", Vector2(w - 105.0, h - 290.0), 36.0, "СТОП")
    _add("horn", Vector2(w - 250.0, h - 215.0), 34.0, "СИГНАЛ")
    _last_size = size


func _active(id: String) -> bool:
    if _car_mode:
        return id in ["left", "right", "gas", "rev", "hand", "horn", "interact", "cam", "pause"]
    match id:
        "reload":
            if Game.equipped == "":
                return false
            var k: String = str(WeaponDefs.get_def(Game.equipped).get("kind", ""))
            return k == "gun" or k == "rocket"
        "drop":
            return Game.equipped != ""
        "interact":
            return Game.prompt != ""
        "fire", "jump", "run", "cam", "pause", "items", "wheel":
            return true
    return false


func _button_at(p: Vector2) -> String:
    for b in _btns:
        var id: String = b["id"]
        if not _active(id):
            continue
        var c: Vector2 = b["c"]
        if p.distance_to(c) <= float(b["r"]) + 6.0:
            return id
    return ""


# ---------- ввод ----------

func _input(event: InputEvent) -> void:
    if not is_visible_in_tree() or Game.player == null:
        return
    if event is InputEventScreenTouch:
        var te: InputEventScreenTouch = event
        if te.pressed:
            _press(te.index, te.position)
        else:
            _release(te.index)
    elif event is InputEventScreenDrag:
        var de: InputEventScreenDrag = event
        _drag(de.index, de.position, de.relative)
    elif not DisplayServer.is_touchscreen_available():
        if event is InputEventMouseButton:
            var mb: InputEventMouseButton = event
            if mb.button_index == MOUSE_BUTTON_LEFT:
                if mb.pressed:
                    _press(0, mb.position)
                else:
                    _release(0)
        elif event is InputEventMouseMotion:
            var mm: InputEventMouseMotion = event
            if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
                _drag(0, mm.position, mm.relative)


func _press(idx: int, p: Vector2) -> void:
    if wheel_open:
        _wheel_press(p)
        return
    var id: String = _button_at(p)
    if id != "":
        _touch_btn[idx] = id
        _btn_down(id)
        return
    if not _car_mode and _joy_idx == -1 and p.x < size.x * 0.42 and p.y > size.y * 0.18:
        _joy_idx = idx
        _joy_c = p
        _joy_p = p
        return
    if _look_idx == -1:
        _look_idx = idx


func _release(idx: int) -> void:
    if _touch_btn.has(idx):
        _btn_up(str(_touch_btn[idx]))
        _touch_btn.erase(idx)
    if idx == _joy_idx:
        _joy_idx = -1
        Ctl.t_move = Vector2.ZERO
    if idx == _look_idx:
        _look_idx = -1


func _drag(idx: int, p: Vector2, rel: Vector2) -> void:
    if wheel_open:
        _wheel_hover = _wheel_sector(p)
        return
    if idx == _joy_idx:
        _joy_p = p
        var off: Vector2 = _joy_p - _joy_c
        if off.length() > JOY_R:
            _joy_p = _joy_c + off.normalized() * JOY_R
            off = _joy_p - _joy_c
        var v: Vector2 = off / JOY_R
        if v.length() < 0.12:
            v = Vector2.ZERO
        Ctl.t_move = v.limit_length(1.0)
    elif idx == _look_idx:
        Ctl.look += rel


func _release_all() -> void:
    _touch_btn.clear()
    _joy_idx = -1
    _look_idx = -1
    Ctl.t_move = Vector2.ZERO
    Ctl.t_fire = false
    Ctl.t_left = false
    Ctl.t_right = false
    Ctl.t_gas = false
    Ctl.t_rev = false
    Ctl.t_hand = false


func _btn_down(id: String) -> void:
    match id:
        "fire":
            Ctl.t_fire = true
        "run":
            run_on = not run_on
            Ctl.t_run = run_on
        "left":
            Ctl.t_left = true
        "right":
            Ctl.t_right = true
        "gas":
            Ctl.t_gas = true
        "rev":
            Ctl.t_rev = true
        "hand":
            Ctl.t_hand = true
        "jump", "reload", "interact", "cam", "drop", "horn":
            Ctl.action.emit(id)
        "pause":
            _release_all()
            open_pause.emit()
        "items":
            _release_all()
            open_items.emit()
        "wheel":
            _open_wheel()


func _btn_up(id: String) -> void:
    match id:
        "fire":
            Ctl.t_fire = false
        "left":
            Ctl.t_left = false
        "right":
            Ctl.t_right = false
        "gas":
            Ctl.t_gas = false
        "rev":
            Ctl.t_rev = false
        "hand":
            Ctl.t_hand = false


# ---------- круговое меню оружия ----------

func _open_wheel() -> void:
    _release_all()
    wheel_open = true
    _wheel_hover = -1
    Game.set_slowmo(true)


func close_wheel() -> void:
    if wheel_open:
        wheel_open = false
        Game.set_slowmo(false)


func _wheel_sector(p: Vector2) -> int:
    var v: Vector2 = p - size * 0.5
    var d: float = v.length()
    if d < 60.0 or d > 260.0:
        return -1
    var step: float = TAU / float(WeaponDefs.ORDER.size())
    return int(roundf(fposmod(v.angle() + PI * 0.5, TAU) / step)) % WeaponDefs.ORDER.size()


func _wheel_press(p: Vector2) -> void:
    var v: Vector2 = p - size * 0.5
    var d: float = v.length()
    if d < 60.0:
        Game.equip("")
        Sfx.play2d("click")
    elif d <= 260.0:
        var idx: int = _wheel_sector(p)
        if idx >= 0:
            var id: String = WeaponDefs.ORDER[idx]
            if Game.owned.has(id):
                Game.equip(id)
                Sfx.play2d("click")
            else:
                Game.say("Нет оружия: %s" % str(WeaponDefs.get_def(id)["name"]))
    close_wheel()


# ---------- кадр ----------

func _process(delta: float) -> void:
    if Game.player == null:
        return
    _flash_t = maxf(0.0, _flash_t - delta * 2.0)
    for t in _toasts:
        t["age"] = float(t["age"]) + delta
    while _toasts.size() > 0 and float(_toasts[0]["age"]) > 3.0:
        _toasts.pop_front()
    var car: bool = Game.player.in_vehicle != null
    if car != _car_mode:
        _car_mode = car
        _release_all()
        close_wheel()
    if size != _last_size or _btns.is_empty():
        _build_layout()
    Ctl.t_run = run_on
    queue_redraw()


func _draw() -> void:
    if Game.player == null or _btns.is_empty():
        return
    var w: float = size.x
    var h: float = size.y
    _draw_bars()
    if not _car_mode:
        var c: Vector2 = size * 0.5
        draw_arc(c, 3.6, 0.0, TAU, 16, Color(0, 0, 0, 0.55), 2.0, true)
        draw_circle(c, 2.4, Color(1, 1, 1, 0.95))
        if Game.prompt != "":
            draw_arc(c, 9.0, 0.0, TAU, 24, Color(1, 1, 1, 0.8), 1.6, true)
    _draw_joystick(h)
    for b in _btns:
        if _active(str(b["id"])):
            _draw_btn(b)
    if Game.prompt != "":
        var tw: float = 460.0
        draw_string(_font, Vector2(size.x * 0.5 - tw * 0.5 + 1.0, size.y * 0.5 + 56.0), Game.prompt, HORIZONTAL_ALIGNMENT_CENTER, tw, 22, Color(0, 0, 0, 0.7))
        draw_string(_font, Vector2(size.x * 0.5 - tw * 0.5, size.y * 0.5 + 55.0), Game.prompt, HORIZONTAL_ALIGNMENT_CENTER, tw, 22, Color(1, 1, 1, 0.95))
    var ty: float = 100.0
    for t in _toasts:
        var a: float = clampf(3.0 - float(t["age"]), 0.0, 1.0)
        draw_string(_font, Vector2(w * 0.5 - 300.0, ty), str(t["t"]), HORIZONTAL_ALIGNMENT_CENTER, 600.0, 22, Color(1, 0.95, 0.7, a))
        ty += 28.0
    if _flash_t > 0.0:
        draw_rect(Rect2(Vector2.ZERO, size), Color(0.8, 0.0, 0.0, _flash_t * 0.35))
    if wheel_open:
        _draw_wheel()


func _draw_bars() -> void:
    var hp: float = clampf(float(Game.player.hp) / 100.0, 0.0, 1.0)
    draw_rect(Rect2(28, 24, 224, 14), Color(0, 0, 0, 0.5))
    draw_rect(Rect2(30, 26, 220.0 * hp, 10), Color(0.85 - 0.5 * hp, 0.2 + 0.6 * hp, 0.2))
    var y: float = 62.0
    if Settings.show_fps:
        draw_string(_font, Vector2(30, y), "FPS %d" % Engine.get_frames_per_second(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.7))
    if Game.equipped != "" and not _car_mode:
        var wd: Dictionary = WeaponDefs.get_def(Game.equipped)
        var txt: String = str(wd["name"])
        if Game.owned.has(Game.equipped) and str(wd["kind"]) != "melee":
            var st: Dictionary = Game.owned[Game.equipped]
            txt += "   %d / %d" % [int(st["mag"]), int(st["reserve"])]
        draw_string(_font, Vector2(size.x - 420.0, 124.0), txt, HORIZONTAL_ALIGNMENT_RIGHT, 400.0, 22, Color(1, 1, 1, 0.9))


func _draw_joystick(h: float) -> void:
    if _car_mode:
        return
    if _joy_idx >= 0:
        draw_circle(_joy_c, JOY_R, Color(1, 1, 1, 0.12))
        draw_arc(_joy_c, JOY_R, 0.0, TAU, 48, Color(1, 1, 1, 0.4), 2.5, true)
        draw_circle(_joy_p, 34.0, Color(1, 1, 1, 0.45))
    else:
        var hint: Vector2 = Vector2(150.0, h - 140.0)
        draw_arc(hint, JOY_R, 0.0, TAU, 48, Color(1, 1, 1, 0.12), 2.0, true)
        draw_circle(hint, 30.0, Color(1, 1, 1, 0.08))


func _draw_btn(b: Dictionary) -> void:
    var id: String = b["id"]
    var c: Vector2 = b["c"]
    var r: float = b["r"]
    var pressed: bool = _touch_btn.values().has(id) or (id == "run" and run_on)
    draw_circle(c, r, Color(1, 1, 1, 0.3) if pressed else Color(0, 0, 0, 0.35))
    draw_arc(c, r, 0.0, TAU, 48, Color(1, 1, 1, 0.65), 2.5, true)
    var label: String = str(b["label"])
    if id == "interact":
        label = Game.prompt_btn
    var col: Color = Color(1, 1, 1, 0.95)
    match id:
        "pause":
            draw_rect(Rect2(c.x - 9, c.y - 10, 6, 20), col)
            draw_rect(Rect2(c.x + 3, c.y - 10, 6, 20), col)
            return
        "left":
            draw_colored_polygon(PackedVector2Array([c + Vector2(-26, 0), c + Vector2(16, -30), c + Vector2(16, 30)]), col)
            return
        "right":
            draw_colored_polygon(PackedVector2Array([c + Vector2(26, 0), c + Vector2(-16, -30), c + Vector2(-16, 30)]), col)
            return
        "wheel":
            if Game.equipped == "":
                Icons.draw_fist(self, c, 22.0, col)
            else:
                Icons.draw_weapon(self, Game.equipped, c, 24.0, col)
            return
    var fs: float = minf(r * 0.42, r * 1.8 / (float(maxi(label.length(), 1)) * 0.62))
    var fsi: int = clampi(int(fs), 9, 24)
    draw_string(_font, Vector2(c.x - r, c.y + float(fsi) * 0.35), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fsi, col)


func _draw_wheel() -> void:
    var c: Vector2 = size * 0.5
    var n: int = WeaponDefs.ORDER.size()
    var step: float = TAU / float(n)
    draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.25))
    draw_circle(c, 262.0, Color(0, 0, 0, 0.82))
    draw_arc(c, 262.0, 0.0, TAU, 64, Color(1, 1, 1, 0.35), 3.0, true)
    draw_circle(c, 58.0, Color(0.12, 0.12, 0.14, 0.95))
    draw_arc(c, 58.0, 0.0, TAU, 40, Color(1, 1, 1, 0.4), 2.0, true)
    Icons.draw_fist(self, c + Vector2(0, -4), 26.0, Color(1, 1, 1, 0.9) if Game.equipped == "" else Color(1, 1, 1, 0.55))
    draw_string(_font, Vector2(c.x - 50, c.y + 44), "Кулаки", HORIZONTAL_ALIGNMENT_CENTER, 100.0, 13, Color(1, 1, 1, 0.7))
    for i in n:
        var a: float = -PI * 0.5 + float(i) * step
        var edge: float = a - step * 0.5
        draw_line(c + Vector2(cos(edge), sin(edge)) * 58.0, c + Vector2(cos(edge), sin(edge)) * 262.0, Color(1, 1, 1, 0.18), 2.0)
        var id: String = WeaponDefs.ORDER[i]
        var owned: bool = Game.owned.has(id)
        var ic: Vector2 = c + Vector2(cos(a), sin(a)) * 160.0
        if i == _wheel_hover or (owned and Game.equipped == id):
            var pts := PackedVector2Array()
            for s in range(0, 13):
                var aa: float = a - step * 0.5 + step * float(s) / 12.0
                pts.append(c + Vector2(cos(aa), sin(aa)) * 70.0)
            for s in range(12, -1, -1):
                var aa2: float = a - step * 0.5 + step * float(s) / 12.0
                pts.append(c + Vector2(cos(aa2), sin(aa2)) * 256.0)
            draw_colored_polygon(pts, Color(1, 1, 1, 0.16 if owned else 0.06))
        var col: Color = Color(1, 1, 1, 0.95) if owned else Color(0.5, 0.5, 0.5, 0.45)
        Icons.draw_weapon(self, id, ic + Vector2(0, -8), 52.0, col)
        var label: String = str(WeaponDefs.get_def(id)["name"]) if owned else str(WeaponDefs.CATS[i])
        draw_string(_font, Vector2(ic.x - 70, ic.y + 44), label, HORIZONTAL_ALIGNMENT_CENTER, 140.0, 15, Color(col.r, col.g, col.b, 0.9 if owned else 0.5))
