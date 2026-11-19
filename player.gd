class_name Player
extends CharacterBody3D
# Игрок: вид от 1-го лица (по умолчанию) и от 3-го, оружие, посадка в машины.

const WALK: float = 3.6
const RUN: float = 6.6
const JUMP_V: float = 5.6
const GRAV: float = 16.0

var cam_yaw: float = 0.0
var cam_pitch: float = 0.0
var third: bool = false
var car_third: bool = true
var head: Node3D
var arm: SpringArm3D
var cam: Camera3D
var rig: Humanoid
var shape_node: CollisionShape3D
var vm: Node3D
var vm_r: Node3D
var vm_l: Node3D
var vm_muzzle: Node3D = null
var vm_r_base: Vector3 = Vector3.ZERO
var vm_l_base: Vector3 = Vector3.ZERO
var vm_r_rot: Vector3 = Vector3.ZERO
var cam_rig: Node3D
var car_arm: SpringArm3D
var car_cam: Camera3D
var car_yaw: float = 0.0
var car_pitch: float = 0.35
var car_idle: float = 0.0
var fp_off: float = 0.0
var fp_pitch: float = 0.0

var in_vehicle: Vehicle = null
var hp: float = 100.0
var dead: bool = false
var busy_t: float = 0.0
var fire_cd: float = 0.0
var reload_t: float = 0.0
var reload_dur: float = 1.0
var reloading: bool = false
var fire_prev: bool = false
var kick: float = 0.0
var anim_p: float = 1.0
var anim_dur: float = 0.4
var anim_kind: String = ""
var step_acc: float = 0.0
var bob_t: float = 0.0
var jump_req: bool = false
var last_fire_t: float = -10.0
var rig_yaw: float = 0.0
var spawn_pos: Vector3 = Vector3.ZERO
var target_pickup: Pickup = null
var target_vehicle: Vehicle = null
var _prev_vy: float = 0.0
var _was_floor: bool = true
var _auto_reload_t: float = -1.0


func _ready() -> void:
    collision_layer = Const.L_CHAR
    collision_mask = Const.L_WORLD | Const.L_VEH | Const.L_CHAR
    floor_snap_length = 0.35
    floor_max_angle = deg_to_rad(60.0)
    shape_node = CollisionShape3D.new()
    var cap := CapsuleShape3D.new()
    cap.radius = 0.34
    cap.height = 1.78
    shape_node.shape = cap
    shape_node.position = Vector3(0, 0.89, 0)
    add_child(shape_node)

    rig = Humanoid.new()
    rig.owner_char = self
    rig.shirt = Color(0.15, 0.35, 0.65)
    rig.build()
    add_child(rig)

    head = Node3D.new()
    head.position = Vector3(0, 1.62, 0)
    add_child(head)
    arm = SpringArm3D.new()
    arm.collision_mask = Const.L_WORLD | Const.L_VEH
    arm.margin = 0.15
    arm.spring_length = 0.0
    head.add_child(arm)
    cam = Camera3D.new()
    cam.near = 0.05
    cam.fov = Settings.fov
    arm.add_child(cam)
    Settings.register_camera(cam)

    cam_rig = Node3D.new()
    cam_rig.top_level = true
    add_child(cam_rig)
    car_arm = SpringArm3D.new()
    car_arm.collision_mask = Const.L_WORLD
    car_arm.margin = 0.2
    cam_rig.add_child(car_arm)
    car_cam = Camera3D.new()
    car_cam.near = 0.08
    car_arm.add_child(car_cam)
    Settings.register_camera(car_cam)

    vm = Node3D.new()
    cam.add_child(vm)
    vm_r = Node3D.new()
    vm.add_child(vm_r)
    vm_l = Node3D.new()
    vm.add_child(vm_l)

    add_to_group("walkers")
    Ctl.action.connect(_on_action)
    Game.equipped_changed.connect(_refresh_weapon)
    _refresh_weapon()
    _apply_view_mode()
    cam.current = true


# ---------- ввод ----------

func _on_action(a: String) -> void:
    if dead:
        return
    match a:
        "jump":
            if in_vehicle == null:
                jump_req = true
        "interact":
            interact()
        "reload":
            start_reload()
        "cam":
            if in_vehicle != null:
                car_third = not car_third
            else:
                third = not third
            _apply_view_mode()
        "drop":
            drop_weapon()
        "horn":
            if in_vehicle != null:
                in_vehicle.honk()


