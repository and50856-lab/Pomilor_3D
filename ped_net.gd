class_name PedNet
extends RefCounted
# Граф тротуаров и переходов. Узлы — углы кварталов (по 4 на перекрёсток).

var pts: Array = []
var adj: Array = []
var cross_axis: Dictionary = {}      # "a_b" -> ось дороги, которую пересекают (-1 тротуар)
var center_lat: Dictionary = {}      # "a_b" -> координата оси дороги (для обхода посередине квартала)
var edge_dir_axis: Dictionary = {}   # "a_b" -> ось, вдоль которой идёт тротуар
var _idx: Dictionary = {}


static func _key(a: int, b: int) -> String:
    return "%d_%d" % [a, b]


func _has(j: int, k: int, sx: int, sz: int) -> bool:
    return Const.node_ok(j, k) and Const.node_ok(j + sx, k + sz)


func _pt(j: int, k: int, sx: int, sz: int) -> int:
    var key: String = "%d_%d_%d_%d" % [j, k, sx, sz]
    if _idx.has(key):
        return _idx[key]
    return -1


func _link(a: int, b: int, cross: int, center: float, edge_axis: int) -> void:
    if a < 0 or b < 0:
        return
    (adj[a] as Array).append(b)
    (adj[b] as Array).append(a)
    for key in [_key(a, b), _key(b, a)]:
        cross_axis[key] = cross
        center_lat[key] = center
        edge_dir_axis[key] = edge_axis


func build() -> void:
    for j in Const.N:
        for k in Const.N:
            for sx in [-1, 1]:
                for sz in [-1, 1]:
                    if _has(j, k, sx, sz):
                        var p: Vector3 = Const.node_pos(j, k) + Vector3(float(sx) * Const.SIDE_C, Const.CURB, float(sz) * Const.SIDE_C)
                        _idx["%d_%d_%d_%d" % [j, k, sx, sz]] = pts.size()
                        pts.append(p)
                        adj.append([])
    for j in Const.N:
        for k in Const.N:
            var c: Vector3 = Const.node_pos(j, k)
            for sx in [-1, 1]:
                for sz in [-1, 1]:
                    var a: int = _pt(j, k, sx, sz)
                    if a < 0:
                        continue
                    # переход через ногу дороги по X (ось 0): (sx,sz) <-> (sx,-sz)
                    if sz == 1:
                        var b: int = _pt(j, k, sx, -1)
                        if b >= 0 and Const.node_ok(j + sx, k):
                            _link(a, b, 0, c.z, 1)
                    # переход через ногу по Z (ось 1): (sx,sz) <-> (-sx,sz)
                    if sx == 1:
                        var b2: int = _pt(j, k, -1, sz)
                        if b2 >= 0 and Const.node_ok(j, k + sz):
                            _link(a, b2, 1, c.x, 0)
            # тротуары вдоль дорог
            for sz in [-1, 1]:
                var a1: int = _pt(j, k, 1, sz)
                var b1: int = _pt(j + 1, k, -1, sz)
                if a1 >= 0 and b1 >= 0:
                    _link(a1, b1, -1, c.z, 0)
            for sx in [-1, 1]:
                var a2: int = _pt(j, k, sx, 1)
                var b3: int = _pt(j, k + 1, sx, -1)
                if a2 >= 0 and b3 >= 0:
                    _link(a2, b3, -1, c.x, 1)


func nearest(p: Vector3) -> int:
    var best: int = 0
    var bd: float = 1e9
    for i in pts.size():
        var dd: float = (pts[i] as Vector3).distance_squared_to(p)
        if dd < bd:
            bd = dd
            best = i
    return best


func edge_cross(a: int, b: int) -> int:
    var key: String = _key(a, b)
    if cross_axis.has(key):
        return cross_axis[key]
    return -1
