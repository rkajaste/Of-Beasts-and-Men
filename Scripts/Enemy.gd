extends CharacterBody2D

class_name Enemy

enum Direction {
    Up,
    Down,
    Left,
    Right
}

enum EnemyState {
    ChargingForward,
    FinishedAttacking,
    Attacking,
    Casting,
    Moving,
    Idle
}

const INVINCIBILITY_TIME_MS = 1000
var _time_since_last_damage = 0
var max_health = 20
var current_health = 20

var ATTACK_DISTANCE = 100
var WAIT_TIME_BEFORE_ACTIONS_IN_MS = 200

var damage = 8
var _animation_player
var _cooldowns
var _sprite
var _hitbox
var _health_bar

var player_position

var _active_states = [EnemyState.Idle]
var _direction
var _position_last_frame
var _time_since_last_action = Time.get_ticks_msec()
var player_node

func _ready():
    _position_last_frame = self.position
    _health_bar.max_value = max_health
    player_node = get_parent().get_children()[3]
    _animation_player.animation_finished.connect(_on_animation_end)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(dt):
    _animate()
    if (not _has_state(EnemyState.Attacking)):
        player_position = player_node.position

    if (Time.get_ticks_msec() - _time_since_last_damage >= INVINCIBILITY_TIME_MS):
        _hitbox.disabled = false

    if (self.position.distance_to(player_position) < ATTACK_DISTANCE):
        if (_has_state(EnemyState.Moving)): # when enemy stops tracking player
            _time_since_last_action = Time.get_ticks_msec()
        _deactivate_state(EnemyState.Moving)
        if (is_allowed_to_do_action()):
            attack()
            _time_since_last_action = Time.get_ticks_msec()
    else:
        if (is_allowed_to_do_action()):
            run_towards_player(player_position, dt)

    _update_status_bar()

func _update_status_bar():
    _health_bar.value = current_health

func is_allowed_to_do_action():
    return Time.get_ticks_msec() - _time_since_last_action >= WAIT_TIME_BEFORE_ACTIONS_IN_MS

func run_towards_player(player_position, dt):
    _activate_state(EnemyState.Moving)
    self.position = self.position.lerp(player_position, 1.0 * dt)
    var position_diff: Vector2 = _position_last_frame - self.position

    if (abs(position_diff.x) > abs(position_diff.y)):
        if (position_diff.x < 0):
            _direction = Direction.Right
        else:
            _direction = Direction.Left
    else:
        if (position_diff.y > 0):
            _direction = Direction.Down
        else:
            _direction = Direction.Up

    _position_last_frame = self.position

func attack() -> void:
    print("Enemy Attack, implement me!")


func _on_animation_end(animation: String):
    _activate_state(EnemyState.Idle)


func _animate():
    var animation_suffix = "_horizontal"

    if ([Direction.Left, Direction.Right].has(_direction)):
        _sprite.scale.x = -1 if _direction == Direction.Left else 1
        animation_suffix = "_horizontal"
    elif (_direction == Direction.Up):
        animation_suffix = "_back"
    elif (_direction == Direction.Down):
        animation_suffix = "_face"

    if (_has_state(EnemyState.Moving) and not _has_state(EnemyState.Attacking)):
        _animation_player.play("walk" + animation_suffix)
    elif (_has_state(EnemyState.Attacking)):
        _animation_player.play("attack" + animation_suffix)
        _animation_player.advance(0)
    else:
        _animation_player.play("idle" + animation_suffix)
        _animation_player.advance(0)

func _activate_state(state: EnemyState):
    if (not _has_state(state)):
        _active_states.push_back(state)

func _deactivate_state(state: EnemyState):
    _active_states.erase(state)

func _has_state(state: EnemyState):
    return state in _active_states

func die():
    queue_free()

func take_damage(amount: int):
    current_health -= amount
    _time_since_last_damage = Time.get_ticks_msec()
    # Must be deferred as we can't change physics properties on a physics callback.
    _hitbox.set_deferred("disabled", true)

    if (current_health <= 0):
        die()



