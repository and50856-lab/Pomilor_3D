class_name TrafficManager
extends Node
# Трафик вокруг игрока: машины всегда появляются впереди и по бокам (даже когда игрок едет),
# далёкие исчезают. Ближние машины переключаются на настоящую физику.

var cars: Array = []
var veh_cache: Array = []
var target_count: int = 10
var _t: float = 0.0
var _sw_t: float = 0.0
var _spawn_t: float = 0.0


func _ready() -> void:
    Game.gunshot.connect(_on_gunshot)


func _on_gunshot(pos: Vector3, loud: float) -> void:
    for c in cars:
        if not is_instance_valid(c):
            continue
        var v: Vehicle = c as Vehicle
        if v == null or v.ai == null:
            continue
        if v.global_position.distance_to(pos) < loud * 0.35:
            v.panic()


func _flat(a: Vector3, b: Vector3) -> float:
    return Vector2(a.x - b.x, a.z - b.z).length()


func _physics_process(delta: float) -> void:
    _t -= delta
    if _t <= 0.0:
        _t = 0.2
        veh_cache = get_tree().get_nodes_in_group("vehicles")
    if not Game.running:
        return
    _sw_t -= delta
    if _sw_t <= 0.0:
        _sw_t = 0.4
        _stream()
    _spawn_t -= delta
    if _spawn_t <= 0.0:
        _spawn_t = 0.7
        if _count_near() < target_count:
            spawn_one(true)


func _count_near() -> int:
    var pl: Node3D = Game.player as Node3D
    if pl == null:
        return cars.size()
    var n: int = 0
    for c in cars:
        if is_instance_valid(c) and _flat((c as Node3D).global_position, pl.global_position) < 220.0:
            n += 1
    return n


func _despawn(v: Vehicle) -> void:
    cars.erase(v)
    if v.driver_npc != null and is_instance_valid(v.driver_npc):
        v.driver_npc.queue_free()
    v.queue_free()


func _stream() -> void:
    var pl: Node3D = Game.player as Node3D
    if pl == null:
        return
    var cam: Camera3D = pl.get_viewport().get_camera_3d()
    var cap: int = int(Settings.PHYS_CARS[Settings.graphics])
    var alive: Array = []
    var phys_n: int = 0
    for c in cars:
        if is_instance_valid(c):
            alive.append(c)
            if (c as Vehicle).mode == Vehicle.Mode.AI_PHYS:
                phys_n += 1
    cars = alive
    for c in cars.duplicate():
        var v: Vehicle = c as Vehicle
        var dd: float = _flat(v.global_position, pl.global_position)
        if dd > 280.0 and (cam == null or not cam.is_position_in_frustum(v.global_position)):
            _despawn(v)
            continue
        if v.mode == Vehicle.Mode.AI_LANE and dd < 75.0 and phys_n < cap:
            v.set_ai_phys(true)
            phys_n += 1
        elif v.mode == Vehicle.Mode.AI_PHYS and dd > 115.0:
            v.set_ai_phys(false)
            phys_n -= 1


func _pick_model() -> String:
    var r: float = randf()
    if r < 0.5:
        return "vaz"
    if r < 0.8:
        return "g_class"
    return "gallardo"


func spawn_one(away: bool) -> bool:
    var pl: Node3D = Game.player as Node3D
    var cam: Camera3D = null
    if pl != null:
        cam = pl.get_viewport().get_camera_3d()
    var dmin: float = 85.0 if away else 20.0
    var all: Array = get_tree().get_nodes_in_group("vehicles")
    for attempt in 28:
        var ax: int = randi() % 2
        var dd: int = 1 if randf() < 0.5 else -1
        var a_j: int = randi() % Const.N
        var a_k: int = randi() % Const.N
        var b_j: int = a_j + (dd if ax == 0 else 0)
        var b_k: int = a_k + (dd if ax == 1 else 0)
        if not Const.node_ok(b_j, b_k):
            continue
        var frac: float = randf_range(0.05, 0.95)
        var p: Vector3 = AIDriver.edge_pos(a_j, a_k, ax, dd, frac, 2.2)
        if pl != null:
            var dist: float = _flat(p, pl.global_position)
            if dist < dmin or dist > 210.0:
                continue
            if away and dist < 150.0 and cam != null and cam.is_position_in_frustum(p + Vector3(0, 1, 0)):
                continue
        var free: bool = true
        for c in all:
            if is_instance_valid(c) and (c as Node3D).global_position.distance_to(p) < 10.0:
                free = false
                break
        if not free:
            continue
        var id: String = _pick_model()
        var def: Dictionary = VehicleDefs.get_def(id)
        var cols: Array = def["colors"]
        var v := Vehicle.new()
        v.setup(id, cols[randi() % cols.size()])
        Game.world.add_child(v)
        v.place(p + Vector3(0, 1.0, 0), 0.0)
        v.start_ai_lane()
        var ai := AIDriver.new()
        ai.init_on_edge(v, a_j, a_k, ax, dd, frac)
        v.ai = ai
        cars.append(v)
        var npc: NPC = NPC.create()
        Game.world.add_child(npc)
        npc.enter_vehicle(v)
        return true
    return false
