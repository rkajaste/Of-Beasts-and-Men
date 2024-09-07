extends CharacterBody2D

enum Direction {
    Up,
    Down,
    Left,
    Right
}

enum PlayerState {
    Attacking,
    Moving,
    Idle,
    Dodging,
    Invincible
}

enum Transformation {
    Wolf,
    Bat,
    Bear,
    None
}

const PLAYER_ANIMATION_FRAME_SIZE = 96
const TILE_SIZE = 32
const SPEED = 32 * 1000
const DODGE_SPEED = 500
const INVINCIBILITY_TIME_MS = 500
const MAX_HEALTH = 100
const MAX_STAMINA = 100
const DODGE_COST = 25
const ATTACK_COST = 20
const STAMINA_REGEN = 0.5
const BASE_DAMAGE = 10

const TRANSFORMATION_GAUGE_MAX = 100
const TRANSFORMATION_GAUGE_REGEN_PER_HIT = 5

const WOLF_FORM_COLOR = Vector4(0.98, 0.0, 0.124, 1.0)
const WOLF_FORM_STAMINA_REGEN = STAMINA_REGEN * 2
const WOLF_FORM_DAMAGE = BASE_DAMAGE * 2
const WOLF_FORM_COST_PER_SECOND = 5

const BAT_FORM_COLOR = Vector4(0.23, 0.83, 0.0, 1.0)
const BAT_FORM_HEAL_PER_HIT = 8
const BAT_FORM_TRANSFORMATION_GAUGE_LOSS_PER_HIT = 5

const BEAR_FORM_COLOR = Vector4(0.93, 0.743, 0.0, 1.0)
const BEAR_FORM_ACTIVATION_COST = TRANSFORMATION_GAUGE_MAX

const TRANSFORMATION_SPRITE_OUTLINE_WIDTH = 1

var damage = BASE_DAMAGE
var current_stamina = 50
var current_health = 100
var current_shield = 0
var current_transformation = Transformation.None
var current_transformation_gauge_value = 0

var time_since_last_damage = 0
var position_before_dodge = Vector2()
var direction = Direction.Left
var last_direction = direction
var active_states = [PlayerState.Idle]
var animation_player
var cooldowns
var particle_trail
var sprite
var health_bar
var stamina_bar
var shield_bar
var ui_wolf
var ui_bat
var ui_bear
var ui_transformation_gauge

var attack_hitbox_up
var attack_hitbox_down
var attack_hitbox_left
var attack_hitbox_right
var hitbox
var hud

func _ready():
    animation_player = $AnimationPlayer
    cooldowns = $Cooldowns
    particle_trail = $Sprite2D/GPUParticles2D
    sprite = $Sprite2D
    attack_hitbox_up = $AttackHitboxUp/CollisionShape2D
    attack_hitbox_down = $AttackHitboxDown/CollisionShape2D
    attack_hitbox_left = $AttackHitboxLeft/CollisionShape2D
    attack_hitbox_right = $AttackHitboxRight/CollisionShape2D
    hitbox = $Hitbox/Rect

    hud = get_parent().get_children()[3]
    health_bar = hud.find_child("Player").find_child("Health")
    stamina_bar = hud.find_child("Player").find_child("Stamina")
    shield_bar = hud.find_child("Player").find_child("Shield")
    ui_wolf = hud.find_child("Player").find_child("Powers").find_child("Wolf")
    ui_bat = hud.find_child("Player").find_child("Powers").find_child("Bat")
    ui_bear = hud.find_child("Player").find_child("Powers").find_child("Bear")
    ui_transformation_gauge = hud.find_child("Player").find_child("Powers").find_child("BeastBloodGauge")
    animation_player.animation_finished.connect(_on_animation_end)
    setup_ui()

func setup_ui():
    sprite.material.set_shader_parameter("width", 0)
    ui_wolf.material.set_shader_parameter("width", 0)
    ui_bat.material.set_shader_parameter("width", 0)
    ui_bear.material.set_shader_parameter("width", 0)

    shield_bar.max_value = TRANSFORMATION_GAUGE_MAX
    shield_bar.value = 0
    ui_transformation_gauge.max_value = TRANSFORMATION_GAUGE_MAX
    ui_transformation_gauge.value = 0

