class_name Icons
extends RefCounted
# Рисованные 2D-иконки оружия и машин. Если есть res://assets/icons/<id>.png — берётся он.

static var _tex: Dictionary = {}


static func _p(ci: CanvasItem, c: Vector2, s: float, pts: Array, col: Color) -> void:
    var arr := PackedVector2Array()
    for p in pts:
        arr.append(c + (p as Vector2) * s)
    ci.draw_colored_polygon(arr, col)


static func _custom(id: String) -> Texture2D:
    if _tex.has(id):
        return _tex[id]
    var path: String = "res://assets/icons/%s.png" % id
    var t: Texture2D = null
    if ResourceLoader.exists(path):
        t = load(path)
    _tex[id] = t
    return t


static func draw_weapon(ci: CanvasItem, id: String, c: Vector2, s: float, col: Color) -> void:
    var tex: Texture2D = _custom(id)
    if tex != null:
        ci.draw_texture_rect(tex, Rect2(c - Vector2(s, s), Vector2(s, s) * 2.0), false, col)
        return
    match id:
        "bat":
            _p(ci, c, s, [Vector2(-0.95, 0.38), Vector2(-0.95, 0.5), Vector2(-0.6, 0.5), Vector2(0.95, -0.18), Vector2(0.95, -0.4), Vector2(0.6, -0.4)], col)
        "deagle":
            _p(ci, c, s, [Vector2(-0.8, -0.3), Vector2(0.8, -0.3), Vector2(0.8, 0.0), Vector2(0.0, 0.0), Vector2(-0.8, 0.0)], col)
            _p(ci, c, s, [Vector2(-0.1, 0.0), Vector2(0.4, 0.0), Vector2(0.15, 0.55), Vector2(-0.3, 0.55)], col)
            _p(ci, c, s, [Vector2(-0.1, 0.0), Vector2(-0.4, 0.0), Vector2(-0.4, 0.2), Vector2(-0.1, 0.2)], col)
        "ak47":
            _p(ci, c, s, [Vector2(-0.95, -0.12), Vector2(-0.45, -0.12), Vector2(-0.2, -0.2), Vector2(0.9, -0.2), Vector2(0.9, -0.08), Vector2(-0.2, -0.0), Vector2(-0.5, 0.15), Vector2(-0.95, 0.2)], col)
            _p(ci, c, s, [Vector2(-0.25, 0.0), Vector2(0.05, 0.0), Vector2(0.18, 0.5), Vector2(-0.05, 0.52)], col)
            _p(ci, c, s, [Vector2(-0.45, 0.0), Vector2(-0.3, 0.0), Vector2(-0.38, 0.32), Vector2(-0.52, 0.3)], col)
            _p(ci, c, s, [Vector2(0.0, -0.2), Vector2(0.6, -0.2), Vector2(0.6, -0.02), Vector2(0.0, -0.02)], col)
        "mossberg":
            _p(ci, c, s, [Vector2(-0.95, -0.1), Vector2(-0.55, -0.12), Vector2(-0.4, -0.22), Vector2(0.95, -0.22), Vector2(0.95, -0.12), Vector2(-0.3, -0.04), Vector2(-0.55, 0.2), Vector2(-0.95, 0.22)], col)
            _p(ci, c, s, [Vector2(0.1, -0.08), Vector2(0.62, -0.08), Vector2(0.62, 0.06), Vector2(0.1, 0.06)], col)
            _p(ci, c, s, [Vector2(-0.4, -0.04), Vector2(-0.12, -0.04), Vector2(-0.2, 0.3), Vector2(-0.42, 0.3)], col)
        "rpg":
            _p(ci, c, s, [Vector2(-0.8, -0.12), Vector2(0.45, -0.12), Vector2(0.45, 0.08), Vector2(-0.8, 0.08)], col)
            _p(ci, c, s, [Vector2(0.45, -0.22), Vector2(0.95, -0.02), Vector2(0.45, 0.18)], col)
            _p(ci, c, s, [Vector2(-1.0, -0.2), Vector2(-0.8, -0.12), Vector2(-0.8, 0.08), Vector2(-1.0, 0.16)], col)
            _p(ci, c, s, [Vector2(-0.15, 0.08), Vector2(0.1, 0.08), Vector2(0.0, 0.5), Vector2(-0.22, 0.5)], col)
        _:
            ci.draw_circle(c, s * 0.4, col)