func _apply_view_mode() -> void:
    if in_vehicle != null:
        car_cam.current = true
        vm.visible = false
        return
    cam.current = true
    arm.spring_length = 3.2 if third else 0.0
    arm.position = Vector3.ZERO
    rig.visible = true
    rig.set_shadow_only(not third)
    vm.visible = (not third) and not dead


# ---------- кадр ----------

func _process(delta: float) -> void:
    var lk: Vector2 = Ctl.take_look()
    var sens: float = 0.0032 * Settings.sensitivity
    cam.fov = Settings.fov
    if in_vehicle != null:
        _car_camera(lk, sens, delta)
        return
    if not dead:
        cam_yaw -= lk.x * sens
        cam_pitch = clampf(cam_pitch - lk.y * sens, -1.4, 1.35)
    head.rotation = Vector3(cam_pitch, cam_yaw, 0.0)
    var hs: float = Vector2(velocity.x, velocity.z).length()
    bob_t += hs * delta * 1.9
    if not third and is_on_floor() and not dead:
        head.position.y = 1.62 + sin(bob_t * 2.0) * 0.03 * minf(hs / 4.0, 1.0)
    elif dead:
        head.position.y = lerpf(head.position.y, 0.35, minf(1.0, delta * 4.0))
    else:
        head.position.y = 1.62
    _animate_viewmodel(delta, hs)
    _update_rig(delta, hs)


func _update_rig(delta: float, hs: float) -> void:
    if dead:
        return
    var face: float = cam_yaw
    var recently: bool = float(Time.get_ticks_msec()) / 1000.0 - last_fire_t < 2.0
    if third and hs > 0.5 and not recently:
        face = atan2(-velocity.x, -velocity.z)
    rig_yaw = lerp_angle(rig_yaw, face, minf(1.0, delta * 10.0))
    rig.rotation.y = rig_yaw
    rig.speed = hs
    rig.run_amt = 1.0 if (Ctl.run and hs > 4.5) else 0.0
    rig.pitch_aim = cam_pitch * 0.7


func _car_camera(lk: Vector2, sens: float, delta: float) -> void:
    var v: Vehicle = in_vehicle
    if v == null:
        return
    if lk.length() > 0.5:
        car_idle = 0.0
    else:
        car_idle += delta
    var fwd: Vector3 = -v.global_transform.basis.z
    if car_third:
        car_yaw -= lk.x * sens
        car_pitch = clampf(car_pitch + lk.y * sens, -0.05, 1.2)
        if car_idle > 1.5 and absf(v.speed_ms) > 2.5:
            var want: float = atan2(-fwd.x, -fwd.z)
            if v.speed_ms < 0.0:
                want += PI
            car_yaw = lerp_angle(car_yaw, want, 1.0 - exp(-1.8 * delta))
        car_arm.spring_length = 4.6 + v.length * 0.55
        var base: Vector3 = v.global_position + Vector3(0, 1.3, 0)
        cam_rig.global_transform = Transform3D(Basis.from_euler(Vector3(-car_pitch, car_yaw, 0.0)), base)
    else:
        fp_off = clampf(fp_off - lk.x * sens, -2.1, 2.1)
        fp_pitch = clampf(fp_pitch - lk.y * sens, -0.8, 0.8)
        car_arm.spring_length = 0.0
        var hp_: Vector3 = v.seat_world() + v.global_transform.basis.y * 0.78
        cam_rig.global_transform = Transform3D(v.global_transform.basis * Basis.from_euler(Vector3(fp_pitch, fp_off, 0.0)), hp_)
    car_cam.fov = Settings.fov + clampf(absf(v.speed_ms) * 0.3, 0.0, 14.0)


