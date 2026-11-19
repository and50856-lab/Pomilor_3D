class_name Pickup
extends RigidBody3D
# Оружие на земле (выброшенное). Подбирается, если навести точку и нажать кнопку.

var weapon_id: String = ""
var mag: int = 0
var reserve: int = 0


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


func display_name() -> String:
    var d: Dictionary = WeaponDefs.get_def(weapon_id)
    return str(d.get("name", weapon_id))


func collect() -> void:
    Game.give_weapon(weapon_id, mag, reserve)
    Game.equip(weapon_id)
    Sfx.play2d("pickup")
    Game.say("Подобрано: %s" % display_name())
    queue_free()
