extends Node2D

@export var speed := 100

var CLOSE_ENOUGH := 5

var destination : Vector2

func _ready() -> void:
	PlayerInput.move_command_issued.connect(_on_move_command_issued)

func _physics_process(delta: float) -> void:
	if destination:
		var direction = (destination - position).normalized()
		position += direction * speed * delta  # Move at 100 pixels per second
		if position.distance_to(destination) < CLOSE_ENOUGH:  # Close enough to stop
			destination = Vector2.ZERO  # Reset destination

	# If bulbasaur is moving, update the animation
	
	

func _on_move_command_issued(new_destination: Vector2):
	self.destination = new_destination
