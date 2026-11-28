class_name AIDriver
extends RefCounted
# Водитель трафика. Едет по полосам сетки: светофоры, повороты, пропуск пешеходов, сигнал.
# Рядом с игроком машина — настоящее физическое тело, которым управляют руль и педали
# (плавный разгон, объезд препятствий задним ходом и манёвром). Вдали — лёгкая кинематика.

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
var panic: bool = false
var panic_t: float = 0.0
var maneuver: int = 0       # 0 обычная езда, 1 задний ход, 2 объезд
var man_t: float = 0.0
var stuck_t: float = 0.0
var prev_speed: float = 0.0
var flip_t: float = 0.0
var hit_cd: float = 0.0
var honk_n: int = 0
var lost_t: float = 0.0


func init_on_edge(v: Vehicle, a_j: int, a_k: int, ax: int, dir_: int, frac: float) -> void:
    veh = v
    axis = ax
    d = dir_
    half_len = v.half_len
    cruise = randf_range(13.0, 16.5)
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


# Вызывается, когда машина переключается обратно на лёгкий режим.
func sync_from_vehicle() -> void:
    var p: Vector3 = veh.global_position
    pos = Vector3(p.x, 0.0, p.z)
    var f3: Vector3 = -veh.global_transform.basis.z
    yaw = atan2(-f3.x, -f3.z)
    speed = maxf(veh.speed_ms, 0.0)
    avoid = 0.0
    avoid_target = 0.0
    maneuver = 0
    if state == 0:
        _plan_approach()


func _plan_approach() -> void:
    var node: Vector3 = Const.node_pos(j, k)
    var al: float = node.x if axis == 0 else node.z
    var lane_c: float = _lane(axis, d, node)
    var cur_al: float = pos.x if axis == 0 else pos.z
    var start: Vector3 = Const.world_pt(axis, cur_al, lane_c)
    var stop_al: float = al - float(d) * (Const.STOP_D + half_len)
    path = [start, Const.world_pt(axis, stop_al, lane_c)]
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
        path.append(node)
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


func _finish_cross() -> void:
    axis = n_axis
    d = n_d
    j = n_j
    k = n_k
    _plan_approach()


# Что впереди: x — расстояние (м), y — тип (1 человек, 2 машина), z — боковое смещение препятствия.
func _scan(phys: bool) -> Vector3:
    var fwd: Vector3 = Vector3(-sin(yaw), 0.0, -cos(yaw))
    var right: Vector3 = Vector3(cos(yaw), 0.0, -sin(yaw))
    var me: Vector3 = pos if phys else pos + right * avoid
    var best: float = 1000.0
    var kind: float = 0.0
    var side: float = 0.0
    var ped_w: float = veh.width * 0.5 + 0.95
    for w in Game.walkers():
        if not is_instance_valid(w):
            continue
        var o: Vector3 = (w as Node3D).global_position - me
        var f: float = o.dot(fwd)
        if f < 0.3 or f > 17.0:
            continue
        var l: float = o.dot(right)
        if absf(l) < ped_w:
            var gap: float = f - half_len
            if gap < best:
                best = gap
                kind = 1.0
                side = l
    if ghost_t <= 0.0 and Game.traffic != null:
        for c in Game.traffic.veh_cache:
            if not is_instance_valid(c):
                continue
            var cv: Vehicle = c as Vehicle
            if cv == null or cv == veh:
                continue
            var o2: Vector3 = cv.global_position - me
            var f2: float = o2.dot(fwd)
            if f2 < 0.3 or f2 > 22.0:
                continue
            var l2: float = o2.dot(right)
            if absf(l2) < veh.width * 0.5 + cv.width * 0.5 + 0.45:
                var gap2: float = f2 - half_len - cv.half_len
                if gap2 < best:
                    best = gap2
                    kind = 2.0
                    side = l2
    if phys:
        var o3: Vector3 = veh.global_position + Vector3(0, 0.7, 0)
        var q := PhysicsRayQueryParameters3D.create(o3, o3 + fwd * (8.0 + maxf(speed, 0.0) * 0.5), Const.L_WORLD)
        q.exclude = veh._ex
        var h: Dictionary = veh.get_world_3d().direct_space_state.intersect_ray(q)
        if not h.is_empty():
            var hp3: Vector3 = h["position"]
            var gap3: float = o3.distance_to(hp3) - half_len
            if gap3 < best:
                best = gap3
                kind = 3.0
                side = 0.0
    return Vector3(best, kind, side)


