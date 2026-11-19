class_name NPC
extends CharacterBody3D
# Пешеход / водитель. Реалистичные реакции: убегает от выстрелов, хромает и держится за рану,
# дерётся, мстит за угнанную машину, может сесть за руль и быстро уехать.

enum S { WALK, WAIT, CROSSING, FLEE, HURT, FIGHT, DEAD, DRIVER, CHASE, BUSY }

var state: int = S.WALK
var hp: float = 100.0
var rig: Humanoid
var cs: CollisionShape3D
var net: PedNet = null
var cur: int = 0
var nxt: int = -1
var prev: int = -1
var target: Vector3 = Vector3.ZERO
var has_target: bool = false
var queue: Array = []
var reset_after_queue: bool = false
var walk_speed: float = 1.5
var speed_mul: float = 1.0
var state_t: float = 0.0
var wound_t: float = 0.0
var threat: Vector3 = Vector3.ZERO
var punch_cd: float = 0.0
var yaw: float = 0.0
var vehicle: Vehicle = null
var chase_veh: Vehicle = null
var wait_axis: int = -1
var lat: float = 0.0
var panic_scream_cd: float = 0.0


static func create() -> NPC:
    var n := NPC.new()
    n.collision_layer = Const.L_CHAR
    n.collision_mask = Const.L_WORLD
    n.floor_snap_length = 0.4
    n.floor_max_angle = deg_to_rad(60.0)
    var cs := CollisionShape3D.new()
    var cap := CapsuleShape3D.new()
    cap.radius = 0.3
    cap.height = 1.75
    cs.shape = cap
    cs.position = Vector3(0, 0.875, 0)
    n.cs = cs
    n.add_child(cs)
    var rig := Humanoid.new()
    rig.owner_char = n
    rig.with_hitboxes = true
    var skins: Array = [Color(0.93, 0.76, 0.62), Color(0.85, 0.65, 0.5), Color(0.66, 0.46, 0.33), Color(0.45, 0.3, 0.2), Color(0.95, 0.8, 0.7)]
    rig.skin = skins[randi() % skins.size()]
    rig.shirt = Color.from_hsv(randf(), randf_range(0.25, 0.8), randf_range(0.35, 0.9))
    rig.pants = Color.from_hsv(randf(), randf_range(0.0, 0.4), randf_range(0.12, 0.45))
    rig.hair = Color.from_hsv(randf_range(0.04, 0.12), randf_range(0.2, 0.8), randf_range(0.06, 0.5))
    rig.build()
    var sc: float = randf_range(0.93, 1.07)
    rig.scale = Vector3(sc, sc, sc)
    n.rig = rig
    n.add_child(rig)
    n.walk_speed = randf_range(1.2, 1.8)
    n.lat = randf_range(-0.9, 0.9)
    n.add_to_group("npcs")
    n.add_to_group("walkers")
    n.add_to_group("peds")
    return n


func _ready() -> void:
    Game.gunshot.connect(_on_gunshot)


func start_on_edge(a: int, b: int, t: float) -> void:
    net = Game.ped_net
    cur = a
    var pa: Vector3 = net.pts[a]
    var pb: Vector3 = net.pts[b]
    global_position = pa.lerp(pb, t) + Vector3(0, 0.06, 0)
    yaw = randf() * TAU
    nxt = b
    prev = a
    _prepare_edge()


# ---------- машина ----------

func enter_vehicle(v: Vehicle) -> void:
    state = S.DRIVER
    vehicle = v
    remove_from_group("walkers")
    remove_from_group("peds")
    collision_layer = 0
    collision_mask = 0
    cs.set_deferred("disabled", true)
    var p: Node = get_parent()
    if p != null:
        p.remove_child(self)
    v.add_child(self)
    position = v.seat_local - Vector3(0, 0.30, 0)
    rotation = Vector3.ZERO
    rig.rotation = Vector3.ZERO
    rig.scale = Vector3(0.93, 0.93, 0.93)
    rig.sitting = true
    rig.speed = 0.0
    velocity = Vector3.ZERO
    v.driver_npc = self
    set_physics_process(false)


