extends Node
# Глобальное состояние игры (автозагрузка "Game")

signal weapons_changed
signal equipped_changed
signal gunshot(pos: Vector3, loudness: float)
signal toast(text: String)

var player = null
var hud = null
var traffic = null
var npc_mgr = null
var world: Node3D = null
var ped_net: PedNet = null
var light_time: float = 0.0
var prompt: String = ""
var prompt_btn: String = ""
var running: bool = false
var owned: Dictionary = {}
var equipped: String = ""

var _walkers: Array = []
var _walkers_t: float = 0.0


func reset() -> void:
    player = null
    hud = null
    traffic = null
    npc_mgr = null
    world = null
    ped_net = null
    light_time = 0.0
    prompt = ""
    prompt_btn = ""
    running = false
    owned.clear()
    equipped = ""
    _walkers = []
    set_slowmo(false)
    if is_inside_tree():
        get_tree().paused = false


func _process(delta: float) -> void:
    if running:
        light_time += delta
    _walkers_t -= delta


func light_state(axis: int) -> int:
    # 0 зелёный, 1 жёлтый, 2 красный
    var t: float = fposmod(light_time + (12.0 if axis == 1 else 0.0), Const.CYCLE)
    if t < 9.0:
        return 0
    if t < 11.0:
        return 1
    return 2


func walkers() -> Array:
    if _walkers_t <= 0.0:
        _walkers_t = 0.15
        _walkers = get_tree().get_nodes_in_group("walkers")
    return _walkers


func set_slowmo(on: bool) -> void:
    Engine.time_scale = 0.2 if on else 1.0
    AudioServer.playback_speed_scale = 0.35 if on else 1.0


func give_weapon(id: String, mag: int = -1, reserve: int = -1) -> void:
    var d: Dictionary = WeaponDefs.get_def(id)
    if d.is_empty():
        return
    var m: int = int(d["mag"]) if mag < 0 else mag
    var r: int = int(d["reserve"]) if reserve < 0 else reserve
    if owned.has(id):
        var cur: Dictionary = owned[id]
        cur["reserve"] = int(cur["reserve"]) + m + r
    else:
        owned[id] = {"mag": m, "reserve": r}
    weapons_changed.emit()


func equip(id: String) -> void:
    if id == "" or owned.has(id):
        equipped = id
        equipped_changed.emit()


func remove_weapon(id: String) -> Dictionary:
    var data: Dictionary = {}
    if owned.has(id):
        data = owned[id]
        owned.erase(id)
    if equipped == id:
        equipped = ""
        equipped_changed.emit()
    weapons_changed.emit()
    return data


func say(text: String) -> void:
    toast.emit(text)