func _process(dt):
    animate()

    if (not has_state(PlayerState.Dodging)):
        if (Input.get_action_strength("move_up")):
            direction = Direction.Up
            move(dt)
        elif (Input.get_action_strength("move_down")):
            direction = Direction.Down
            move(dt)
        elif (Input.get_action_strength("move_left")):
            direction = Direction.Left
            move(dt)
        elif (Input.get_action_strength("move_right")):
            direction = Direction.Right
            move(dt)

    if (has_state(PlayerState.Attacking)):
        direction = last_direction

    if (not has_state(PlayerState.Attacking)):
        attack_hitbox_up.disabled = true
        attack_hitbox_down.disabled = true
        attack_hitbox_left.disabled = true
        attack_hitbox_right.disabled = true

    if (
        Input.is_action_just_released("move_up") ||
        Input.is_action_just_released("move_down") ||
        Input.is_action_just_released("move_right") ||
        Input.is_action_just_released("move_left") &&
        has_state(PlayerState.Moving) &&
        not has_state(PlayerState.Attacking)
    ):
        deactivate_state(PlayerState.Moving)
        activate_state(PlayerState.Idle)

    if (Input.get_action_strength("attack")):
        attack()
    if (Input.is_action_just_released("dodge")):
        prepare_dodge()

    if (not has_state(PlayerState.Attacking)):
        if (Input.is_action_just_released("activate_wolf_power")):
            if (current_transformation == Transformation.Wolf):
                activate_transformation(Transformation.None)
            else:
                activate_transformation(Transformation.Wolf)
        if (Input.is_action_just_released("activate_bat_power")):
            if (current_transformation == Transformation.Bat):
                activate_transformation(Transformation.None)
            else:
                activate_transformation(Transformation.Bat)
        if (Input.is_action_just_released("activate_bear_power")):
            if (current_transformation == Transformation.Bear):
                activate_transformation(Transformation.None)
            else:
                activate_transformation(Transformation.Bear)

    handle_transformation()

    if (has_state(PlayerState.Dodging)):
        dodge(dt)
    if (not has_state(PlayerState.Attacking) and not has_state(PlayerState.Attacking)):
        regenerate_stamina()

    update_status_bar()

    if (Time.get_ticks_msec() - time_since_last_damage >= INVINCIBILITY_TIME_MS):
        hitbox.set_deferred("disabled", false)

    last_direction = direction

func spawn(pos: Vector2):
    position = pos
    current_health = MAX_HEALTH
    current_stamina = MAX_STAMINA

func handle_transformation():
    if (current_transformation == Transformation.Wolf):
        if (not cooldowns.has_cooldown("player_deplete_transformation_gauge")):
            current_transformation_gauge_value -= WOLF_FORM_COST_PER_SECOND
            cooldowns.set_on_cooldown("player_deplete_transformation_gauge")
        if (current_transformation_gauge_value <= 0):
            activate_transformation(Transformation.None)
    elif (current_transformation == Transformation.Bat):
        if (current_transformation_gauge_value <= 0):
            activate_transformation(Transformation.None)
    elif (current_transformation == Transformation.Bear):
        if (current_shield <= 0):
            activate_transformation(Transformation.None)

    if (current_transformation_gauge_value < 0):
        current_transformation_gauge_value = 0


func activate_transformation(transformation: Transformation):
    current_transformation = transformation
    var color
    var UI_TRANSFORMATION_OUTLINE_WIDTH = 3

    ui_wolf.material.set_shader_parameter("width", 0)
    ui_bat.material.set_shader_parameter("width", 0)
    ui_bear.material.set_shader_parameter("width", 0)

    if (transformation == Transformation.None):
        sprite.material.set_shader_parameter("width", 0)
        damage = BASE_DAMAGE
        current_shield = 0
        return

    if (transformation == Transformation.Wolf):
        color = WOLF_FORM_COLOR
        damage = WOLF_FORM_DAMAGE
        ui_wolf.material.set_shader_parameter("width", UI_TRANSFORMATION_OUTLINE_WIDTH)
        ui_wolf.material.set_shader_parameter("color", color)
    elif (transformation == Transformation.Bat):
        color = BAT_FORM_COLOR

        ui_bat.material.set_shader_parameter("width", UI_TRANSFORMATION_OUTLINE_WIDTH)
        ui_bat.material.set_shader_parameter("color", color)
    elif (transformation == Transformation.Bear):
        color = BEAR_FORM_COLOR
        current_shield += current_transformation_gauge_value
        current_transformation_gauge_value -= BEAR_FORM_ACTIVATION_COST

        ui_bear.material.set_shader_parameter("width", UI_TRANSFORMATION_OUTLINE_WIDTH)
        ui_bear.material.set_shader_parameter("color", color)

    sprite.material.set_shader_parameter("width", TRANSFORMATION_SPRITE_OUTLINE_WIDTH)
    sprite.material.set_shader_parameter("color", color)