func eject(pos: Vector3, yaw_: float = 0.0) -> void:
    var v: Vehicle = vehicle
    vehicle = null
    if v != null and v.driver_npc == self:
        v.driver_npc = null
    var p: Node = get_parent()
    if p != null:
        p.remove_child(self)
    Game.world.add_child(self)
    global_position = pos
    yaw = yaw_
    rig.rotation = Vector3(0, yaw, 0)
    rig.sitting = false
    rig.scale = Vector3.ONE
    collision_layer = Const.L_CHAR
    collision_mask = Const.L_WORLD
    cs.set_deferred("disabled", false)
    add_to_group("walkers")
    add_to_group("peds")
    set_physics_process(true)
    state = S.WALK
    has_target = false
    net = Game.ped_net
    cur = net.nearest(pos)
    prev = -1
    nxt = -1


func _side_pos(v: Vehicle) -> Vector3:
    return v.exit_position(-1.0)


func bail_out(v: Vehicle, scared: bool) -> void:
    if state == S.DRIVER and vehicle != null:
        v = vehicle
        v.detach_ai()
        var pos: Vector3 = _side_pos(v)
        eject(pos, v.global_rotation.y)
        if scared:
            _start_flee(v.global_position, 9.0)


func on_vehicle_shot(pos: Vector3) -> void:
    if state == S.DRIVER and vehicle != null:
        call_deferred("bail_out", vehicle, true)


func carjacked(v: Vehicle, from_pos: Vector3) -> void:
    # игрок выдернул водителя из машины
    v.detach_ai()
    var pos: Vector3 = _side_pos(v)
    eject(pos, v.global_rotation.y)
    rig.play("hit", 0.5)
    Sfx.play3d("scream", global_position, 0.0, randf_range(0.85, 1.2), 60.0)
    threat = from_pos
    var roll: float = randf()
    if roll < 0.4:
        _start_flee(from_pos, 9.0)
    elif roll < 0.75:
        state = S.CHASE
        chase_veh = v
        state_t = 20.0
    else:
        state = S.FIGHT


# ---------- урон ----------

func take_hit(part: String, dmg: float, dir: Vector3, shooter) -> void:
    if state == S.DEAD:
        return
    if state == S.DRIVER:
        call_deferred("_driver_hit", part, dmg, dir, shooter)
        return
    var mult: float = 1.0
    match part:
        "head":
            mult = 1.0
        "arm":
            mult = 0.6
        "leg":
            mult = 0.7
    if part == "head" and dmg >= 15.0:
        hp = 0.0
    else:
        hp -= dmg * mult
    if hp <= 0.0:
        die(dir)
        return
    Sfx.play3d("pain", global_position, 0.0, randf_range(0.85, 1.25), 50.0)
    rig.play("hit", 0.3)
    var sp: Vector3 = threat
    if shooter != null and is_instance_valid(shooter) and shooter is Node3D:
        sp = (shooter as Node3D).global_position
    threat = sp
    if dmg <= 12.0 and shooter == Game.player:
        # удар кулаком: дать сдачи или убежать
        if randf() < 0.5 and hp > 40.0:
            state = S.FIGHT
        else:
            _start_flee(sp, 8.0)
        return
    var w: String = "torso"
    if part == "leg":
        w = "leg"
    elif part == "arm":
        w = "arm"
    rig.wounded = w
    wound_t = 40.0
    state = S.HURT
    state_t = 14.0
    has_target = false
    queue.clear()
    reset_after_queue = false
    if net != null:
        cur = net.nearest(global_position)
        prev = -1
    panic_scream_cd = 0.0


func _driver_hit(part: String, dmg: float, dir: Vector3, shooter) -> void:
    if state != S.DRIVER or vehicle == null:
        return
    var v: Vehicle = vehicle
    v.detach_ai()
    eject(_side_pos(v), v.global_rotation.y)
    take_hit(part, dmg, dir, shooter)


func die(dir: Vector3) -> void:
    if state == S.DEAD:
        return
    state = S.DEAD
    remove_from_group("npcs")
    remove_from_group("walkers")
    remove_from_group("peds")
    rig.wounded = ""
    rig.die(dir)
    Sfx.play3d("pain", global_position, 3.0, 0.8, 60.0)
    collision_layer = 0
    cs.set_deferred("disabled", true)
    set_physics_process(false)
    await get_tree().create_timer(25.0).timeout
    if is_inside_tree():
        queue_free()


# ---------- поведение ----------

func _on_gunshot(pos: Vector3, loud: float) -> void:
    if state == S.DEAD or state == S.DRIVER or state == S.BUSY:
        return
    if state == S.FIGHT or state == S.CHASE:
        return
    var dist: float = global_position.distance_to(pos)
    if dist > loud * 0.55:
        return
    if state == S.FLEE:
        threat = pos
        return
    if randf() < 0.92:
        _start_flee(pos, randf_range(7.0, 11.0))