func _physics_process(delta: float) -> void:
    fire_cd = maxf(0.0, fire_cd - delta)
    busy_t = maxf(0.0, busy_t - delta)
    if in_vehicle != null:
        var v: Vehicle = in_vehicle
        v.in_throttle = Ctl.gas - Ctl.rev
        v.in_steer = Ctl.steer
        v.in_hand = Ctl.handbrake
        v.in_brake = 0.0
        global_position = v.global_position
        if v.is_flipped():
            Game.prompt = "Поставить машину на колёса"
            Game.prompt_btn = "ПОСТАВИТЬ"
        else:
            Game.prompt = ""
            Game.prompt_btn = "ВЫЙТИ"
        return
    if dead:
        return
    _find_targets()
    _move(delta)
    _weapon_logic(delta)


func _move(delta: float) -> void:
    var inp: Vector2 = Ctl.move
    if busy_t > 0.0:
        inp = Vector2.ZERO
    var mag: float = minf(inp.length(), 1.0)
    var dir3: Vector3 = Vector3(inp.x, 0.0, inp.y).rotated(Vector3.UP, cam_yaw)
    var running: bool = Ctl.run and mag > 0.1
    var tgt: float = (RUN if running else WALK) * mag
    var hv: Vector2 = Vector2(velocity.x, velocity.z)
    var want: Vector2 = Vector2.ZERO
    if mag > 0.01:
        want = Vector2(dir3.x, dir3.z).normalized() * tgt
    var accel: float = 30.0 if is_on_floor() else 6.0
    hv = hv.move_toward(want, accel * delta)
    velocity.x = hv.x
    velocity.z = hv.y
    if is_on_floor():
        velocity.y = -0.5
        if jump_req and busy_t <= 0.0:
            velocity.y = JUMP_V
            Sfx.play3d("jump", global_position, -4.0, randf_range(0.95, 1.05), 30.0)
    else:
        velocity.y -= GRAV * delta
    jump_req = false
    _prev_vy = velocity.y
    move_and_slide()
    if is_on_floor() and not _was_floor and _prev_vy < -4.0:
        Sfx.play3d("land", global_position, -2.0, randf_range(0.9, 1.1), 40.0)
    _was_floor = is_on_floor()
    var hsp: float = hv.length()
    if is_on_floor() and hsp > 0.5:
        step_acc += hsp * delta
        if step_acc > (2.3 if running else 1.6):
            step_acc = 0.0
            Sfx.play3d("step", global_position, -7.0, randf_range(0.9, 1.1), 35.0)


# ---------- цели (оружие на земле, машины) ----------

func _find_targets() -> void:
    target_pickup = null
    target_vehicle = null
    Game.prompt = ""
    Game.prompt_btn = ""
    if busy_t > 0.0:
        return
    var from: Vector3 = cam.global_position
    var d: Vector3 = -cam.global_transform.basis.z
    var q := PhysicsRayQueryParameters3D.create(from, from + d * 3.4, Const.L_ITEM)
    var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
    if not hit.is_empty() and hit["collider"] is Pickup:
        target_pickup = hit["collider"]
        Game.prompt = "%s: подобрать" % target_pickup.display_name()
        Game.prompt_btn = "ВЗЯТЬ"
        return
    var best: float = 1000.0
    for n in get_tree().get_nodes_in_group("vehicles"):
        var v: Vehicle = n as Vehicle
        if v == null:
            continue
        var dd: float = Vector2(v.global_position.x - global_position.x, v.global_position.z - global_position.z).length()
        if dd < v.half_len + 1.2 and dd < best and absf(v.global_position.y - global_position.y) < 3.0:
            best = dd
            target_vehicle = v
    if target_vehicle != null:
        if target_vehicle.driver_npc != null:
            Game.prompt = "Угнать: %s" % target_vehicle.display_name()
            Game.prompt_btn = "УГНАТЬ"
        else:
            Game.prompt = "Сесть: %s" % target_vehicle.display_name()
            Game.prompt_btn = "СЕСТЬ"


func interact() -> void:
    if busy_t > 0.0 or dead:
        return
    if in_vehicle != null:
        if in_vehicle.is_flipped():
            in_vehicle.flip_upright()
        else:
            _exit_vehicle()
        return
    if target_pickup != null and is_instance_valid(target_pickup):
        target_pickup.collect()
        return
    if target_vehicle != null and is_instance_valid(target_vehicle):
        _enter_vehicle(target_vehicle)


# ---------- машина ----------

