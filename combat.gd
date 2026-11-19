class_name Combat
extends RefCounted
# Стрельба, ближний бой, взрывы.


static func fire_gun(shooter: Node3D, origin: Vector3, dir: Vector3, wd: Dictionary, exclude: Array[RID]) -> void:
    var space: PhysicsDirectSpaceState3D = shooter.get_world_3d().direct_space_state
    var pellets: int = int(wd.get("pellets", 1))
    var spread: float = deg_to_rad(float(wd.get("spread", 0.0)))
    var reach: float = float(wd.get("range", 100.0))
    var basis: Basis = Basis.looking_at(dir.normalized(), Vector3.UP)
    for i in pellets:
        var a: float = randf() * TAU
        var r: float = sqrt(randf()) * spread
        var d: Vector3 = (basis * Vector3(sin(r) * cos(a), sin(r) * sin(a), -cos(r))).normalized()
        var q := PhysicsRayQueryParameters3D.create(origin, origin + d * reach, Const.L_WORLD | Const.L_VEH | Const.L_HIT)
        q.collide_with_areas = true
        q.exclude = exclude
        var hit: Dictionary = space.intersect_ray(q)
        if hit.is_empty():
            continue
        _apply_hit(shooter, hit, d, float(wd["damage"]))
    Game.gunshot.emit(origin, float(wd.get("loud", 100.0)))


static func _apply_hit(shooter: Node3D, hit: Dictionary, d: Vector3, dmg: float) -> void:
    var col: Object = hit["collider"]
    var pos: Vector3 = hit["position"]
    var nrm: Vector3 = hit["normal"]
    if col is HitBox:
        var hb: HitBox = col
        if hb.character != null and is_instance_valid(hb.character) and hb.character.has_method("take_hit"):
            hb.character.call("take_hit", hb.part, dmg, d, shooter)
        Effects.blood(pos, nrm)
    elif col is Vehicle:
        var v: Vehicle = col
        v.shot(pos, d, dmg)
        Effects.sparks(pos, nrm)
    else:
        Effects.sparks(pos, nrm)


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
