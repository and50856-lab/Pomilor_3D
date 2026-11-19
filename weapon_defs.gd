class_name WeaponDefs
extends RefCounted

const ORDER: Array = ["bat", "deagle", "ak47", "mossberg", "rpg"]
const CATS: Array = ["Холодное", "Пистолеты", "Автоматы", "Дробовики", "Тяжёлое"]

const DEFS: Dictionary = {
    "bat": {
        "name": "Бита", "kind": "melee", "damage": 30.0, "rate": 1.5, "range": 2.2,
        "mag": 0, "reserve": 0, "spread": 0.0, "auto": false, "pellets": 1, "reload": 0.0,
        "recoil": 0.0, "hold": 3, "snd": "bat_hit", "loud": 0.0,
    },
    "deagle": {
        "name": "Desert Eagle", "kind": "gun", "damage": 58.0, "rate": 2.4, "range": 140.0,
        "mag": 7, "reserve": 56, "spread": 0.5, "auto": false, "pellets": 1, "reload": 1.8,
        "recoil": 3.2, "hold": 1, "snd": "deagle", "loud": 110.0,
    },
    "ak47": {
        "name": "AK-47", "kind": "gun", "damage": 27.0, "rate": 9.0, "range": 180.0,
        "mag": 30, "reserve": 150, "spread": 1.2, "auto": true, "pellets": 1, "reload": 2.4,
        "recoil": 1.5, "hold": 2, "snd": "rifle", "loud": 130.0,
    },
    "mossberg": {
        "name": "Mossberg 500", "kind": "gun", "damage": 15.0, "rate": 1.1, "range": 55.0,
        "mag": 6, "reserve": 36, "spread": 4.5, "auto": false, "pellets": 8, "reload": 2.6,
        "recoil": 4.5, "hold": 2, "snd": "shotgun", "loud": 130.0,
    },
    "rpg": {
        "name": "RPG", "kind": "rocket", "damage": 260.0, "rate": 0.5, "range": 300.0,
        "mag": 1, "reserve": 5, "spread": 0.0, "auto": false, "pellets": 1, "reload": 3.2,
        "recoil": 6.0, "hold": 2, "snd": "rpg", "loud": 160.0,
    },
}


static func get_def(id: String) -> Dictionary:
    if DEFS.has(id):
        return DEFS[id]
    return {}
