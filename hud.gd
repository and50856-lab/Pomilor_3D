class_name Hud
extends Control
# Сенсорный интерфейс: плавающий джойстик слева, кнопки справа, круговое меню оружия,
# мини-карта и полная карта, спидометр. Всё рисуется и обрабатывается вручную (мультитач).

signal open_items
signal open_pause

const JOY_R: float = 80.0
const MM_POS: Vector2 = Vector2(28.0, 50.0)
const MM_SIZE: float = 170.0

var run_on: bool = false
var wheel_open: bool = false
var map_open: bool = false
var map_center: Vector2 = Vector2.ZERO
var map_zoom: float = 1.2

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
var _map_touch: Dictionary = {}
var _pinch_d: float = 0.0
var _rd_t: float = 0.0
var _drop_held: bool = false
var _drop_ms: int = 0


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    UI.full_rect(self)
    _font = ThemeDB.fallback_font
    Game.toast.connect(_on_toast)


func _exit_tree() -> void:
    if wheel_open or map_open:
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
    _add("aim", Vector2(w - 95.0, h - 335.0), 38.0, "ПРИЦЕЛ")
    _add("interact", Vector2(w - 340.0, h - 235.0), 46.0, "ДА")
    _add("up", Vector2(w - 445.0, h - 120.0), 40.0, "ВВЕРХ")
    _add("down", Vector2(w - 445.0, h - 215.0), 40.0, "ВНИЗ")
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


func _drop_light() -> bool:
    return Game.equipped == "bat" or Game.equipped == "deagle"


func _has_gun() -> bool:
    if Game.equipped == "":
        return false
    var k: String = str(WeaponDefs.get_def(Game.equipped).get("kind", ""))
    return k == "gun" or k == "rocket"


func _active(id: String) -> bool:
    if _car_mode:
        return id in ["left", "right", "gas", "rev", "hand", "horn", "interact", "cam", "pause"]
    match id:
        "reload", "aim":
            return _has_gun()
        "drop":
            return Game.equipped != ""
        "up", "down":
            return Game.admin_noclip
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


func _mm_rect() -> Rect2:
    return Rect2(MM_POS, Vector2(MM_SIZE, MM_SIZE))


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
            elif map_open and mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
                _zoom_map(1.15 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 0.87)
        elif event is InputEventMouseMotion:
            var mm: InputEventMouseMotion = event
            if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
                _drag(0, mm.position, mm.relative)


func _press(idx: int, p: Vector2) -> void:
    if map_open:
        _map_press(idx, p)
        return
    if wheel_open:
        _wheel_press(p)
        return
    var id: String = _button_at(p)
    if id != "":
        _touch_btn[idx] = id
        _btn_down(id)
        return
    if _mm_rect().has_point(p):
        _open_map()
        return
    if not _car_mode and _joy_idx == -1 and p.x < size.x * 0.42 and p.y > size.y * 0.18:
        _joy_idx = idx
        _joy_c = p
        _joy_p = p
        return
    if _look_idx == -1:
        _look_idx = idx


func _release(idx: int) -> void:
    if _map_touch.has(idx):
        _map_touch.erase(idx)
        _pinch_d = 0.0
    if _touch_btn.has(idx):
        _btn_up(str(_touch_btn[idx]))
        _touch_btn.erase(idx)
    if idx == _joy_idx:
        _joy_idx = -1
        Ctl.t_move = Vector2.ZERO
    if idx == _look_idx:
        _look_idx = -1


func _drag(idx: int, p: Vector2, rel: Vector2) -> void:
    if map_open:
        _map_drag(idx, p, rel)
        return
    if wheel_open:
        _wheel_hover = _wheel_sector(p)
        return
    if _touch_btn.has(idx):
        # палец, зажавший ОГОНЬ, может крутить камеру
        if str(_touch_btn[idx]) == "fire":
            Ctl.look += rel
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
    _map_touch.clear()
    _joy_idx = -1
    _look_idx = -1
    Ctl.t_move = Vector2.ZERO
    Ctl.t_fire = false
    Ctl.t_left = false
    Ctl.t_right = false
    Ctl.t_gas = false
    Ctl.t_rev = false
    Ctl.t_hand = false
    Ctl.t_aim = false
    Ctl.t_up = false
    Ctl.t_down = false
    _drop_held = false


