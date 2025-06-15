extends CharacterBody2D

@export var speed := 100

@onready var animation_player = $AnimationPlayer

const CLOSE_ENOUGH := 5
# This array maps a direction index (0-7) to your specific animation names.
# 0 = East, 1 = Northeast, 2 = North, etc. Adjust the names to match your project.
const DIRECTION_MAP = [
	"Right", "Down_Right", "Down", "Down_Left",
	"Left", "Up_Left", "Up", "Up_Right",
]

var current_dir := "Down"
var destination : Vector2

func _ready() -> void:
	PlayerInput.move_command_issued.connect(_on_move_command_issued)

func _physics_process(delta: float) -> void:
	if destination:
		if position.distance_to(destination) < CLOSE_ENOUGH:  # Close enough to stop
			destination = Vector2.ZERO
			velocity = Vector2.ZERO
		else:
			var direction = (destination - position).normalized()
			velocity = speed * direction
	
	move_and_slide()
	
	update_animation()

func update_animation():
	# First, check if we are moving. If not, play "idle".
	# Use a small threshold to avoid stopping due to tiny velocity values.
	if velocity.length() < 1.0:
		# If current_animation is a string of the format "Idle/<DIRECTION>"
		if not animation_player.current_animation.begins_with("Idle/"): 
			animation_player.play("Idle/%s" % current_dir)
		return
	# If we are moving, calculate the direction index from 0 to 7.
	# We add 22.5 degrees to offset the slices, so "East" (0 degrees) is in the middle of a slice.
	var angle = rad_to_deg(velocity.angle()) + 22.5
	if angle < 0:
		angle += 360 # Ensure angle is positive
	
	var direction_index = int(angle / 45) % 8
	# Get the correct animation name from our map.
	var new_animation = "Walk/%s" % DIRECTION_MAP[direction_index]
	# Only play the new animation if it's different from the current one.
	if animation_player.current_animation != new_animation:
		current_dir = DIRECTION_MAP[direction_index]
		animation_player.play(new_animation)

func _on_move_command_issued(new_destination: Vector2):
	self.destination = new_destination
