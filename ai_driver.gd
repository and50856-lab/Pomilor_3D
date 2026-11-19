class_name AIDriver
extends RefCounted
# Езда по полосам сетки: светофоры, повороты, пропуск пешеходов, сигнал, объезд.

var veh: Vehicle
var axis: int = 0
var d: int = 1
var j: int = 0
var k: int = 0
var pos: Vector3 = Vector3.ZERO
var yaw: float = 0.0
var speed: float = 0.0
var path: Array = []
var pi: int = 1
var state: int = 0          # 0 подъезд к перекрёстку, 1 проезд перекрёстка
var committed: bool = false
var n_axis: int = 0
var n_d: int = 1
var n_j: int = 0
var n_k: int = 0
var cruise: float = 12.0
var half_len: float = 2.0
var stopped_t: float = 0.0
var blocked_t: float = 0.0
var honk_cd: float = 0.0
var ghost_t: float = 0.0
var calm_t: float = 0.0
var avoid: float = 0.0
var avoid_target: float = 0.0


func init_on_edge(v: Vehicle, a_j: int, a_k: int, ax: int, dir_: int, frac: float) -> void:
    veh = v
    axis = ax
    d = dir_
    half_len = v.half_len
    cruise = randf_range(10.0, 14.5)
    j = a_j + (dir_ if ax == 0 else 0)
    k = a_k + (dir_ if ax == 1 else 0)
    pos = edge_pos(a_j, a_k, ax, dir_, frac, half_len)
    yaw = _yaw_of(ax, d)
    state = 0
    _plan_approach()
    _apply(0.0)


static func edge_pos(a_j: int, a_k: int, ax: int, dir_: int, frac: float, hl: float) -> Vector3:
    var b_j: int = a_j + (dir_ if ax == 0 else 0)
    var b_k: int = a_k + (dir_ if ax == 1 else 0)
    var a_pos: Vector3 = Const.node_pos(a_j, a_k)
    var b_pos: Vector3 = Const.node_pos(b_j, b_k)
    var a_al: float = a_pos.x if ax == 0 else a_pos.z
    var b_al: float = b_pos.x if ax == 0 else b_pos.z
    var lo: float = a_al + float(dir_) * 14.0
    var hi: float = b_al - float(dir_) * (Const.STOP_D + hl + 4.0)
    var center: float = b_pos.z if ax == 0 else b_pos.x
    return Const.world_pt(ax, lerpf(lo, hi, frac), center + Const.lane_lat(ax, dir_))


static func _yaw_of(ax: int, dd: int) -> float:
    var dx: float = float(dd) if ax == 0 else 0.0
    var dz: float = float(dd) if ax == 1 else 0.0
    return atan2(-dx, -dz)


func _lane(ax: int, dd: int, node: Vector3) -> float:
    var center: float = node.z if ax == 0 else node.x
    return center + Const.lane_lat(ax, dd)


func _plan_approach() -> void:
    var node: Vector3 = Const.node_pos(j, k)
    var al: float = node.x if axis == 0 else node.z
    var stop_al: float = al - float(d) * (Const.STOP_D + half_len)
    var stop_pt: Vector3 = Const.world_pt(axis, stop_al, _lane(axis, d, node))
    path = [pos, stop_pt]
    pi = 1
    state = 0
    committed = false


func _plan_cross() -> void:
    var node: Vector3 = Const.node_pos(j, k)
    var hx: float = float(d) if axis == 0 else 0.0
    var hz: float = float(d) if axis == 1 else 0.0
    var opts: Array = []
    var weights: Array = []
    var vecs: Array = [Vector2(hx, hz), Vector2(hz, -hx), Vector2(-hz, hx)]
    var ws: Array = [0.5, 0.22, 0.28]
    for i in 3:
        var v: Vector2 = vecs[i]
        if Const.node_ok(j + int(v.x), k + int(v.y)):
            opts.append(v)
            weights.append(ws[i])
    if opts.is_empty():
        opts.append(Vector2(-hx, -hz))
        weights.append(1.0)
    var total: float = 0.0
    for w in weights:
        total += float(w)
    var roll: float = randf() * total
    var pick: Vector2 = opts[0]
    for i in opts.size():
        roll -= float(weights[i])
        if roll <= 0.0:
            pick = opts[i]
            break
    var ax2: int = 0 if absf(pick.x) > 0.5 else 1
    var d2: int = int(pick.x) if ax2 == 0 else int(pick.y)
    n_axis = ax2
    n_d = d2
    n_j = j + int(pick.x)
    n_k = k + int(pick.y)
    var le: float = _lane(axis, d, node)
    var lx: float = _lane(ax2, d2, node)
    var in_al: float = (node.x if axis == 0 else node.z) - float(d) * Const.R
    var out_al: float = (node.x if ax2 == 0 else node.z) + float(d2) * Const.R
    var p0: Vector3 = Const.world_pt(axis, in_al, le)
    var p2: Vector3 = Const.world_pt(ax2, out_al, lx)
    path = [p0]
    if ax2 == axis and d2 == d:
        path.append(p2)
    elif ax2 == axis:
        # разворот: просто короткая дуга через центр
        path.append(node + Vector3(0, 0, 0))
        path.append(p2)
    else:
        var p1: Vector3 = Const.world_pt(axis, lx, le)
        for s in range(1, 9):
            var t: float = float(s) / 8.0
            var q: Vector3 = p0 * ((1.0 - t) * (1.0 - t)) + p1 * (2.0 * (1.0 - t) * t) + p2 * (t * t)
            path.append(q)
    pi = 0
    state = 1
    avoid_target = 0.0


