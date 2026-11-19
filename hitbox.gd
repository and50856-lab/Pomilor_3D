class_name HitBox
extends Area3D
# Хитбокс части тела. Пули (рейкаст с collide_with_areas) попадают сюда.

var character = null
var part: String = "torso"


static func attach(parent: Node3D, shape: Shape3D, pos: Vector3, part_name: String, owner_char) -> HitBox:
    var hb := HitBox.new()
    hb.character = owner_char
    hb.part = part_name
    hb.collision_layer = Const.L_HIT
    hb.collision_mask = 0
    hb.monitoring = false
    hb.monitorable = true
    var cs := CollisionShape3D.new()
    cs.shape = shape
    hb.add_child(cs)
    hb.position = pos
    parent.add_child(hb)
    return hb
