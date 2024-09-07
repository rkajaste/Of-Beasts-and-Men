extends CanvasLayer


# Called when the node enters the scene tree for the first time.
func _ready():
    pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(dt):
    pass


func navigate_to_tutorial():
    $TitleScreen.visible = false
    $Tutorial.visible = true
    navigate_to_powers_tutorial()

func navigate_to_main_menu():
    $TitleScreen.visible = true
    $Tutorial.visible = false

func navigate_to_powers_tutorial():
    $Tutorial/Powers.visible = true
    $Tutorial/Controls.visible = false

func navigate_to_controls_tutorial():
    $Tutorial/Powers.visible = false
    $Tutorial/Controls.visible = true

func _on_new_game_pressed():
    get_tree().call_group("main", "new_game")
    queue_free()

func _on_tutorial_pressed():
    navigate_to_tutorial()

func _on_to_main_menu_pressed():
    navigate_to_main_menu()

func _on_to_controls_pressed():
    navigate_to_controls_tutorial()

func _on_to_powers_pressed():
    navigate_to_powers_tutorial()