func _enter_vehicle(v: Vehicle) -> void:
    busy_t = 2.4
    Game.prompt = ""
    var npc = v.driver_npc
    if v.mode == Vehicle.Mode.AI_LANE:
        if v.ai != null:
            v.ai.cruise = 0.0
            v.ai.speed = 0.0
    else:
        v.wake()
    v.door_target = 1.0
    Sfx.play3d("door_open", v.global_position, 0.0, 1.0, 50.0)
    if npc != null and is_instance_valid(npc):
        await get_tree().create_timer(0.4).timeout
        if is_instance_valid(npc) and is_instance_valid(v) and v.driver_npc == npc:
            npc.carjacked(v, global_position)
            Sfx.play3d("punch", v.global_position, 0.0, 0.9, 40.0)
        await get_tree().create_timer(0.6).timeout
    else:
        await get_tree().create_timer(0.45).timeout
    if dead or not is_instance_valid(v):
        busy_t = 0.0
        return
    _set_in_vehicle(v)
    await get_tree().create_timer(0.35).timeout
    if is_instance_valid(v):
        v.door_target = 0.0
        Sfx.play3d("door_close", v.global_position, 0.0, 1.0, 50.0)
    busy_t = 0.0


func _set_in_vehicle(v: Vehicle) -> void:
    in_vehicle = v
    v.player_enter()
    remove_from_group("walkers")
    collision_layer = 0
    collision_mask = 0
    shape_node.disabled = true
    rig.visible = false
    var fwd: Vector3 = -v.global_transform.basis.z
    car_yaw = atan2(-fwd.x, -fwd.z)
    car_pitch = 0.3
    fp_off = 0.0
    fp_pitch = 0.0
    car_idle = 0.0
    reloading = false
    Game.prompt = ""
    _apply_view_mode()


func _leave_vehicle_to(pos: Vector3) -> void:
    var v: Vehicle = in_vehicle
    in_vehicle = null
    if v != null and is_instance_valid(v):
        v.player_exit()
        var fwd: Vector3 = -v.global_transform.basis.z
        cam_yaw = atan2(-fwd.x, -fwd.z)
    global_position = pos
    velocity = Vector3.ZERO
    collision_layer = Const.L_CHAR
    collision_mask = Const.L_WORLD | Const.L_VEH | Const.L_CHAR
    shape_node.disabled = false
    add_to_group("walkers")
    cam_pitch = 0.0
    _apply_view_mode()


func _exit_vehicle() -> void:
    var v: Vehicle = in_vehicle
    if v == null:
        return
    busy_t = 1.2
    v.door_target = 1.0
    Sfx.play3d("door_open", v.global_position, 0.0, 1.0, 50.0)
    await get_tree().create_timer(0.3).timeout
    if not is_instance_valid(v):
        in_vehicle = null
        busy_t = 0.0
        return
    _leave_vehicle_to(v.exit_position(-1.0))
    await get_tree().create_timer(0.5).timeout
    if is_instance_valid(v):
        v.door_target = 0.0
        Sfx.play3d("door_close", v.global_position, 0.0, 1.0, 50.0)
    busy_t = 0.0


func get_pulled_out(npc) -> void:
    # NPC вытащил игрока из машины
    if in_vehicle == null:
        return
    var v: Vehicle = in_vehicle
    _leave_vehicle_to(v.exit_position(-1.0))
    busy_t = 0.9
    take_damage(4.0, Vector3.ZERO)
    Game.say("Вас выдернули из машины!")


func spawn_vehicle(id: String) -> void:
    var fwd: Vector3 = Vector3(-sin(cam_yaw), 0.0, -cos(cam_yaw))
    var origin: Vector3 = global_position + Vector3(0, 1.0, 0)
    var p: Vector3 = global_position + fwd * 5.5
    var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
    var wq := PhysicsRayQueryParameters3D.create(origin, origin + fwd * 6.0, Const.L_WORLD)
    var wh: Dictionary = space.intersect_ray(wq)
    if not wh.is_empty():
        var hp_: Vector3 = wh["position"]
        p = hp_ - fwd * 2.6
        if p.distance_to(global_position) < 2.2:
            p = global_position + fwd * 2.2
    var gq := PhysicsRayQueryParameters3D.create(p + Vector3(0, 3.0, 0), p - Vector3(0, 6.0, 0), Const.L_WORLD)
    var gh: Dictionary = space.intersect_ray(gq)
    var gy: float = global_position.y
    if not gh.is_empty():
        var gp: Vector3 = gh["position"]
        gy = gp.y
    var def: Dictionary = VehicleDefs.get_def(id)
    var cols: Array = def["colors"]
    var v := Vehicle.new()
    v.setup(id, cols[randi() % cols.size()])
    Game.world.add_child(v)
    v.place(Vector3(p.x, gy + v.wheel_r + 0.03, p.z), cam_yaw)
    Sfx.play2d("click")
    Game.say("Машина: %s" % v.display_name())


