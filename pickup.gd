class_name Pickup
extends RigidBody3D
# Оружие на земле (выброшенное). Подбирается, если навести точку и нажать кнопку.

var weapon_id: String = ""
var mag: int = 0
var reserve: int = 0
var thrown: bool = false
var thrower = null


static func spawn(pos: Vector3, id: String, m: int, r: int, vel: Vector3) -> Pickup:
    var p := Pickup.new()
    p.weapon_id = id
    p.mag = m
    p.reserve = r
    Game.world.add_child(p)
    p.global_position = pos
    p.linear_velocity = vel
    p.angular_velocity = Vector3(randf_range(-3, 3), randf_range(-3, 3), randf_range(-3, 3))
    return p


func _ready() -> void:
    collision_layer = Const.L_ITEM
    collision_mask = Const.L_WORLD
    mass = 3.0
    add_to_group("pickups")
    var cs := CollisionShape3D.new()
    var bs := BoxShape3D.new()
    bs.size = Vector3(0.22, 0.16, 0.7)
    cs.shape = bs
    add_child(cs)
    var model: Node3D = WeaponModel.build(weapon_id)
    add_child(model)


func _physics_process(_delta: float) -> void:
    if not thrown:
        return
    if linear_velocity.length() < 3.0:
        thrown = false
        return
    for n in get_tree().get_nodes_in_group("npcs"):
        var npc: Node3D = n as Node3D
        if npc == null:
            continue
        if (npc.global_position + Vector3(0, 1.0, 0)).distance_to(global_position) < 0.8:
            var bat: bool = weapon_id == "bat"
            npc.call("take_hit", "torso", 14.0 if bat else 8.0, linear_velocity.normalized(), thrower)
            Sfx.play3d("bat_hit" if bat else "punch", global_position, 0.0, 1.0, 40.0)
            thrown = false
            linear_velocity *= 0.3
            return


func display_name() -> String:
    var d: Dictionary = WeaponDefs.get_def(weapon_id)
    return str(d.get("name", weapon_id))


func collect() -> void:
    Game.give_weapon(weapon_id, mag, reserve)
    Game.equip(weapon_id)
    Sfx.play2d("pickup")
    Game.say("Подобрано: %s" % display_name())
    queue_free()