func _rear_clear() -> bool:
    var fwd: Vector3 = -veh.global_transform.basis.z
    var o: Vector3 = veh.global_position + Vector3(0, 0.6, 0)
    var q := PhysicsRayQueryParameters3D.create(o, o - fwd * (half_len + 3.0), Const.L_WORLD | Const.L_VEH)
    q.exclude = veh._ex
    return veh.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _pick_side(obs: Vector3) -> float:
    if obs.y == 1.0 and absf(obs.z) > 0.7:
        return -signf(obs.z) * 3.0
    var lat_v: Vector3 = Vector3(0, 0, 1) if axis == 0 else Vector3(1, 0, 0)
    var to_center: Vector3 = -signf(Const.lane_lat(axis, d)) * lat_v
    var right: Vector3 = Vector3(cos(yaw), 0.0, -sin(yaw))
    var s: float = signf(to_center.dot(right))
    if s == 0.0:
        s = 1.0
    return s * 3.2


func _seg_dir() -> Vector3:
    var a: Vector3 = path[pi - 1] if pi > 0 else pos
    var b: Vector3 = path[pi]
    var v: Vector3 = b - a
    v.y = 0.0
    if v.length() < 0.01:
        return Vector3(-sin(yaw), 0.0, -cos(yaw))
    return v.normalized()


func _lookahead(dist_ahead: float) -> Vector3:
    var a: Vector3 = path[pi - 1] if pi > 0 else pos
    var b: Vector3 = path[pi]
    var ab: Vector3 = b - a
    ab.y = 0.0
    var len2: float = ab.length_squared()
    var t: float = 0.0
    if len2 > 0.0001:
        t = clampf((pos - a).dot(ab) / len2, 0.0, 1.0)
    var p: Vector3 = a + ab * t
    var remaining: float = dist_ahead
    var idx: int = pi
    while true:
        var seg_end: Vector3 = path[idx]
        var dd: float = (seg_end - p).length()
        if dd >= remaining or idx >= path.size() - 1:
            if dd > 0.001:
                return p + (seg_end - p) * minf(remaining / dd, 1.0)
            return seg_end
        remaining -= dd
        p = seg_end
        idx += 1
    return p


