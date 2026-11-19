class_name Const
extends RefCounted

# Слои физики
const L_WORLD: int = 1
const L_CHAR: int = 2
const L_VEH: int = 4
const L_HIT: int = 8
const L_ITEM: int = 16

# Сетка города. axis 0 = движение вдоль X, axis 1 = вдоль Z
const N: int = 7
const PITCH: float = 84.0
const ROAD_W: float = 10.0
const R: float = 5.0
const SW: float = 4.0
const LANE: float = 2.5
const CURB: float = 0.12
const SIDE_C: float = 7.0
const STOP_D: float = 9.8
const CYCLE: float = 24.0


static func node_pos(j: int, k: int) -> Vector3:
    var h: float = float(N - 1) * 0.5
    return Vector3((float(j) - h) * PITCH, 0.0, (float(k) - h) * PITCH)


static func half_size() -> float:
    return float(N - 1) * 0.5 * PITCH


static func world_pt(axis: int, along: float, lat: float) -> Vector3:
    if axis == 0:
        return Vector3(along, 0.0, lat)
    return Vector3(lat, 0.0, along)


static func lane_lat(axis: int, d: int) -> float:
    if axis == 0:
        return float(d) * LANE
    return -float(d) * LANE


static func node_ok(j: int, k: int) -> bool:
    return j >= 0 and k >= 0 and j < N and k < N
