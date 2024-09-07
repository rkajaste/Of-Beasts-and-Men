extends Node

var COOLDOWNS = {
    "player_attack": {
        "cooldown": 1000,
        "lastUsedInMs": 0
    },
    "player_stamina_regen": {
        "cooldown": 25,
        "lastUsedInMs": 0
    },
    "player_deplete_transformation_gauge": {
        "cooldown": 1000,
        "lastUsedInMs": 0
    },
    "wolf_attack": {
        "cooldown": 1200,
        "lastUsedInMs": 0
    },
    "cast_bar_countdown": {
        "cooldown": 25,
        "lastUsedInMs": 0
    }
}

func has_cooldown(name: String) -> bool:
    var config = COOLDOWNS[name]

    return (
        config["lastUsedInMs"] != 0 and
        (Time.get_ticks_msec() - config["lastUsedInMs"]) < config["cooldown"]
    )

# Use only values from enum-objects defined here for argument
func set_on_cooldown(name: String) -> void:
    COOLDOWNS[name]["lastUsedInMs"] = Time.get_ticks_msec()

func reset_cooldown(name: String) -> void:
    COOLDOWNS[name]["lastUsedInMs"] = 0