func heal():
    current_health += BAT_FORM_HEAL_PER_HIT
    current_transformation_gauge_value -= BAT_FORM_TRANSFORMATION_GAUGE_LOSS_PER_HIT

func increase_transformation_gauge():
    current_transformation_gauge_value += TRANSFORMATION_GAUGE_REGEN_PER_HIT
    if (current_transformation_gauge_value >= TRANSFORMATION_GAUGE_MAX):
        current_transformation_gauge_value = TRANSFORMATION_GAUGE_MAX

func update_status_bar():
    health_bar.value = current_health
    stamina_bar.value = current_stamina
    shield_bar.value = current_shield
    ui_transformation_gauge.value = current_transformation_gauge_value

func regenerate_stamina():
    if (not cooldowns.has_cooldown('player_stamina_regen')):
        if (current_transformation == Transformation.Wolf):
            current_stamina += WOLF_FORM_STAMINA_REGEN
        else:
            current_stamina += STAMINA_REGEN

        if (current_stamina >= MAX_STAMINA):
            current_stamina = MAX_STAMINA
        else:
            cooldowns.set_on_cooldown('player_stamina_regen')

func animate():
    var animation_suffix

    if (direction == Direction.Left):
        sprite.flip_h = false
        animation_suffix = "_horizontal"
    elif (direction == Direction.Right):
        sprite.flip_h = true
        animation_suffix = "_horizontal"
    elif (direction == Direction.Up):
        animation_suffix = "_back"
        sprite.flip_h = false
    elif (direction == Direction.Down):
        animation_suffix = "_face"
        sprite.flip_h = false

    if (has_state(PlayerState.Moving) and not has_state(PlayerState.Attacking)):
        animation_player.play("walk" + animation_suffix)
    elif (has_state(PlayerState.Attacking)):
        animation_player.play("attack" + animation_suffix)
        animation_player.advance(0)
    elif (has_state(PlayerState.Dodging)):
        if (direction == Direction.Right || direction == Direction.Left):
            animation_suffix = "_left"
        animation_player.play("dodge" + animation_suffix)
    else:
        animation_player.play("idle" + animation_suffix)
        animation_player.advance(0)

func attack():
    if (not cooldowns.has_cooldown('player_attack') && current_stamina >= ATTACK_COST):
        deactivate_state(PlayerState.Moving)
        deactivate_state(PlayerState.Idle)
        activate_state(PlayerState.Attacking)
        current_stamina -= ATTACK_COST
        cooldowns.set_on_cooldown('player_attack')

        if (direction == Direction.Right):
            attack_hitbox_up.disabled = true
            attack_hitbox_down.disabled = true
            attack_hitbox_left.disabled = true
            attack_hitbox_right.disabled = false
        if (direction == Direction.Left):
            attack_hitbox_up.disabled = true
            attack_hitbox_down.disabled = true
            attack_hitbox_left.disabled = false
            attack_hitbox_right.disabled = true
        if (direction == Direction.Up):
            attack_hitbox_up.disabled = false
            attack_hitbox_down.disabled = true
            attack_hitbox_left.disabled = true
            attack_hitbox_right.disabled = true
        if (direction == Direction.Down):
            attack_hitbox_up.disabled = true
            attack_hitbox_down.disabled = false
            attack_hitbox_left.disabled = true
            attack_hitbox_right.disabled = true

func _on_animation_end(animation: String):
    if (animation.begins_with("attack")):
        deactivate_state(PlayerState.Attacking)
    activate_state(PlayerState.Idle)

func activate_state(state: PlayerState):
    if (not has_state(state)):
        active_states.push_back(state)

func deactivate_state(state: PlayerState):
    active_states.erase(state)

func has_state(state: PlayerState):
    return state in active_states

func is_movement_key_being_held_down() -> bool:
    return (
        Input.is_action_pressed("move_up") ||
        Input.is_action_pressed("move_down") ||
        Input.is_action_pressed("move_right") ||
        Input.is_action_pressed("move_left")
    )