# ---------- оружие ----------

func _weapon_logic(delta: float) -> void:
    if reloading:
        reload_t -= delta
        if reload_t <= 0.0:
            _finish_reload()
    if _auto_reload_t > 0.0:
        _auto_reload_t -= delta
        if _auto_reload_t <= 0.0:
            start_reload()
    var fire: bool = Ctl.fire and busy_t <= 0.0
    var wd: Dictionary = {}
    if Game.equipped != "":
        wd = WeaponDefs.get_def(Game.equipped)
    var kind: String = str(wd.get("kind", "fist"))
    var auto: bool = bool(wd.get("auto", false)) or kind == "fist"
    if fire and fire_cd <= 0.0 and not reloading:
        if auto or not fire_prev:
            match kind:
                "fist":
                    _punch()
                "melee":
                    _swing(wd)
                _:
                    _shoot(wd, kind)
    fire_prev = fire


func _start_anim(k: String, dur: float) -> void:
    anim_kind = k
    anim_dur = dur
    anim_p = 0.0


func _punch() -> void:
    fire_cd = 0.45
    _start_anim("punch", 0.35)
    rig.play("punch", 0.35)
    Sfx.play3d("swing", global_position, -8.0, 1.2, 25.0)
    await get_tree().create_timer(0.12).timeout
    if dead or in_vehicle != null or not is_inside_tree():
        return
    var fwd: Vector3 = -cam.global_transform.basis.z
    if Combat.melee_hit(self, head.global_position, fwd, 1.7, 8.0):
        Sfx.play3d("punch", global_position + fwd, 0.0, randf_range(0.9, 1.1), 30.0)


func _swing(wd: Dictionary) -> void:
    fire_cd = 1.0 / float(wd["rate"])
    _start_anim("swing", 0.45)
    rig.play("swing", 0.45)
    Sfx.play3d("swing", global_position, -2.0, 1.0, 30.0)
    await get_tree().create_timer(0.2).timeout
    if dead or in_vehicle != null or not is_inside_tree():
        return
    var fwd: Vector3 = -cam.global_transform.basis.z
    if Combat.melee_hit(self, head.global_position, fwd, float(wd["range"]), float(wd["damage"])):
        Sfx.play3d(str(wd["snd"]), global_position + fwd, 2.0, randf_range(0.9, 1.1), 40.0)


func _shoot(wd: Dictionary, kind: String) -> void:
    var id: String = Game.equipped
    var st: Dictionary = Game.owned[id]
    if int(st["mag"]) <= 0:
        fire_cd = 0.3
        Sfx.play2d("empty", -4.0)
        if int(st["reserve"]) > 0:
            start_reload()
        return
    st["mag"] = int(st["mag"]) - 1
    fire_cd = 1.0 / float(wd["rate"])
    last_fire_t = float(Time.get_ticks_msec()) / 1000.0
    var origin: Vector3 = cam.global_position
    var dir: Vector3 = -cam.global_transform.basis.z
    if kind == "rocket":
        Rocket.launch(head.global_position + dir * 1.1, dir, self)
        Game.gunshot.emit(origin, float(wd["loud"]))
    else:
        var ex: Array[RID] = []
        Combat.fire_gun(self, origin, dir, wd, ex)
    Sfx.play3d(str(wd["snd"]), origin, 0.0, randf_range(0.97, 1.03), 230.0)
    kick = 1.0
    var rc: float = deg_to_rad(float(wd["recoil"]))
    cam_pitch = minf(cam_pitch + rc * 0.4 * randf_range(0.7, 1.2), 1.35)
    cam_yaw += randf_range(-0.3, 0.3) * rc * 0.3
    rig.play("recoil", 0.15)
    if not third and vm_muzzle != null and is_instance_valid(vm_muzzle):
        Effects.muzzle_flash(vm_muzzle)
    else:
        var m: Node3D = rig.weapon_muzzle()
        if m != null:
            Effects.muzzle_flash(m)
    if id == "mossberg":
        var t: SceneTreeTimer = get_tree().create_timer(0.45)
        t.timeout.connect(func() -> void: Sfx.play2d("pump", -4.0))
    if int(st["mag"]) == 0 and int(st["reserve"]) > 0:
        _auto_reload_t = 0.5


