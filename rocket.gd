class_name Rocket
extends Node3D
# Ракета РПГ: летит по прямой, проверяя столкновение лучом каждый кадр физики.

var vel: Vector3 = Vector3.ZERO
var shooter = null
var life: float = 0.0
var _light: OmniLight3D


static func launch(pos: Vector3, dir: Vector3, who) -> void:
    if Game.world == null:
        return
    var r := Rocket.new()
    r.shooter = who
    Game.world.add_child(r)
    r.global_position = pos
    r.vel = dir.normalized() * 58.0
    r.look_at(pos + dir, Vector3.UP)


func _ready() -> void:
    var body := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = 0.0
    cm.bottom_radius = 0.07
    cm.height = 0.35
    cm.radial_segments = 8
    cm.rings = 1
    body.mesh = cm
    body.material_override = WeaponModel.mat(Color(0.3, 0.3, 0.22), 0.3, 0.5)
    body.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
    add_child(body)
    var tube := MeshInstance3D.new()
    var tm := CylinderMesh.new()
    tm.top_radius = 0.045
    tm.bottom_radius = 0.045
    tm.height = 0.5
    tm.radial_segments = 8
    tm.rings = 1
    tube.mesh = tm
    tube.material_override = WeaponModel.mat(Color(0.25, 0.28, 0.2), 0.3, 0.5)
    tube.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
    tube.position = Vector3(0, 0, 0.4)
    add_child(tube)
    _light = OmniLight3D.new()
    _light.light_color = Color(1.0, 0.6, 0.2)
    _light.light_energy = 3.0
    _light.omni_range = 8.0
    _light.position = Vector3(0, 0, 0.7)
    add_child(_light)


func _physics_process(delta: float) -> void:
    life += delta
    var from: Vector3 = global_position
    var to: Vector3 = from + vel * delta
    var q := PhysicsRayQueryParameters3D.create(from, to, Const.L_WORLD | Const.L_VEH)
    var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
    var end: Vector3 = to
    if not hit.is_empty():
        end = hit["position"]
    var nh: Dictionary = Combat.ray_npc(from, end)
    if not nh.is_empty():
        global_position = nh["pos"]
        _boom()
        return
    if not hit.is_empty():
        global_position = end
        _boom()
        return
    global_position = to
    if life > 7.0 or to.y < -5.0:
        _boom()


func _boom() -> void:
    set_physics_process(false)
    Combat.explode(global_position, 9.0, 260.0, shooter)
    queue_free()