func prepare_dodge():
    if (current_stamina < DODGE_COST):
        return
    const TEXTURE_REGION_Y_BASE = 384
    var animation_texture_region_y
    if (direction == Direction.Left):
        animation_player.play("dodge_left")
        animation_texture_region_y = TEXTURE_REGION_Y_BASE
        particle_trail.position = Vector2(48, 50)
    elif (direction == Direction.Right):
        animation_player.play("dodge_right")
        animation_texture_region_y = TEXTURE_REGION_Y_BASE + PLAYER_ANIMATION_FRAME_SIZE
        particle_trail.position = Vector2(52, 50)
    elif (direction == Direction.Down):
        animation_player.play("dodge_face")
        animation_texture_region_y = TEXTURE_REGION_Y_BASE + (PLAYER_ANIMATION_FRAME_SIZE * 2)
        particle_trail.position = Vector2(50, 32)
    elif (direction == Direction.Up):
        animation_player.play("dodge_back")
        animation_texture_region_y = TEXTURE_REGION_Y_BASE + (PLAYER_ANIMATION_FRAME_SIZE * 3)
        particle_trail.position = Vector2(50, 48)
    var _dodge_animation_texture_region = Rect2(
        0,
        animation_texture_region_y,
        PLAYER_ANIMATION_FRAME_SIZE,
        PLAYER_ANIMATION_FRAME_SIZE
    )
    particle_trail.texture.region = _dodge_animation_texture_region
    particle_trail.visible = true
    activate_state(PlayerState.Dodging)
    deactivate_state(PlayerState.Moving)
    deactivate_state(PlayerState.Attacking)
    deactivate_state(PlayerState.Idle)
    position_before_dodge = Vector2(self.position)

    current_stamina -= DODGE_COST

func dodge(dt):
    const MAX_ALLOWED_POSITION_CHANGE = TILE_SIZE * 3
    var movement_key_pressed_modifier = -1 if is_movement_key_being_held_down() else 1

    if (direction == Direction.Left):
        self.position.x += DODGE_SPEED * dt * movement_key_pressed_modifier
    elif (direction == Direction.Right):
        self.position.x -= DODGE_SPEED * dt * movement_key_pressed_modifier
    elif (direction == Direction.Up):
        self.position.y += DODGE_SPEED * dt * movement_key_pressed_modifier
    elif (direction == Direction.Down):
        self.position.y -= DODGE_SPEED * dt * movement_key_pressed_modifier

    var _distance_to_origin = self.position.distance_to(position_before_dodge)

    if (_distance_to_origin >= MAX_ALLOWED_POSITION_CHANGE):
        particle_trail.visible = false
        deactivate_state(PlayerState.Dodging)
        cooldowns.reset_cooldown("player_attack")
        if (direction == Direction.Left):
            self.position = position_before_dodge + Vector2(
                MAX_ALLOWED_POSITION_CHANGE * movement_key_pressed_modifier,
                0.0
            )
        elif (direction == Direction.Right):
            self.position = position_before_dodge + Vector2(
                -MAX_ALLOWED_POSITION_CHANGE * movement_key_pressed_modifier,
                0.0
            )
        elif (direction == Direction.Up):
            self.position = position_before_dodge + Vector2(
                0.0,
                MAX_ALLOWED_POSITION_CHANGE * movement_key_pressed_modifier
            )
        elif (direction == Direction.Down):
            self.position = position_before_dodge + Vector2(
                0.0,
                -MAX_ALLOWED_POSITION_CHANGE * movement_key_pressed_modifier
            )
        animation_player.stop()


func move(dt):
    activate_state(PlayerState.Moving)
    var movementVec = Vector2(0, 0)
    if (direction == Direction.Left):
        movementVec.x = -1 * SPEED * dt
    elif (direction == Direction.Right):
        movementVec.x = SPEED * dt
    elif (direction == Direction.Up):
        movementVec.y = -1 * SPEED * dt
    elif (direction == Direction.Down):
        movementVec.y = SPEED * dt

    move_and_collide(movementVec * dt)

func take_damage(amount: int):
    var health_damage = amount

    if (current_shield > 0):
        current_shield -= amount
        health_damage = current_shield
        if (health_damage < 0):
            current_shield = 0
            health_damage = abs(health_damage)
        else:
            health_damage = 0

    current_health -= health_damage
    if (current_health <= 0):
        get_tree().call_group("main", "show_game_over_screen")
    time_since_last_damage = Time.get_ticks_msec()

func _on_hitbox_area_entered(area):
    if (area.get_parent().name == "Player"):
        return

    if (area.name.begins_with("AttackHitbox")):
        take_damage(area.get_parent().damage)
    # Must be deferred as we can't change physics properties on a physics callback.
    hitbox.set_deferred("disabled", true)
