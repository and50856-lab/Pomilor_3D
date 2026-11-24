class_name VehicleDefs
extends RefCounted

const ORDER: Array = ["g_class", "vaz", "gallardo"]

# Начало координат машины — на высоте оси колёс. Перед = -Z.
# kw — мощность двигателя (кВт), f_max — предел тяги на старте (Н), vmax — максимальная скорость (м/с),
# hp — прочность кузова, grip_r — доля сцепления задних шин (ниже = легче сорвать в занос),
# s0 — статическое сжатие подвески (м), zeta — демпфирование подвески, com_y — высота центра масс.
const DEFS: Dictionary = {
    "g_class": {
        "name": "Mercedes-Benz Geländewagen", "mass": 2400.0, "kw": 210.0, "f_max": 11000.0, "vmax": 48.0,
        "wheel_r": 0.42, "track": 1.66, "wheelbase": 2.85, "steer": 0.5, "grip": 1.1, "grip_r": 0.95,
        "drive": "awd", "lat_k": 8.0, "hp": 1500.0, "s0": 0.11, "zeta": 0.5, "com_y": -0.10,
        "body": Vector3(1.95, 1.05, 4.6), "body_c": Vector3(0.0, 0.405, 0.0),
        "cab": Vector3(1.8, 0.62, 2.6), "cab_c": Vector3(0.0, 1.24, 0.5),
        "seat": Vector3(-0.46, 0.45, 0.25), "door": Vector3(-0.85, 1.15, 0.78), "door_h": 1.3,
        "length": 4.7, "width": 1.95,
        "colors": [Color(0.05, 0.05, 0.06), Color(0.8, 0.8, 0.82), Color(0.1, 0.25, 0.12), Color(0.5, 0.05, 0.05)],
    },
    "vaz": {
        "name": "ВАЗ-21099", "mass": 950.0, "kw": 58.0, "f_max": 4200.0, "vmax": 39.0,
        "wheel_r": 0.30, "track": 1.40, "wheelbase": 2.46, "steer": 0.55, "grip": 1.0, "grip_r": 0.9,
        "drive": "fwd", "lat_k": 9.0, "hp": 650.0, "s0": 0.10, "zeta": 0.45, "com_y": -0.12,
        "body": Vector3(1.62, 0.62, 3.95), "body_c": Vector3(0.0, 0.2, 0.0),
        "cab": Vector3(1.5, 0.52, 1.9), "cab_c": Vector3(0.0, 0.77, 0.2),
        "seat": Vector3(-0.40, 0.17, 0.15), "door": Vector3(-0.45, 0.95, 0.55), "door_h": 0.95,
        "length": 4.0, "width": 1.62,
        "colors": [Color(0.75, 0.75, 0.78), Color(0.55, 0.06, 0.06), Color(0.1, 0.2, 0.45), Color(0.85, 0.8, 0.2), Color(0.3, 0.3, 0.32)],
    },
    "gallardo": {
        "name": "Lamborghini Gallardo", "mass": 1450.0, "kw": 368.0, "f_max": 12500.0, "vmax": 80.0,
        "wheel_r": 0.34, "track": 1.60, "wheelbase": 2.56, "steer": 0.5, "grip": 1.35, "grip_r": 1.0,
        "drive": "awd", "lat_k": 12.0, "hp": 850.0, "s0": 0.07, "zeta": 0.65, "com_y": -0.20,
        "body": Vector3(1.9, 0.42, 4.25), "body_c": Vector3(0.0, 0.14, 0.0),
        "cab": Vector3(1.4, 0.47, 1.5), "cab_c": Vector3(0.0, 0.585, 0.25),
        "seat": Vector3(-0.42, -0.02, 0.12), "door": Vector3(-0.55, 1.0, 0.32), "door_h": 0.55,
        "length": 4.3, "width": 1.9,
        "colors": [Color(0.95, 0.6, 0.05), Color(0.7, 0.02, 0.02), Color(0.15, 0.7, 0.2), Color(0.9, 0.9, 0.92)],
    },
}


static func get_def(id: String) -> Dictionary:
    if DEFS.has(id):
        return DEFS[id]
    return DEFS["vaz"]