static func draw_person(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
    ci.draw_circle(c + Vector2(0, -s * 0.9), s * 0.26, col)
    _p(ci, c, s, [Vector2(-0.4, -0.55), Vector2(0.4, -0.55), Vector2(0.46, 0.15), Vector2(0.2, 0.15), Vector2(0.2, 0.95), Vector2(-0.2, 0.95), Vector2(-0.2, 0.15), Vector2(-0.46, 0.15)], col)


static func draw_fist(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
    ci.draw_circle(c + Vector2(0, -s * 0.05), s * 0.42, col)
    for i in 4:
        ci.draw_circle(c + Vector2((float(i) - 1.5) * s * 0.2, -s * 0.38), s * 0.11, col)
    _p(ci, c, s, [Vector2(-0.3, 0.3), Vector2(0.3, 0.3), Vector2(0.24, 0.7), Vector2(-0.24, 0.7)], col)


static func draw_car(ci: CanvasItem, id: String, c: Vector2, s: float, col: Color) -> void:
    var tex: Texture2D = _custom(id)
    if tex != null:
        ci.draw_texture_rect(tex, Rect2(c - Vector2(s, s), Vector2(s, s) * 2.0), false, col)
        return
    var dark: Color = col.darkened(0.55)
    match id:
        "g_class":
            _p(ci, c, s, [Vector2(-0.9, 0.25), Vector2(-0.9, -0.2), Vector2(-0.7, -0.22), Vector2(-0.62, -0.62), Vector2(0.5, -0.62), Vector2(0.58, -0.22), Vector2(0.9, -0.2), Vector2(0.9, 0.25)], col)
            _p(ci, c, s, [Vector2(-0.55, -0.55), Vector2(0.0, -0.55), Vector2(0.0, -0.25), Vector2(-0.6, -0.25)], dark)
            _p(ci, c, s, [Vector2(0.05, -0.55), Vector2(0.45, -0.55), Vector2(0.5, -0.25), Vector2(0.05, -0.25)], dark)
        "vaz":
            _p(ci, c, s, [Vector2(-0.95, 0.25), Vector2(-0.95, -0.05), Vector2(-0.6, -0.12), Vector2(-0.3, -0.5), Vector2(0.3, -0.5), Vector2(0.55, -0.12), Vector2(0.95, -0.02), Vector2(0.95, 0.25)], col)
            _p(ci, c, s, [Vector2(-0.52, -0.1), Vector2(-0.28, -0.42), Vector2(-0.02, -0.42), Vector2(-0.02, -0.1)], dark)
            _p(ci, c, s, [Vector2(0.04, -0.1), Vector2(0.04, -0.42), Vector2(0.27, -0.42), Vector2(0.46, -0.1)], dark)
        "gallardo":
            _p(ci, c, s, [Vector2(-1.0, 0.22), Vector2(-1.0, 0.0), Vector2(-0.55, -0.12), Vector2(-0.1, -0.42), Vector2(0.3, -0.4), Vector2(0.62, -0.1), Vector2(1.0, 0.0), Vector2(1.0, 0.22)], col)
            _p(ci, c, s, [Vector2(-0.05, -0.34), Vector2(0.28, -0.34), Vector2(0.5, -0.12), Vector2(-0.2, -0.12)], dark)
        _:
            _p(ci, c, s, [Vector2(-0.9, 0.25), Vector2(-0.9, -0.2), Vector2(0.9, -0.2), Vector2(0.9, 0.25)], col)
    var wc: Color = Color(0.05, 0.05, 0.06, col.a)
    ci.draw_circle(c + Vector2(-0.55, 0.28) * s, s * 0.2, wc)
    ci.draw_circle(c + Vector2(0.55, 0.28) * s, s * 0.2, wc)
    ci.draw_circle(c + Vector2(-0.55, 0.28) * s, s * 0.09, col)
    ci.draw_circle(c + Vector2(0.55, 0.28) * s, s * 0.09, col)