func _btn_down(id: String) -> void:
    match id:
        "fire":
            Ctl.t_fire = true
        "aim":
            if Settings.aim_toggle:
                Ctl.t_aim = not Ctl.t_aim
            else:
                Ctl.t_aim = true
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
        "jump", "reload", "interact", "cam", "horn":
            Ctl.action.emit(id)
        "drop":
            _drop_held = true
            _drop_ms = Time.get_ticks_msec()
        "up":
            Ctl.t_up = true
        "down":
            Ctl.t_down = true
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
        "aim":
            if not Settings.aim_toggle:
                Ctl.t_aim = false
        "drop":
            var held: float = float(Time.get_ticks_msec() - _drop_ms) / 1000.0
            _drop_held = false
            if held >= 0.25 and _drop_light():
                Ctl.throw_power = clampf(held / 3.0, 0.0, 1.0)
                Ctl.action.emit("throw")
            else:
                Ctl.action.emit("drop")
        "up":
            Ctl.t_up = false
        "down":
            Ctl.t_down = false
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


# ---------- карта ----------

func _city_half() -> float:
    return Const.half_size() + 12.0


func _fit_zoom() -> float:
    return minf(size.x - 60.0, size.y - 60.0) / (_city_half() * 2.0)


func _player_pos2() -> Vector2:
    var p: Vector3 = (Game.player as Node3D).global_position
    return Vector2(p.x, p.z)


func _player_heading() -> Vector2:
    var pl = Game.player
    if pl.in_vehicle != null:
        var f: Vector3 = -(pl.in_vehicle as Vehicle).global_transform.basis.z
        return Vector2(f.x, f.z).normalized()
    return Vector2(-sin(pl.cam_yaw), -cos(pl.cam_yaw))


func _open_map() -> void:
    _release_all()
    map_open = true
    map_center = _player_pos2()
    map_zoom = _fit_zoom()
    _pinch_d = 0.0
    Game.set_slowmo(true)


func close_map() -> void:
    if map_open:
        map_open = false
        _map_touch.clear()
        Game.set_slowmo(false)


func _zoom_map(f: float) -> void:
    var fz: float = _fit_zoom()
    map_zoom = clampf(map_zoom * f, fz * 0.7, fz * 7.0)


func _map_rect() -> Rect2:
    return Rect2(Vector2(30, 30), size - Vector2(60, 60))


func _map_press(idx: int, p: Vector2) -> void:
    var r: Rect2 = _map_rect()
    var close_c: Vector2 = Vector2(r.end.x - 40.0, r.position.y + 40.0)
    if p.distance_to(close_c) < 34.0:
        close_map()
        return
    var zin_c: Vector2 = Vector2(r.end.x - 40.0, r.get_center().y - 44.0)
    var zout_c: Vector2 = Vector2(r.end.x - 40.0, r.get_center().y + 44.0)
    if p.distance_to(zin_c) < 30.0:
        _zoom_map(1.4)
        return
    if p.distance_to(zout_c) < 30.0:
        _zoom_map(0.71)
        return
    _map_touch[idx] = p
    _pinch_d = 0.0


func _map_drag(idx: int, p: Vector2, rel: Vector2) -> void:
    if not _map_touch.has(idx):
        return
    _map_touch[idx] = p
    if _map_touch.size() == 1:
        map_center -= rel / map_zoom
        var hh: float = _city_half() + 40.0
        map_center = Vector2(clampf(map_center.x, -hh, hh), clampf(map_center.y, -hh, hh))
    elif _map_touch.size() >= 2:
        var pts: Array = _map_touch.values()
        var dn: float = (pts[0] as Vector2).distance_to(pts[1] as Vector2)
        if _pinch_d > 10.0 and dn > 10.0:
            _zoom_map(dn / _pinch_d)
        _pinch_d = dn


func _w2s(w: Vector2, rect: Rect2, center: Vector2, sc: float) -> Vector2:
    return rect.get_center() + (w - center) * sc


func _fill(world_min: Vector2, world_size: Vector2, rect: Rect2, center: Vector2, sc: float, col: Color) -> void:
    var r := Rect2(_w2s(world_min, rect, center, sc), world_size * sc)
    var c: Rect2 = r.intersection(rect)
    if c.size.x > 0.0 and c.size.y > 0.0:
        draw_rect(c, col)


func _draw_city(rect: Rect2, center: Vector2, sc: float) -> void:
    draw_rect(rect, Color(0.09, 0.16, 0.09))
    var hh: float = _city_half()
    _fill(Vector2(-hh, -hh), Vector2(hh * 2.0, hh * 2.0), rect, center, sc, Color(0.27, 0.27, 0.3))
    var blk: float = Const.PITCH - Const.ROAD_W
    for bj in range(Const.N - 1):
        for bk in range(Const.N - 1):
            var a: Vector3 = Const.node_pos(bj, bk)
            var b: Vector3 = Const.node_pos(bj + 1, bk + 1)
            var cc: Vector3 = (a + b) * 0.5
            _fill(Vector2(cc.x - blk * 0.5, cc.z - blk * 0.5), Vector2(blk, blk), rect, center, sc, Color(0.2, 0.29, 0.2))


