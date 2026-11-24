class_name Corpse
extends RigidBody3D
# Тело убитого человека: настоящее физическое тело. Его отбрасывает машина, оно не проходит сквозь неё.


static func make(src: Node3D, rig_: Humanoid, vel: Vector3) -> Corpse:
    var c := Corpse.new()
    c.collision_layer = Const.L_BODY
    c.collision_mask = Const.L_WORLD | Const.L_VEH
    c.mass = 70.0
    c.linear_damp = 0.3
    c.angular_damp = 1.4
    var cs := CollisionShape3D.new()
    var cap := CapsuleShape3D.new()
    cap.radius = 0.28
    cap.height = 1.7
    cs.shape = cap
    c.add_child(cs)
    var pm := PhysicsMaterial.new()
    pm.friction = 0.9
    pm.bounce = 0.05
    c.physics_material_override = pm
    Game.world.add_child(c)
    var yaw: float = src.global_rotation.y
    c.global_transform = Transform3D(Basis.IDENTITY, src.global_position + Vector3(0, 0.88, 0))
    var old: Node = rig_.get_parent()
    if old != null:
        old.remove_child(rig_)
    c.add_child(rig_)
    rig_.position = Vector3(0, -0.88, 0)
    rig_.rotation = Vector3(0, rig_.rotation.y, 0)
    rig_.go_limp()
    c.linear_velocity = vel
    c.angular_velocity = Vector3(randf_range(-2.0, 2.0), randf_range(-1.0, 1.0), randf_range(-2.0, 2.0))
    c.apply_torque_impulse(Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * 28.0)
    c.add_to_group("corpses")
    return c


func _ready() -> void:
    _life()


func _life() -> void:
    await get_tree().create_timer(25.0).timeout
    if is_inside_tree():
        queue_free()