func start_reload() -> void:
    var id: String = Game.equipped
    if id == "" or reloading or dead or in_vehicle != null:
        return
    var wd: Dictionary = WeaponDefs.get_def(id)
    var kind: String = str(wd.get("kind", ""))
    if kind != "gun" and kind != "rocket":
        return
    var st: Dictionary = Game.owned[id]
    if int(st["mag"]) >= int(wd["mag"]) or int(st["reserve"]) <= 0:
        return
    reloading = true
    reload_dur = float(wd["reload"])
    reload_t = reload_dur
    Sfx.play2d("reload", -2.0)
    rig.play("reload", reload_dur)


func _finish_reload() -> void:
    reloading = false
    var id: String = Game.equipped
    if id == "" or not Game.owned.has(id):
        return
    var wd: Dictionary = WeaponDefs.get_def(id)
    var st: Dictionary = Game.owned[id]
    var take: int = mini(int(wd["mag"]) - int(st["mag"]), int(st["reserve"]))
    st["mag"] = int(st["mag"]) + take
    st["reserve"] = int(st["reserve"]) - take


func drop_weapon() -> void:
    var id: String = Game.equipped
    if id == "" or busy_t > 0.0 or in_vehicle != null:
        return
    busy_t = 0.5
    reloading = false
    rig.play("throw", 0.5)
    _start_anim("throw", 0.5)
    await get_tree().create_timer(0.25).timeout
    if dead or not Game.owned.has(id):
        return
    var data: Dictionary = Game.remove_weapon(id)
    var fwd: Vector3 = -cam.global_transform.basis.z
    Pickup.spawn(head.global_position + fwd * 0.7 + Vector3(0, -0.3, 0), id, int(data.get("mag", 0)), int(data.get("reserve", 0)), fwd * 4.0 + Vector3(0, 2.0, 0))
    Sfx.play3d("click", global_position, 0.0, 0.7, 20.0)


# ---------- урон ----------

func take_damage(dmg: float, _dir: Vector3) -> void:
    if dead:
        return
    hp -= dmg
    if Game.hud != null:
        Game.hud.call("flash")
    Sfx.play3d("pain", global_position, 0.0, 0.8, 30.0)
    if hp <= 0.0:
        _die()


func _die() -> void:
    dead = true
    Game.say("Вы погибли")
    Ctl.t_fire = false
    if in_vehicle != null:
        var v: Vehicle = in_vehicle
        _leave_vehicle_to(v.exit_position(-1.0))
    vm.visible = false
    reloading = false
    await get_tree().create_timer(3.2).timeout
    if not is_inside_tree():
        return
    hp = 100.0
    dead = false
    global_position = spawn_pos
    velocity = Vector3.ZERO
    head.position.y = 1.62
    _apply_view_mode()
    Game.say("Вы возродились")


# ---------- вид от первого лица: руки и оружие ----------

func _vm_limb(parent: Node3D, from: Vector3, to: Vector3, r: float, col: Color) -> void:
    var mi := MeshInstance3D.new()
    var cm := CapsuleMesh.new()
    cm.radius = r
    cm.height = from.distance_to(to) + r * 2.0
    cm.radial_segments = 8
    cm.rings = 3
    mi.mesh = cm
    mi.material_override = WeaponModel.mat(col, 0.0, 0.8)
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    mi.position = (from + to) * 0.5
    mi.quaternion = Quaternion(Vector3.UP, (to - from).normalized())
    parent.add_child(mi)


