class_name Combat
extends RefCounted
# Стрельба, ближний бой, взрывы.


static func _ray_cyl(from: Vector3, dir: Vector3, max_len: float, base: Vector3, r: float, y0: float, y1: float) -> float:
    var ox: float = from.x - base.x
    var oz: float = from.z - base.z
    var a: float = dir.x * dir.x + dir.z * dir.z
    if a < 0.00001:
        return -1.0
    var b: float = 2.0 * (ox * dir.x + oz * dir.z)
    var c: float = ox * ox + oz * oz - r * r
    var disc: float = b * b - 4.0 * a * c
    if disc < 0.0:
        return -1.0
    var sq: float = sqrt(disc)
    var t1: float = (-b - sq) / (2.0 * a)
    var t2: float = (-b + sq) / (2.0 * a)
    for t in [t1, t2]:
        var tt: float = t
        if tt >= 0.0 and tt <= max_len:
            var y: float = from.y + dir.y * tt - base.y
            if y >= y0 and y <= y1:
                return tt
    return -1.0


static func _part_at(rel_y: float, radial: float) -> String:
    if rel_y > 1.52:
        return "head"
    if rel_y < 0.85:
        return "leg"
    if radial > 0.25 and rel_y > 0.95:
        return "arm"
    return "torso"


# Луч против людей (вертикальные цилиндры). Возвращает {"npc", "pos", "part", "t"} или {}.
static func ray_npc(from: Vector3, to: Vector3) -> Dictionary:
    var best: Dictionary = {}
    var d: Vector3 = to - from
    var seg: float = d.length()
    if seg < 0.001:
        return best
    var dir: Vector3 = d / seg
    for n in Game.get_tree().get_nodes_in_group("npcs"):
        var npc: Node3D = n as Node3D
        if npc == null:
            continue
        var base: Vector3 = npc.global_position
        var mid: Vector3 = base + Vector3(0, 0.9, 0)
        var proj: float = (mid - from).dot(dir)
        if proj < -1.0 or proj > seg + 1.0:
            continue
        var closest: Vector3 = from + dir * clampf(proj, 0.0, seg)
        if closest.distance_to(mid) > 1.3:
            continue
        var t: float = _ray_cyl(from, dir, seg, base, 0.32, 0.0, 1.82)
        if t < 0.0:
            continue
        if best.is_empty() or t < float(best["t"]):
            var p: Vector3 = from + dir * t
            best = {"npc": npc, "pos": p, "t": t, "part": _part_at(p.y - base.y, Vector2(p.x - base.x, p.z - base.z).length())}
    return best


static func fire_gun(shooter: Node3D, origin: Vector3, dir: Vector3, wd: Dictionary, exclude: Array[RID]) -> void:
    var space: PhysicsDirectSpaceState3D = shooter.get_world_3d().direct_space_state
    var pellets: int = int(wd.get("pellets", 1))
    var spread: float = deg_to_rad(float(wd.get("spread", 0.0)))
    var reach: float = float(wd.get("range", 100.0))
    var dmg: float = float(wd["damage"])
    var basis: Basis = Basis.looking_at(dir.normalized(), Vector3.UP)
    for i in pellets:
        var a: float = randf() * TAU
        var r: float = sqrt(randf()) * spread
        var d: Vector3 = (basis * Vector3(sin(r) * cos(a), sin(r) * sin(a), -cos(r))).normalized()
        var end: Vector3 = origin + d * reach
        var q := PhysicsRayQueryParameters3D.create(origin, end, Const.L_WORLD | Const.L_VEH)
        q.exclude = exclude
        var hit: Dictionary = space.intersect_ray(q)
        var world_end: Vector3 = end
        if not hit.is_empty():
            world_end = hit["position"]
        var nh: Dictionary = ray_npc(origin, world_end)
        if not nh.is_empty():
            var npc: Node3D = nh["npc"]
            npc.call("take_hit", str(nh["part"]), dmg, d, shooter)
            Effects.blood(nh["pos"], -d)
        elif not hit.is_empty():
            var col: Object = hit["collider"]
            var pos: Vector3 = hit["position"]
            var nrm: Vector3 = hit["normal"]
            if col is Vehicle:
                (col as Vehicle).shot(pos, d, dmg)
            Effects.sparks(pos, nrm)
    Game.gunshot.emit(origin, float(wd.get("loud", 100.0)))


static func melee_hit(attacker: Node3D, origin: Vector3, fwd: Vector3, reach: float, dmg: float) -> bool:
    var any: bool = false
    for n in attacker.get_tree().get_nodes_in_group("npcs"):
        if n == attacker:
            continue
        var npc: Node3D = n as Node3D
        if npc == null:
            continue
        var to: Vector3 = npc.global_position + Vector3(0, 1.0, 0) - origin
        var dist: float = to.length()
        if dist > reach + 0.35:
            continue
        if dist > 0.4 and to.normalized().dot(fwd.normalized()) < 0.4:
            continue
        npc.call("take_hit", "torso", dmg, fwd, attacker)
        Effects.blood(npc.global_position + Vector3(0, 1.2, 0), -fwd)
        any = true
    return any


static func explode(pos: Vector3, radius: float, dmg: float, attacker) -> void:
    if Game.world == null:
        return
    Effects.explosion(pos)
    Sfx.play3d("explosion", pos, 6.0, 1.0, 260.0)
    Game.gunshot.emit(pos, 220.0)
    var tree: SceneTree = Game.get_tree()
    for n in tree.get_nodes_in_group("npcs"):
        var npc: Node3D = n as Node3D
        if npc == null:
            continue
        var dist: float = npc.global_position.distance_to(pos)
        if dist < radius:
            var f: float = 1.0 - dist / radius
            var dir: Vector3 = (npc.global_position - pos).normalized()
            npc.call("take_hit", "torso", dmg * f * 1.5, dir, attacker)
    var pl = Game.player
    if pl != null and is_instance_valid(pl):
        var pd: float = (pl as Node3D).global_position.distance_to(pos)
        if pd < radius:
            pl.call("take_damage", dmg * (1.0 - pd / radius) * 0.6, (pl as Node3D).global_position - pos)
    for n in tree.get_nodes_in_group("vehicles"):
        var v: Vehicle = n as Vehicle
        if v == null:
            continue
        var dv: float = v.global_position.distance_to(pos)
        if dv < radius * 1.6:
            var f2: float = 1.0 - dv / (radius * 1.6)
            v.explosion_push((v.global_position - pos).normalized() + Vector3(0, 0.6, 0), f2)
    for n in tree.get_nodes_in_group("pickups"):
        var rb: RigidBody3D = n as RigidBody3D
        if rb != null and rb.global_position.distance_to(pos) < radius:
            rb.apply_central_impulse((rb.global_position - pos).normalized() * 6.0 + Vector3(0, 3, 0))
