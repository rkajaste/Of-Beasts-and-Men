extends Node
@export var mob_scene: PackedScene
@export var tilemap_scene: PackedScene
@export var boss_scene: PackedScene

var hud_scene = load("res://Scenes/hud.tscn")
var main_menu_scene = preload("res://Scenes/main_menu.tscn")
var player_scene = preload("res://Scenes/player.tscn")
var main_menu

# Called when the node enters the scene tree for the first time.
func _ready():
    go_to_main_menu()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
    pass

func set_camera_limits():
    var map_limits = $Grasslands.get_used_rect()
    var map_cellsize = $Grasslands.tile_set.tile_size
    $Player/Camera2D.limit_left = map_limits.position.x * map_cellsize.x
    $Player/Camera2D.limit_right = map_limits.end.x * map_cellsize.x
    $Player/Camera2D.limit_top = map_limits.position.y * map_cellsize.y
    $Player/Camera2D.limit_bottom = map_limits.end.y * map_cellsize.y

func go_to_main_menu():
    main_menu = main_menu_scene.instantiate()
    add_child(main_menu)

func new_game():
    # deletes all enemies in group "mobs"
    get_tree().call_group("mobs", "queue_free")
    var tilemap = tilemap_scene.instantiate()
    var boss = boss_scene.instantiate()
    var hud = hud_scene.instantiate()
    var player = player_scene.instantiate()

    add_child(tilemap)
    add_child(hud)
    add_child(player)
    add_child(boss)
    player.spawn(tilemap.find_child("PlayerSpawn").position)
    boss.spawn(tilemap.find_child("BossSpawn").position)
    $MobWaveTimer.start()
    set_camera_limits()

func win_game():
    $MobWaveTimer.stop()
    $HUD.find_child("Player").visible = false
    get_tree().call_group("mobs", "queue_free")
    $HUD.find_child("VictoryScreen").visible = true
    $HUD.find_child("Boss").visible = false

func show_game_over_screen():
    $HUD.find_child("Boss").visible = false
    $HUD.find_child("Player").visible = false
    $MobWaveTimer.stop()
    get_tree().call_group("mobs", "queue_free")
    $Player.visible = false
    $Werewolf.visible = false
    $Grasslands.visible = false
    $HUD.find_child("GameOverScreen").visible = true

func game_over():
    $HUD.queue_free()
    $Player.queue_free()
    get_tree().call_group("mobs", "queue_free")
    $Grasslands.queue_free()
    go_to_main_menu()

func update_boss_hp(current_hp, max_hp):
    var boss_hp_bar = $HUD.find_child("Boss").find_child("Health")
    boss_hp_bar.max_value = max_hp
    boss_hp_bar.value = current_hp

func spawn_mob():
    # Create a new instance of the Mob scene.
    var mob = mob_scene.instantiate()

    # Choose a random location on Path2D.
    var mob_spawn_location = $Player/Camera2D/EnemyPath/EnemySpawn
    mob_spawn_location.progress_ratio = randf()

    # Set the mob's direction perpendicular to the path direction.
    var direction = mob_spawn_location.rotation + PI / 2

    # Set the mob's position to a random location.
    mob.position = mob_spawn_location.position

    # Spawn the mob by adding it to the Main scene.
    add_child(mob)


func _on_mob_wave_timer_timeout():
    if ($Player != null):
        spawn_mob()
        spawn_mob()
        spawn_mob()