func _vm_hand(parent: Node3D, col: Color) -> void:
    var mi := MeshInstance3D.new()
    var sm := SphereMesh.new()
    sm.radius = 0.055
    sm.height = 0.11
    sm.radial_segments = 8
    sm.rings = 4
    mi.mesh = sm
    mi.material_override = WeaponModel.mat(col, 0.0, 0.8)
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mi)


func _refresh_weapon() -> void:
    reloading = false
    _auto_reload_t = -1.0
    var id: String = Game.equipped
    if rig != null:
        rig.set_weapon(id)
        rig.set_shadow_only(not third)
    for c in vm_r.get_children():
        c.queue_free()
    for c in vm_l.get_children():
        c.queue_free()
    vm_muzzle = null
    var skin: Color = rig.skin
    var sleeve: Color = rig.shirt
    vm_r_rot = Vector3.ZERO
    var two: bool = false
    var left_off: Vector3 = Vector3.ZERO
    if id == "":
        vm_r_base = Vector3(0.2, -0.26, -0.45)
        vm_l_base = Vector3(-0.2, -0.26, -0.45)
        two = true
    else:
        var wd: Dictionary = WeaponDefs.get_def(id)
        var w: Node3D = WeaponModel.build(id)
        vm_r.add_child(w)
        WeaponModel.set_shadow_mode(w, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
        vm_muzzle = w.find_child("Muzzle", true, false) as Node3D
        match id:
            "deagle":
                vm_r_base = Vector3(0.17, -0.19, -0.42)
            "ak47":
                vm_r_base = Vector3(0.16, -0.21, -0.38)
                left_off = Vector3(-0.15, 0.0, -0.33)
                two = true
            "mossberg":
                vm_r_base = Vector3(0.16, -0.21, -0.38)
                left_off = Vector3(-0.14, -0.02, -0.34)
                two = true
            "rpg":
                vm_r_base = Vector3(0.2, -0.27, -0.3)
                left_off = Vector3(-0.28, 0.05, -0.3)
                two = true
            "bat":
                vm_r_base = Vector3(0.24, -0.22, -0.4)
                w.rotation = Vector3(0.8, 0.0, -0.1)
                vm_r_rot = Vector3.ZERO
            _:
                vm_r_base = Vector3(0.17, -0.2, -0.4)
        vm_l_base = vm_r_base + left_off
        if int(wd.get("hold", 0)) != 2:
            two = false
    _vm_limb(vm_r, Vector3(0.12, -0.3, 0.5), Vector3.ZERO, 0.05, sleeve)
    _vm_hand(vm_r, skin)
    vm_l.visible = two
    if two:
        _vm_limb(vm_l, Vector3(-0.12, -0.3, 0.5), Vector3.ZERO, 0.05, sleeve)
        _vm_hand(vm_l, skin)
    vm_r.position = vm_r_base
    vm_l.position = vm_l_base


func _animate_viewmodel(delta: float, hs: float) -> void:
    kick = move_toward(kick, 0.0, delta * 8.0)
    if anim_p < 1.0:
        anim_p = minf(1.0, anim_p + delta / maxf(anim_dur, 0.05))
    var ph: float = sin(anim_p * PI) if anim_p < 1.0 else 0.0
    var pos_r: Vector3 = vm_r_base + Vector3(0.0, 0.0, kick * 0.07)
    var rot_r: Vector3 = vm_r_rot + Vector3(kick * 0.15, 0.0, 0.0)
    var pos_l: Vector3 = vm_l_base + Vector3(0.0, 0.0, kick * 0.05)
    match anim_kind:
        "punch":
            pos_r += Vector3(0.0, 0.05 * ph, -0.4 * ph)
        "swing":
            rot_r += Vector3(-1.3 * ph, 0.0, 0.6 * ph)
        "throw":
            pos_r += Vector3(0.0, 0.1 * ph, -0.3 * ph)
    vm_r.position = pos_r
    vm_r.rotation = rot_r
    vm_l.position = pos_l
    var dip: float = 0.0
    if reloading:
        dip = -sin((1.0 - reload_t / maxf(reload_dur, 0.1)) * PI) * 0.22
    var sway: float = minf(hs / 4.0, 1.0)
    vm.position = Vector3(sin(bob_t) * 0.006 * sway, dip + absf(sin(bob_t)) * 0.005 * sway, 0.0)
