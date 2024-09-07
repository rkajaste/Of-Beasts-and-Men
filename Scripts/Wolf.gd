extends Enemy

const ATTACK_TIME_MS = 500

var position_before_attack
var time_before_attack
var _attack_hitbox

# Called when the node enters the scene tree for the first time.
func _ready():
    _animation_player = $AnimationPlayer
    _cooldowns = $Cooldowns
    _sprite = $Sprite2D
    _attack_hitbox = $AttackHitbox/Bite
    _hitbox = $Hitbox/Body
    _health_bar = $Health
    max_health = 40
    current_health = 40
    position_before_attack = self.position
    super._ready()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(dt):
    super._process(dt)

    if (not _has_state(EnemyState.Attacking)):
        _attack_hitbox.disabled = true
    if (_has_state(EnemyState.Attacking) and not _has_state(EnemyState.FinishedAttacking)):
        self.position = self.position.lerp(player_position, 4.0 * dt)
        if (self.position.distance_to(player_position) <= 20):
            _activate_state(EnemyState.FinishedAttacking)
    if (_has_state(EnemyState.FinishedAttacking) and Time.get_ticks_msec() - time_before_attack >= ATTACK_TIME_MS):
        self.position = position_before_attack
        _deactivate_state(EnemyState.Attacking)
        _deactivate_state(EnemyState.FinishedAttacking)
        _attack_hitbox.disabled = true

func attack():
    if (not _cooldowns.has_cooldown("wolf_attack")):
        position_before_attack = self.position
        time_before_attack = Time.get_ticks_msec()
        _activate_state(EnemyState.Attacking)
        _deactivate_state(EnemyState.Moving)
        _deactivate_state(EnemyState.Idle)
        _cooldowns.set_on_cooldown("wolf_attack")

        if (_direction == Direction.Left):
            _attack_hitbox.disabled = false
        elif (_direction == Direction.Right):
            _attack_hitbox.disabled = false
    else:
        _activate_state(EnemyState.Idle)


func _on_hitbox_area_entered(area):
    if (area.get_parent().name != "Player"):
        return

    var player = area.get_parent()
    if (area.name.begins_with("AttackHitbox")):
        take_damage(player.damage)

        if (player.current_transformation == player.Transformation.Bat):
            player.heal()
        elif (player.current_transformation == player.Transformation.None):
            player.increase_transformation_gauge()