func _start_flee(from: Vector3, t: float) -> void:
    state = S.FLEE
    threat = from
    state_t = t
    has_target = false
    queue.clear()
    reset_after_queue = false
    if net != null:
        cur = net.nearest(global_position)
        prev = -1
    if panic_scream_cd <= 0.0 and randf() < 0.6:
        Sfx.play3d("scream", global_position, -2.0, randf_range(0.8, 1.3), 55.0)
        panic_scream_cd = 4.0


func _physics_process(delta: float) -> void:
    if state == S.DEAD or state == S.DRIVER or Game.player == null:
        return
    panic_scream_cd -= delta
    punch_cd -= delta
    if wound_t > 0.0:
        wound_t -= delta
        if wound_t <= 0.0:
            rig.wounded = ""
    match state:
        S.WALK, S.CROSSING:
            _walk(delta)
        S.WAIT:
            _wait(delta)
        S.FLEE:
            _flee(delta, 5.3, false)
        S.HURT:
            _flee(delta, 1.0, true)
        S.FIGHT:
            _fight(delta)
        S.CHASE:
            _chase(delta)
        S.BUSY:
            _go(global_position, 0.0, delta)


func _go(tgt: Vector3, spd: float, delta: float) -> void:
    var to: Vector3 = tgt - global_position
    to.y = 0.0
    var dist: float = to.length()
    var dir: Vector3 = to / dist if dist > 0.01 else Vector3.ZERO
    velocity.x = move_toward(velocity.x, dir.x * spd, 14.0 * delta)
    velocity.z = move_toward(velocity.z, dir.z * spd, 14.0 * delta)
    if is_on_floor():
        velocity.y = -0.5
    else:
        velocity.y -= 18.0 * delta
    move_and_slide()
    var hs: float = Vector2(velocity.x, velocity.z).length()
    rig.speed = hs
    rig.run_amt = clampf((hs - 3.0) / 3.0, 0.0, 1.0)
    if hs > 0.3:
        yaw = lerp_angle(yaw, atan2(-velocity.x, -velocity.z), minf(1.0, delta * 9.0))
    rig.rotation.y = yaw


func _face(p: Vector3, delta: float) -> void:
    var to: Vector3 = p - global_position
    yaw = lerp_angle(yaw, atan2(-to.x, -to.z), minf(1.0, delta * 10.0))
    rig.rotation.y = yaw


func _flat_dist(p: Vector3) -> float:
    return Vector2(p.x - global_position.x, p.z - global_position.z).length()


# --- прогулка по графу тротуаров ---

func _choose_next() -> void:
    var opts: Array = net.adj[cur]
    var cand: Array = []
    for o in opts:
        if o != prev:
            cand.append(o)
    if cand.is_empty():
        cand = opts.duplicate()
    if cand.is_empty():
        cur = net.nearest(global_position)
        return
    nxt = cand[randi() % cand.size()]
    _prepare_edge()


func _prepare_edge() -> void:
    var ax: int = net.edge_cross(cur, nxt)
    var pa: Vector3 = net.pts[cur]
    var pb: Vector3 = net.pts[nxt]
    if ax >= 0:
        wait_axis = ax
        state = S.WAIT
        has_target = false
        return
    state = S.WALK
    # случайный переход дороги в неположенном месте
    if randf() < 0.06 and pa.distance_to(pb) > 50.0:
        var key: String = "%d_%d" % [cur, nxt]
        var c: float = net.center_lat[key]
        var t: float = randf_range(0.3, 0.7)
        var m: Vector3 = pa.lerp(pb, t)
        var o: Vector3 = m
        if int(net.edge_dir_axis[key]) == 0:
            o.z = 2.0 * c - m.z
        else:
            o.x = 2.0 * c - m.x
        queue = [m, o]
        reset_after_queue = true
        target = queue.pop_front()
        has_target = true
        return
    var dirv: Vector3 = (pb - pa).normalized()
    var side: Vector3 = Vector3(-dirv.z, 0.0, dirv.x)
    target = pb + side * lat * 0.9
    has_target = true


func _arrive() -> void:
    if queue.size() > 0:
        target = queue.pop_front()
        state = S.CROSSING
        return
    if reset_after_queue:
        reset_after_queue = false
        cur = net.nearest(global_position)
        prev = -1
        _choose_next()
        return
    prev = cur
    cur = nxt
    _choose_next()


