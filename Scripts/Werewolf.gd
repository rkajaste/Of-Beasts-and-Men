extends Enemy

enum WerewolfAction {
    Explosion,
    IntercardinalExplosion,
    CardinalExplosion,
    Donut,
    Charge,
    Raidwide
}

const CHARGE_CAST_TIME_IN_MS = 2.5 * 1000
const RAIDWIDE_CAST_TIME_IN_MS = 5 * 1000
const EXPLOSION_CAST_TIME_IN_MS = 2 * 1000
const DIRECTIONAL_EXPLOSION_CAST_TIME_IN_MS = 2 * 1000

const CHARGE_ATTACK_DAMAGE_NEAR = 40
const CHARGE_ATTACK_DAMAGE_MID = 20
const RAIDWIDE_DAMAGE = 40
const EXPLOSION_DAMAGE = 20
const DONUT_DAMAGE = 20

const CHARGE_ATTACK_NEAR_DISTANCE_END = 180
const CHARGE_ATTACK_MID_DISTANCE_END = 360
const CHARGE_ATTACK_COLOR_NEAR = "#e22735"
const CHARGE_ATTACK_COLOR_MID = "#bf2fca"
const CHARGE_ATTACK_COLOR_FAR = "#79c109"
const CHARGE_ATTACK_SPEED = 650
const CHARGE_TIME_MS = 800

var time_before_charge_ms

var cast_bar
var cooldowns
var sprite
var explosion_telegraph
var ic_explosion_telegraphs
var c_explosion_telegraphs
var donut_telegraph

var charge_attack_line
var charge_attack_hitbox
var charge_attack_active_color

var position_before_charge_attack
var player_position_before_charge_attack
var are_telegraphs_shown = false # variable to prevent looping through collision shapes when not needed


var next_action_timer
var cast_bar_value = 0
var cast_bar_max_value = 0
var selected_action = null


func _ready():
    max_health = 500
    current_health = 500
    _hitbox = $Hitbox
    next_action_timer = $NextActionTimer
    sprite = $Sprite2D
    cast_bar = $CastBar
    explosion_telegraph = $Explosion/CollisionShape2D
    ic_explosion_telegraphs = $IntercardinalExplosion.get_children()
    c_explosion_telegraphs = $CardinalExplosion.get_children()
    charge_attack_hitbox = $Charge
    charge_attack_line = $ChargeAttackLine
    donut_telegraph = $Donut
    cooldowns = $Cooldowns
    player_node = get_parent().get_children()[4]

    cast_bar.visible = false
    next_action_timer.start()

    get_tree().call_group("main", "update_boss_hp", current_health, max_health)

    reset_actions()
    update_user_interface()


func _process(dt):
    player_position = player_node.position
    if (selected_action != null and not _has_state(EnemyState.Casting) and not _has_state(EnemyState.ChargingForward)):
        prepare_cast()
    if (_has_state(EnemyState.Casting)):
        cast()
    elif (_has_state(EnemyState.ChargingForward)):
        charge_forward(dt)
    update_user_interface()

func spawn(pos: Vector2):
    position = pos

func update_user_interface():
    cast_bar.value = cast_bar_value
    cast_bar.max_value = cast_bar_max_value

func prepare_to_charge_forward():
    var line_length = position.distance_to(player_position)
    charge_attack_active_color = CHARGE_ATTACK_COLOR_NEAR

    if (line_length > CHARGE_ATTACK_NEAR_DISTANCE_END):
        charge_attack_active_color = CHARGE_ATTACK_COLOR_MID
    if (line_length > CHARGE_ATTACK_MID_DISTANCE_END):
        charge_attack_active_color = CHARGE_ATTACK_COLOR_FAR

    $ChargeAttackLine.set_point_position(0, to_local(position))
    $ChargeAttackLine.set_point_position(1, to_local(player_position))
    $ChargeAttackLine.default_color = charge_attack_active_color

func charge_forward(dt):
    var distance_travelled = position.distance_to(position_before_charge_attack)
    var velo = player_position_before_charge_attack - position_before_charge_attack
    velo = velo.normalized()
    velo = velo * CHARGE_ATTACK_SPEED * dt
    position += velo

    check_collision()

    if (Time.get_ticks_msec() - time_before_charge_ms >= CHARGE_TIME_MS or distance_travelled >= CHARGE_ATTACK_MID_DISTANCE_END):
        _deactivate_state(EnemyState.ChargingForward)
        reset_actions()

func prepare_cast():
    cast_bar.visible = true
    if (selected_action == WerewolfAction.Explosion):
        cast_bar_max_value = EXPLOSION_CAST_TIME_IN_MS
    elif (selected_action == WerewolfAction.IntercardinalExplosion):
        cast_bar_max_value = DIRECTIONAL_EXPLOSION_CAST_TIME_IN_MS
    elif (selected_action == WerewolfAction.CardinalExplosion):
        cast_bar_max_value = DIRECTIONAL_EXPLOSION_CAST_TIME_IN_MS
    elif (selected_action == WerewolfAction.Donut):
        cast_bar_max_value = EXPLOSION_CAST_TIME_IN_MS
    elif (selected_action == WerewolfAction.Raidwide):
        cast_bar_max_value = RAIDWIDE_CAST_TIME_IN_MS
    elif (selected_action == WerewolfAction.Charge):
        cast_bar_max_value = CHARGE_CAST_TIME_IN_MS

    _activate_state(EnemyState.Casting)