func _draw_arrow(c: Vector2, heading: Vector2, s: float) -> void:
    var tip: Vector2 = c + heading * s
    var l: Vector2 = c + heading.rotated(2.5) * s * 0.75
    var r: Vector2 = c + heading.rotated(-2.5) * s * 0.75
    var pts := PackedVector2Array([tip, l, c - heading * s * 0.2, r])
    draw_colored_polygon(pts, Color(1, 1, 1))
    draw_polyline(PackedVector2Array([tip, l, c - heading * s * 0.2, r, tip]), Color(0, 0, 0, 0.8), 2.0)


func _draw_minimap() -> void:
    var rect: Rect2 = _mm_rect()
    var center: Vector2 = _player_pos2()
    var sc: float = MM_SIZE / 260.0
    _draw_city(rect, center, sc)
    draw_rect(rect, Color(1, 1, 1, 0.55), false, 2.0)
    _draw_arrow(rect.get_center(), _player_heading(), 11.0)


func _draw_fullmap() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.8))
    var rect: Rect2 = _map_rect()
    _draw_city(rect, map_center, map_zoom)
    draw_rect(rect, Color(1, 1, 1, 0.6), false, 3.0)
    var pp: Vector2 = _w2s(_player_pos2(), rect, map_center, map_zoom)
    if rect.has_point(pp):
        _draw_arrow(pp, _player_heading(), 16.0)
    var close_c: Vector2 = Vector2(rect.end.x - 40.0, rect.position.y + 40.0)
    draw_circle(close_c, 28.0, Color(0, 0, 0, 0.6))
    draw_arc(close_c, 28.0, 0.0, TAU, 32, Color(1, 1, 1, 0.8), 2.5, true)
    draw_line(close_c + Vector2(-9, -9), close_c + Vector2(9, 9), Color(1, 1, 1), 3.0)
    draw_line(close_c + Vector2(-9, 9), close_c + Vector2(9, -9), Color(1, 1, 1), 3.0)
    var zin_c: Vector2 = Vector2(rect.end.x - 40.0, rect.get_center().y - 44.0)
    var zout_c: Vector2 = Vector2(rect.end.x - 40.0, rect.get_center().y + 44.0)
    for z in [zin_c, zout_c]:
        draw_circle(z, 26.0, Color(0, 0, 0, 0.6))
        draw_arc(z, 26.0, 0.0, TAU, 32, Color(1, 1, 1, 0.8), 2.5, true)
    draw_line(zin_c + Vector2(-10, 0), zin_c + Vector2(10, 0), Color(1, 1, 1), 3.0)
    draw_line(zin_c + Vector2(0, -10), zin_c + Vector2(0, 10), Color(1, 1, 1), 3.0)
    draw_line(zout_c + Vector2(-10, 0), zout_c + Vector2(10, 0), Color(1, 1, 1), 3.0)
    draw_string(_font, Vector2(rect.position.x + 16.0, rect.position.y + 30.0), "КАРТА", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.85))


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
        close_map()
    if size.x < 100.0 or size.y < 100.0:
        position = Vector2.ZERO
        size = get_viewport_rect().size
    if size != _last_size or _btns.is_empty():
        _build_layout()
    Ctl.t_run = run_on
    _rd_t += delta
    var busy: bool = _joy_idx >= 0 or not _touch_btn.is_empty() or wheel_open or map_open or _flash_t > 0.0
    if busy or _rd_t >= 0.04:
        _rd_t = 0.0
        queue_redraw()


func _draw() -> void:
    if Game.player == null or _btns.is_empty():
        return
    var w: float = size.x
    _draw_bars()
    _draw_minimap()
    if not _car_mode:
        var c: Vector2 = size * 0.5
        draw_arc(c, 3.6, 0.0, TAU, 16, Color(0, 0, 0, 0.55), 2.0, true)
        draw_circle(c, 2.4, Color(1, 1, 1, 0.95))
        if Game.prompt != "":
            draw_arc(c, 9.0, 0.0, TAU, 24, Color(1, 1, 1, 0.8), 1.6, true)
        if bool(Game.player.ads):
            draw_arc(c, 16.0, 0.0, TAU, 32, Color(1, 1, 1, 0.5), 1.4, true)
    if _drop_held and _drop_light():
        var held: float = float(Time.get_ticks_msec() - _drop_ms) / 1000.0
        if held > 0.25:
            var cb: Vector2 = size * 0.5 + Vector2(-40, 34)
            draw_rect(Rect2(cb, Vector2(80, 7)), Color(0, 0, 0, 0.6))
            draw_rect(Rect2(cb + Vector2(1, 1), Vector2(78.0 * clampf(held / 3.0, 0.0, 1.0), 5)), Color(1, 0.85, 0.3))
    _draw_joystick(size.y)
    for b in _btns:
        if _active(str(b["id"])):
            _draw_btn(b)
    if _car_mode:
        _draw_speedometer()
    var ty: float = 100.0
    for t in _toasts:
        var a: float = clampf(3.0 - float(t["age"]), 0.0, 1.0)
        draw_string(_font, Vector2(w * 0.5 - 300.0, ty), str(t["t"]), HORIZONTAL_ALIGNMENT_CENTER, 600.0, 22, Color(1, 0.95, 0.7, a))
        ty += 28.0
    if _flash_t > 0.0:
        draw_rect(Rect2(Vector2.ZERO, size), Color(0.8, 0.0, 0.0, _flash_t * 0.35))
    if wheel_open:
        _draw_wheel()
    if map_open:
        _draw_fullmap()