func update(dt: float) -> void:
    if path.is_empty():
        return
    var phys: bool = veh.mode == Vehicle.Mode.AI_PHYS
    honk_cd -= dt
    ghost_t -= dt
    hit_cd -= dt
    if panic:
        panic_t -= dt
        if panic_t <= 0.0:
            panic = false
    if phys:
        var p: Vector3 = veh.global_position
        pos = Vector3(p.x, 0.0, p.z)
        var f3: Vector3 = -veh.global_transform.basis.z
        yaw = atan2(-f3.x, -f3.z)
        speed = veh.speed_ms
        if prev_speed - speed > 4.0 and hit_cd <= 0.0:
            hit_cd = 3.0
            veh.honk()
            if prev_speed - speed > 9.0 and veh.driver_npc != null and is_instance_valid(veh.driver_npc) and randf() < 0.4:
                veh.driver_npc.call("bail_out", veh, true)
        prev_speed = speed
        if veh.is_flipped():
            flip_t += dt
            if flip_t > 3.0 and veh.driver_npc != null and is_instance_valid(veh.driver_npc):
                veh.driver_npc.call("bail_out", veh, true)
        else:
            flip_t = 0.0

    var target: Vector3 = path[pi]
    var final_leg: bool = pi == path.size() - 1
    var to: Vector3 = target - pos
    to.y = 0.0
    var dist: float = to.length()
    var ahead: float = 1000.0
    if state == 0 and final_leg:
        ahead = float(d) * ((target.x - pos.x) if axis == 0 else (target.z - pos.z))
    var room: float = 1000.0
    if state == 0 and final_leg:
        var ls: int = Game.light_state(axis)
        if panic:
            committed = true
        if ls != 0 and not committed:
            var brake_d: float = speed * speed / 8.0
            if ls == 2 or brake_d < ahead - 1.0:
                room = maxf(ahead, 0.0)
            else:
                committed = true
    var obs: Vector3 = _scan(phys)
    var light_room: bool = room < 1000.0
    if obs.x < 1000.0:
        room = minf(room, obs.x - (2.0 if panic else 3.0))
    var cr: float = 29.0 if panic else cruise
    var allow: float = cr
    if room < 1000.0:
        allow = minf(cr, sqrt(maxf(0.0, 2.0 * 4.5 * maxf(0.0, room))))
        if room <= 0.3:
            allow = 0.0
    if state == 1:
        allow = minf(allow, (9.0 if panic else 7.5) if path.size() > 3 else cr)
    if maneuver == 2:
        allow = minf(allow, 5.0)

    # --- ожидание, сигнал, объезд
    var blocked_now: bool = obs.x < 7.0 and obs.y > 0.0 and absf(speed) < 0.5
    if blocked_now:
        stopped_t += dt
        if obs.y == 1.0:
            if stopped_t > 1.4 and honk_cd <= 0.0 and honk_n < 3:
                veh.honk()
                honk_cd = 2.6
                honk_n += 1
        elif obs.y == 2.0:
            blocked_t += dt
            if blocked_t > 3.0 and honk_cd <= 0.0 and honk_n < 3:
                veh.honk()
                honk_cd = 3.0
                honk_n += 1
            if blocked_t > 8.0 and not phys:
                ghost_t = 4.0
                blocked_t = 0.0
        if maneuver == 0 and not light_room:
            if (obs.y == 1.0 and stopped_t > 3.5) or (obs.y == 2.0 and stopped_t > 6.0) or (obs.y == 3.0 and stopped_t > 2.5):
                avoid_target = _pick_side(obs)
                if phys and _rear_clear():
                    maneuver = 1
                    man_t = 1.4
                else:
                    maneuver = 2
                    man_t = 7.0
    elif absf(speed) > 0.6:
        stopped_t = 0.0
        if absf(speed) > 2.0:
            honk_n = 0
        blocked_t = maxf(0.0, blocked_t - dt)
    if maneuver == 1:
        man_t -= dt
        if man_t <= 0.0 or not _rear_clear():
            maneuver = 2
            man_t = 7.0
    elif maneuver == 2:
        man_t -= dt
        if obs.x >= 1000.0:
            calm_t += dt
        else:
            calm_t = 0.0
        if man_t <= 0.0 or calm_t > 1.6:
            maneuver = 0
            avoid_target = 0.0
            stopped_t = 0.0
            calm_t = 0.0

    if phys:
        if state == 0:
            var lane_c: float = _lane(axis, d, Const.node_pos(j, k))
            var cur_lat: float = pos.z if axis == 0 else pos.x
            if absf(cur_lat - lane_c) > 5.0:
                lost_t += dt
            else:
                lost_t = maxf(0.0, lost_t - dt)
        # застряли без видимой причины — подаём назад
        if absf(speed) < 0.3 and allow > 1.0 and obs.x > 8.0 and maneuver == 0:
            stuck_t += dt
            if stuck_t > 4.0:
                stuck_t = 0.0
                maneuver = 1
                man_t = 1.5
                avoid_target = 0.0
        else:
            stuck_t = 0.0
        if state == 0 and final_leg:
            var go: bool = Game.light_state(axis) == 0 or committed or panic
            if go and ahead < 5.0 + maxf(speed, 0.0) * 0.6 and (obs.x > 5.0 or obs.y == 0.0):
                _plan_cross()
        elif dist < 3.2:
            pi += 1
            if pi >= path.size():
                _finish_cross()
        _control(dt, allow)
        return

    # --- лёгкий режим (вдали от игрока)
    var acc: float = (4.5 if panic else 3.0) if allow > speed else 8.0
    speed = move_toward(speed, allow, acc * dt)
    if state == 0 and final_leg and dist < 0.7:
        var ls3: int = Game.light_state(axis)
        if ls3 == 0 or committed or panic:
            _plan_cross()
            _apply(dt)
            return
        speed = 0.0
        _apply(dt)
        return
    var step: float = speed * dt
    if dist <= step + 0.02:
        pos = target
        if not (state == 0 and final_leg):
            pi += 1
            if pi >= path.size():
                _finish_cross()
    elif dist > 0.001:
        pos += to / dist * step
    if maneuver == 2 and state == 0:
        avoid = lerpf(avoid, avoid_target, minf(1.0, dt * 1.5))
    else:
        avoid = lerpf(avoid, 0.0, minf(1.0, dt * 1.5))
    _apply(dt)