func _walk(delta: float) -> void:
    if not has_target:
        if nxt < 0:
            _choose_next()
        if not has_target:
            return
    var spd: float = walk_speed * speed_mul
    if state == S.CROSSING:
        spd = maxf(spd, 1.7)
    _go(target, spd, delta)
    if _flat_dist(target) < 0.55:
        _arrive()


func _wait(delta: float) -> void:
    _go(global_position, 0.0, delta)
    if Game.light_state(wait_axis) == 2:
        state = S.CROSSING
        target = net.pts[nxt]
        has_target = true


# --- бегство / ранение ---

func _flee(delta: float, spd: float, hurt: bool) -> void:
    state_t -= delta
    if state_t <= 0.0:
        state = S.WALK
        speed_mul = 0.65 if hurt else 1.0
        has_target = false
        cur = net.nearest(global_position)
        prev = -1
        nxt = -1
        return
    if not has_target or _flat_dist(target) < 0.6:
        var here: int = cur
        if has_target:
            prev = cur
            cur = nxt
            here = cur
        var best: int = -1
        var bd: float = -1.0
        for o in net.adj[here]:
            var dd: float = (net.pts[o] as Vector3).distance_to(threat)
            if o == prev and (net.adj[here] as Array).size() > 1:
                dd -= 30.0
            if dd > bd:
                bd = dd
                best = o
        if best < 0:
            has_target = false
            return
        nxt = best
        target = net.pts[best]
        has_target = true
    var s2: float = spd
    if hurt:
        s2 = 1.1 + 0.4 * sin(float(Time.get_ticks_msec()) * 0.004)
    _go(target, s2, delta)


# --- драка ---

func _fight(delta: float) -> void:
    var pl: Node3D = Game.player as Node3D
    if pl == null or Game.player.in_vehicle != null:
        _calm()
        return
    if hp < 30.0:
        _start_flee(pl.global_position, 8.0)
        return
    var dist: float = _flat_dist(pl.global_position)
    _face(pl.global_position, delta)
    if dist > 1.35:
        _go(pl.global_position, 3.3, delta)
    else:
        _go(global_position, 0.0, delta)
        if punch_cd <= 0.0:
            punch_cd = randf_range(0.9, 1.5)
            rig.play("punch", 0.35)
            Sfx.play3d("punch", global_position, 0.0, randf_range(0.9, 1.1), 30.0)
            Game.player.call("take_damage", 6.0, (pl.global_position - global_position).normalized())
    if dist > 18.0:
        _calm()


func _calm() -> void:
    state = S.WALK
    has_target = false
    cur = net.nearest(global_position)
    prev = -1
    nxt = -1


# --- погоня за угнанной машиной ---

func _chase(delta: float) -> void:
    var pl: Node3D = Game.player as Node3D
    if chase_veh == null or not is_instance_valid(chase_veh) or pl == null:
        _calm()
        return
    state_t -= delta
    if _flat_dist(pl.global_position) > 10.0 or state_t <= 0.0:
        _calm()
        return
    if not chase_veh.has_player:
        _calm()
        return
    var vp: Vector3 = chase_veh.global_position
    _face(vp, delta)
    _go(vp, 6.2, delta)
    if _flat_dist(vp) < chase_veh.width * 0.5 + 1.1 and absf(chase_veh.speed_ms) < 5.0:
        _pull_player_out()


func _pull_player_out() -> void:
    var v: Vehicle = chase_veh
    state = S.BUSY
    v.door_target = 1.0
    Sfx.play3d("door_open", v.global_position, 0.0, 1.0, 50.0)
    rig.play("punch", 0.4)
    await get_tree().create_timer(0.45).timeout
    if state == S.DEAD or Game.player == null or not is_instance_valid(v):
        return
    Game.player.call("get_pulled_out", self)
    await get_tree().create_timer(0.5).timeout
    if state == S.DEAD or not is_instance_valid(v):
        return
    if randf() < 0.5:
        # сам садится и быстро уезжает
        enter_vehicle(v)
        v.door_target = 1.0
        v.start_escape()
        await get_tree().create_timer(0.35).timeout
        if is_instance_valid(v):
            v.door_target = 0.0
            Sfx.play3d("door_close", v.global_position, 0.0, 1.0, 50.0)
    else:
        v.door_target = 0.0
        state = S.FIGHT
