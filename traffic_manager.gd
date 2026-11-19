class_name TrafficManager
extends Node
# Спавн и поддержание трафика (машины с водителями-NPC едут по полосам).

var cars: Array = []
var veh_cache: Array = []
var target_count: int = 10
var _t: float = 0.0
var _respawn_t: float = 0.0


func _physics_process(delta: float) -> void:
    _t -= delta
    if _t <= 0.0:
        _t = 0.2
        veh_cache = get_tree().get_nodes_in_group("vehicles")
    _respawn_t -= delta
    if _respawn_t <= 0.0 and cars.size() < target_count and Game.running:
        _respawn_t = 2.5
        spawn_one(true)


func _pick_model() -> String:
    var r: float = randf()
    if r < 0.5:
        return "vaz"
    if r < 0.8:
        return "g_class"
    return "gallardo"


func spawn_one(away: bool) -> bool:
    var pl: Node3D = Game.player as Node3D
    for attempt in 14:
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
        if pl != null and away and pl.global_position.distance_to(p) < 45.0:
            continue
        var free: bool = true
        for c in cars:
            if (c as Node3D).global_position.distance_to(p) < 10.0:
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