# Руль и педали для физической машины.
func _control(dt: float, allow: float) -> void:
    if maneuver == 1:
        veh.in_throttle = -0.55
        veh.in_brake = 0.0
        veh.in_steer = 0.0
        return
    avoid = lerpf(avoid, avoid_target, minf(1.0, dt * 1.2))
    var look_d: float = clampf(maxf(speed, 0.0) * 0.7 + 3.5, 4.5, 16.0)
    if state == 1:
        look_d = clampf(maxf(speed, 0.0) * 0.35 + 2.5, 3.0, 6.5)
    var look: Vector3 = _lookahead(look_d)
    var sd: Vector3 = _seg_dir()
    look += Vector3(-sd.z, 0.0, sd.x) * avoid
    var fwd_v: Vector3 = Vector3(-sin(yaw), 0.0, -cos(yaw))
    var to: Vector3 = look - pos
    to.y = 0.0
    var ld: float = maxf(to.length(), 2.0)
    var alpha: float = fwd_v.signed_angle_to(to.normalized(), Vector3.UP)
    var wb: float = float(veh.def["wheelbase"])
    var delta: float = atan2(2.0 * wb * sin(alpha), ld)
    var vmax: float = float(veh.def["vmax"])
    var max_steer: float = float(veh.def["steer"]) * lerpf(1.0, 0.25, clampf(maxf(speed, 0.0) / vmax * 1.6, 0.0, 1.0))
    veh.in_steer = clampf(-delta / max_steer, -1.0, 1.0)
    var acc_lim: float = 4.5 if panic else 1.8
    var a_des: float = clampf((allow - speed) * 1.2, -8.0, acc_lim)
    if a_des >= 0.0:
        veh.in_throttle = clampf(a_des / 3.5, 0.0, 1.0)
        veh.in_brake = 0.0
    else:
        veh.in_throttle = 0.0
        veh.in_brake = clampf(-a_des / 7.0, 0.0, 1.0)
    if allow < 0.2 and speed < 1.2:
        veh.in_throttle = 0.0
        veh.in_brake = 1.0


func _apply(dt: float) -> void:
    if veh.mode != Vehicle.Mode.AI_LANE:
        return
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
    var right: Vector3 = Vector3(cos(yaw), 0.0, -sin(yaw))
    var p: Vector3 = pos + right * avoid
    p.y = veh.wheel_r + 0.04
    veh.global_transform = Transform3D(Basis(Vector3.UP, yaw), p)
    veh.speed_ms = speed
