extends CanvasLayer


# Called when the node enters the scene tree for the first time.
func _ready():
    $GameOverScreen.visible = false
    $VictoryScreen.visible = false
    $Boss.visible = true
    $Player.visible = true
    pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
    pass

func show_game_over_screen():
    $GameOverScreen.visible = true

func _on_back_to_title_pressed():
    get_tree().call_group("main", "game_over")