func _scan() -> Vector3:
    # x = расстояние до препятствия впереди, y = тип (1 пешеход, 2 машина), z = сторона
    var fwd: Vector3 = Vector3(-sin(yaw), 0.0, -cos(yaw))
    var right: Vector3 = Vector3(cos(yaw), 0.0, -sin(yaw))
    var me: Vector3 = pos + right * avoid
    var best: float = 1000.0
    var kind: float = 0.0
    var side: float = 0.0
    for w in Game.walkers():
        var o: Vector3 = (w as Node3D).global_position - me
        var f: float = o.dot(fwd)
        if f < 0.3 or f > 17.0:
            continue
        var l: float = o.dot(right)
        if absf(l) < 1.9:
            var gap: float = f - half_len
            if gap < best:
                best = gap
                kind = 1.0
                side = l
    if ghost_t <= 0.0 and Game.traffic != null:
        for c in Game.traffic.veh_cache:
            var cv: Vehicle = c as Vehicle
            if cv == null or cv == veh:
                continue
            var o2: Vector3 = cv.global_position - me
            var f2: float = o2.dot(fwd)
            if f2 < 0.3 or f2 > 20.0:
                continue
            var l2: float = o2.dot(right)
            if absf(l2) < 2.1 + (cv.width - 1.8) * 0.3:
                var gap2: float = f2 - half_len - cv.half_len
                if gap2 < best:
                    best = gap2
                    kind = 2.0
                    side = l2
    return Vector3(best, kind, side)


func update(dt: float) -> void:
    if path.is_empty():
        return
    honk_cd -= dt
    ghost_t -= dt
    var target: Vector3 = path[pi]
    var to: Vector3 = target - pos
    to.y = 0.0
    var dist: float = to.length()
    var final_leg: bool = pi == path.size() - 1
    var room: float = 1000.0
    if state == 0 and final_leg:
        var ls: int = Game.light_state(axis)
        if ls != 0 and not committed:
            var brake_d: float = speed * speed / 8.0
            if ls == 2 or brake_d < dist - 1.0:
                room = dist
            else:
                committed = true
    var obs: Vector3 = _scan()
    if obs.x < 1000.0:
        room = minf(room, obs.x - 3.2)
    var allow: float = cruise
    if room < 1000.0:
        allow = minf(cruise, sqrt(maxf(0.0, 2.0 * 4.5 * maxf(0.0, room))))
        if room <= 0.3:
            allow = 0.0
    if state == 1:
        allow = minf(allow, 7.5 if path.size() > 3 else cruise)
    var acc: float = 3.0 if allow > speed else 8.0
    speed = move_toward(speed, allow, acc * dt)

    # остановка / ожидание
    if speed < 0.3:
        stopped_t += dt
        if obs.y == 1.0 and obs.x < 8.0:
            if stopped_t > 1.4 and honk_cd <= 0.0:
                veh.honk()
                honk_cd = 2.6
            if stopped_t > 5.0:
                var s: float = -signf(obs.z) if absf(obs.z) > 0.15 else 1.0
                avoid_target = clampf(s * 2.0, -2.0, 2.0)
        elif obs.y == 2.0 and obs.x < 6.0:
            blocked_t += dt
            if blocked_t > 3.0 and honk_cd <= 0.0:
                veh.honk()
                honk_cd = 3.0
            if blocked_t > 8.0:
                ghost_t = 4.0
                blocked_t = 0.0
    else:
        stopped_t = 0.0
        blocked_t = maxf(0.0, blocked_t - dt)
    if obs.x >= 1000.0:
        calm_t += dt
        if calm_t > 2.5:
            avoid_target = 0.0
    else:
        calm_t = 0.0

    # на красном у стоп-линии — ждём
    if state == 0 and final_leg and dist < 0.7:
        var ls2: int = Game.light_state(axis)
        if ls2 == 0 or committed:
            _plan_cross()
        else:
            speed = 0.0
            _apply(dt)
            return
    var step: float = speed * dt
    if dist <= step + 0.02:
        pos = target
        if state == 0 and final_leg:
            pass
        else:
            pi += 1
            if pi >= path.size():
                _finish_cross()
    elif dist > 0.001:
        pos += to / dist * step
    _apply(dt)


func _finish_cross() -> void:
    axis = n_axis
    d = n_d
    j = n_j
    k = n_k
    _plan_approach()


func _apply(dt: float) -> void:
    if path.is_empty() or pi >= path.size():
        return
    var tgt: Vector3 = path[pi]
    var dv: Vector3 = tgt - pos
    dv.y = 0.0
    var prev_yaw: float = yaw
    if dv.length() > 0.2:
        var want: float = atan2(-dv.x, -dv.z)
        yaw = lerp_angle(yaw, want, minf(1.0, 7.0 * dt) if dt > 0.0 else 1.0)
    if dt > 0.0:
        veh.steer_vis = clampf(angle_difference(prev_yaw, yaw) / dt * 0.12, -0.45, 0.45)
    avoid = lerpf(avoid, avoid_target if state == 0 else 0.0, minf(1.0, dt * 1.5))
    var right: Vector3 = Vector3(cos(yaw), 0.0, -sin(yaw))
    var p: Vector3 = pos + right * avoid
    p.y = veh.wheel_r + 0.04
    veh.global_transform = Transform3D(Basis(Vector3.UP, yaw), p)
    veh.speed_ms = speed