func _draw_bars() -> void:
    var hp: float = clampf(float(Game.player.hp) / 100.0, 0.0, 1.0)
    if not Game.admin_god:
        draw_rect(Rect2(28, 24, 224, 14), Color(0, 0, 0, 0.5))
        draw_rect(Rect2(30, 26, 220.0 * hp, 10), Color(0.85 - 0.5 * hp, 0.2 + 0.6 * hp, 0.2))
        draw_string(_font, Vector2(260, 38), str(int(ceil(float(Game.player.hp)))), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 1, 1, 0.95))
    if Settings.show_fps:
        draw_string(_font, Vector2(30, MM_POS.y + MM_SIZE + 22.0), "FPS %d" % Engine.get_frames_per_second(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.7))
    if Game.equipped != "" and not _car_mode:
        var wd: Dictionary = WeaponDefs.get_def(Game.equipped)
        var txt: String = str(wd["name"])
        if Game.owned.has(Game.equipped) and str(wd["kind"]) != "melee":
            var st: Dictionary = Game.owned[Game.equipped]
            var mg: String = "∞" if (Game.admin_inf and Game.admin_noreload) else str(int(st["mag"]))
            var rs: String = "∞" if Game.admin_inf else str(int(st["reserve"]))
            txt += "   %s / %s" % [mg, rs]
        draw_string(_font, Vector2(size.x - 420.0, 124.0), txt, HORIZONTAL_ALIGNMENT_RIGHT, 400.0, 22, Color(1, 1, 1, 0.9))


func _draw_speedometer() -> void:
    var v: Vehicle = Game.player.in_vehicle as Vehicle
    if v == null:
        return
    var kmh: float = absf(v.speed_ms) * 3.6
    var max_kmh: float = ceilf(float(v.def["vmax"]) * 3.6 / 20.0) * 20.0
    var c: Vector2 = Vector2(size.x * 0.5, size.y - 92.0)
    var r: float = 74.0
    var a0: float = PI * 0.75
    var a1: float = PI * 2.25
    draw_circle(c, r + 6.0, Color(0, 0, 0, 0.45))
    draw_arc(c, r, a0, a1, 64, Color(1, 1, 1, 0.35), 3.0, true)
    var step: float = 20.0 if max_kmh <= 200.0 else 40.0
    var s: float = 0.0
    while s <= max_kmh + 0.1:
        var a: float = a0 + (a1 - a0) * (s / max_kmh)
        var dirv: Vector2 = Vector2(cos(a), sin(a))
        draw_line(c + dirv * (r - 9.0), c + dirv * r, Color(1, 1, 1, 0.8), 2.0)
        if int(s) % int(step * 2.0) == 0:
            var tp: Vector2 = c + dirv * (r - 22.0)
            draw_string(_font, tp - Vector2(16, -5), str(int(s)), HORIZONTAL_ALIGNMENT_CENTER, 32.0, 12, Color(1, 1, 1, 0.75))
        s += step
    var an: float = a0 + (a1 - a0) * clampf(kmh / max_kmh, 0.0, 1.0)
    draw_line(c, c + Vector2(cos(an), sin(an)) * (r - 12.0), Color(1.0, 0.35, 0.15), 3.0)
    draw_circle(c, 5.0, Color(1, 1, 1))
    draw_string(_font, Vector2(c.x - 50.0, c.y + 34.0), str(int(round(kmh))), HORIZONTAL_ALIGNMENT_CENTER, 100.0, 30, Color(1, 1, 1))
    draw_string(_font, Vector2(c.x - 40.0, c.y + 52.0), "км/ч", HORIZONTAL_ALIGNMENT_CENTER, 80.0, 13, Color(1, 1, 1, 0.7))


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
    var pressed: bool = _touch_btn.values().has(id) or (id == "run" and run_on) or (id == "aim" and Ctl.t_aim)
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