func check_collision():
    if (selected_action == WerewolfAction.Explosion):
        for body in explosion_telegraph.get_parent().get_overlapping_bodies():
            if (body.name == "Player"):
                body.take_damage(EXPLOSION_DAMAGE)
    if (selected_action == WerewolfAction.IntercardinalExplosion):
        for body in ic_explosion_telegraphs[0].get_parent().get_overlapping_bodies():
            if (body.name == "Player"):
                body.take_damage(EXPLOSION_DAMAGE)
    if (selected_action == WerewolfAction.CardinalExplosion):
        for body in c_explosion_telegraphs[0].get_parent().get_overlapping_bodies():
            if (body.name == "Player"):
                body.take_damage(EXPLOSION_DAMAGE)
    if (selected_action == WerewolfAction.Donut):
        for body in donut_telegraph.get_overlapping_bodies():
            if (body.name == "Player"):
                body.take_damage(DONUT_DAMAGE)
                break
    if (selected_action == WerewolfAction.Raidwide):
        player_node.take_damage(RAIDWIDE_DAMAGE)
    if (selected_action == WerewolfAction.Charge):
        if (charge_attack_hitbox.find_child("Rect").disabled):
            return
        for body in charge_attack_hitbox.get_overlapping_bodies():
            if (body.name == "Player"):
                if (charge_attack_active_color == CHARGE_ATTACK_COLOR_NEAR):
                    body.take_damage(CHARGE_ATTACK_DAMAGE_NEAR)
                elif (charge_attack_active_color == CHARGE_ATTACK_COLOR_MID):
                    body.take_damage(CHARGE_ATTACK_DAMAGE_MID)

                charge_attack_hitbox.find_child("Rect").disabled = true
                break

func reset_actions():
    selected_action = null

    explosion_telegraph.get_parent().visible = false
    explosion_telegraph.disabled = true

    ic_explosion_telegraphs[0].get_parent().visible = false
    for telegraph in ic_explosion_telegraphs:
        telegraph.disabled = true

    c_explosion_telegraphs[0].get_parent().visible = false
    for telegraph in c_explosion_telegraphs:
        telegraph.disabled = true

    donut_telegraph.visible = false
    for area in donut_telegraph.find_children("Rect"):
        area.disabled = true

    $ChargeAttackLine.clear_points()
    charge_attack_hitbox.find_child("Rect").disabled = true
    charge_attack_active_color = CHARGE_ATTACK_COLOR_FAR

    sprite.material.set_shader_parameter("width", 0)

    are_telegraphs_shown = false

func show_telegraphs():
    if (selected_action == WerewolfAction.Explosion):
        explosion_telegraph.get_parent().visible = true
        explosion_telegraph.disabled = false
    if (selected_action == WerewolfAction.IntercardinalExplosion):
        ic_explosion_telegraphs[0].get_parent().visible = true
        for telegraph in ic_explosion_telegraphs:
            telegraph.disabled = false
    if (selected_action == WerewolfAction.CardinalExplosion):
        c_explosion_telegraphs[0].get_parent().visible = true
        for telegraph in c_explosion_telegraphs:
            telegraph.disabled = false
    if (selected_action == WerewolfAction.Donut):
        donut_telegraph.visible = true
        for area in donut_telegraph.find_children("Rect"):
            area.disabled = true

    if (selected_action == WerewolfAction.Charge):
        $ChargeAttackLine.add_point(position)
        $ChargeAttackLine.add_point(player_position)
        $ChargeAttackLine.width = 5

    if (selected_action == WerewolfAction.Raidwide):
        sprite.material.set_shader_parameter("width", 4)

    are_telegraphs_shown = true

func cast():
    if (not cooldowns.has_cooldown("cast_bar_countdown")):
        cast_bar_value += 25 # must match the cooldown if you want to tweak the cast bar smoothness
        cooldowns.set_on_cooldown("cast_bar_countdown")

    if (
        float(cast_bar_value) / float(cast_bar_max_value) > 0.5 or
        [WerewolfAction.Raidwide, WerewolfAction.Charge].has(selected_action)
    ):
        if (not are_telegraphs_shown):
            show_telegraphs()

    if (selected_action == WerewolfAction.Charge):
        prepare_to_charge_forward()

    if (cast_bar_value >= cast_bar_max_value):
        if (selected_action == WerewolfAction.Charge):
            time_before_charge_ms = Time.get_ticks_msec()
            position_before_charge_attack = position
            player_position_before_charge_attack = player_position
            $ChargeAttackLine.clear_points()
            charge_attack_hitbox.find_child("Rect").disabled = false
            _activate_state(EnemyState.ChargingForward)
        else:
            check_collision()
            reset_actions()
        cast_bar.visible = false
        cast_bar_value = 0
        next_action_timer.start()
        _deactivate_state(EnemyState.Casting)

func _on_hitbox_area_entered(area):
    if (area.get_parent().name != "Player"):
        return

    var player = area.get_parent()
    if (area.name.begins_with("AttackHitbox")):
        take_damage(player.damage)
        get_tree().call_group("main", "update_boss_hp", current_health, max_health)
        if (player.current_transformation == player.Transformation.Bat):
            player.heal()
        elif (player.current_transformation == player.Transformation.None):
            player.increase_transformation_gauge()

func _on_next_action_timer_timeout():
    if (_has_state(EnemyState.ChargingForward)):
        return

    const actions = [
        WerewolfAction.Explosion,
        WerewolfAction.IntercardinalExplosion,
        WerewolfAction.CardinalExplosion,
        WerewolfAction.Donut,
        WerewolfAction.Raidwide,
        WerewolfAction.Charge
    ]
    selected_action = actions[randi_range(0, len(actions) - 1)]

func die():
    super.die()
    get_tree().call_group("main", "win_game")
