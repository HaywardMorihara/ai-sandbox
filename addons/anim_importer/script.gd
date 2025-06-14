@tool
extends EditorScript

# AnimData.xml is of the format:
# <AnimData>
# 	<ShadowSize>1</ShadowSize>
# 	<Anims>
# 		<Anim>
# 			<Name>Walk</Name>
# 			<Index>0</Index>
# 			<FrameWidth>40</FrameWidth>
# 			<FrameHeight>40</FrameHeight>
# 			<Durations>
# 				<Duration>4</Duration>
# 				<Duration>4</Duration>
# 				<Duration>4</Duration>
# 				<Duration>4</Duration>
# 				<Duration>4</Duration>
# 				<Duration>4</Duration>
# 			</Durations>
# 		</Anim>

func _run() -> void:
	print("Executing import_anim_data_xml script...")
	
	# Create file dialog to select XML file
	var file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.add_filter("*.xml", "XML Files")
	file_dialog.title = "Select AnimData.xml File"
	file_dialog.size = Vector2(800, 600)
	
	# Connect file selected signal
	file_dialog.file_selected.connect(_on_file_selected)
	
	# Add dialog to scene temporarily
	EditorInterface.get_base_control().add_child(file_dialog)
	file_dialog.popup_centered()
	
	# _on_file_selected("res://assets/sprites/pokemon/bulbasaur/AnimData.xml")

func _on_file_selected(file_path: String) -> void:	
	print("Selected file: " + file_path)
	print("Adding animations to scene: " + get_scene().to_string())
	
	# Parse XML file
	var parser = XMLParser.new()
	var error = parser.open(file_path)
	
	if error != OK:
		printerr("Error opening XML file: ", error)
		return
	
	# Get scene name from file path (pokemon name)
	var scene_name = ""
	var path_parts = file_path.split("/")
	for i in range(path_parts.size()):
		if path_parts[i] == "pokemon" and i + 1 < path_parts.size():
			scene_name = path_parts[i + 1]
			break
	
	if scene_name.is_empty():
		printerr("Could not determine Pokemon name from file path")
		return
	
	# Get current scene
	var root = get_scene()
	if not root:
		printerr("No active scene found")
		return
		
	# Get or create SpriteAnimations node
	var sprite_animations = root.get_node_or_null("SpriteAnimations")
	if sprite_animations:
		print("The SpriteAnimations tree already exists - exiting")
		return
	sprite_animations = Node2D.new()
	sprite_animations.name = "SpriteAnimations"
	root.add_child(sprite_animations)
	sprite_animations.owner = root
	
	# Parse XML for animations
	var anims = []
	var current_anim = null
	var in_anims_section = false
	var in_anim = false
	var in_durations = false
	var current_node_name = ""
	
	while parser.read() == OK:
		var node_type = parser.get_node_type()
		
		if node_type == XMLParser.NODE_ELEMENT:
			current_node_name = parser.get_node_name()
			
			if current_node_name == "Anims":
				in_anims_section = true
			elif current_node_name == "Anim" and in_anims_section:
				in_anim = true
				current_anim = {
					"Name": "",
					"Index": -1,
					"FrameWidth": 0,
					"FrameHeight": 0,
					"Durations": [],
					"CopyOf": "",
					"RushFrame": -1,
					"HitFrame": -1,
					"ReturnFrame": -1
				}
			elif current_node_name == "Durations" and in_anim:
				in_durations = true
			
		elif node_type == XMLParser.NODE_TEXT:
			var text = parser.get_node_data().strip_edges()
			if text.is_empty():
				continue  # Skip empty text nodes
		
			if in_anim and not in_durations:
				if current_node_name == "Name":
					current_anim.Name = text
				elif current_node_name == "Index":
					current_anim.Index = int(text)
				elif current_node_name == "FrameWidth":
					current_anim.FrameWidth = int(text)
				elif current_node_name == "FrameHeight":
					current_anim.FrameHeight = int(text)
				elif current_node_name == "CopyOf":
					current_anim.CopyOf = text
				elif current_node_name == "RushFrame":
					current_anim.RushFrame = int(text)
				elif current_node_name == "HitFrame":
					current_anim.HitFrame = int(text)
				elif current_node_name == "ReturnFrame":
					current_anim.ReturnFrame = int(text)
			elif in_durations and current_node_name == "Duration":
				current_anim.Durations.append(int(text))
				
		elif node_type == XMLParser.NODE_ELEMENT_END:
			var node_name = parser.get_node_name()
			
			if node_name == "Anims":
				in_anims_section = false
			elif node_name == "Anim" and in_anim:
				in_anim = false
				anims.append(current_anim)
				current_anim = null
			elif node_name == "Durations" and in_durations:
				in_durations = false
	
	# Process CopyOf references
	for anim in anims:
		if not anim.CopyOf.is_empty():
			var found = false
			for source_anim in anims:
				if source_anim.Name == anim.CopyOf:
					anim.FrameWidth = source_anim.FrameWidth
					anim.FrameHeight = source_anim.FrameHeight
					anim.Durations = source_anim.Durations.duplicate()
					found = true
					break
			
			if not found:
				printerr("Could not find animation named " + anim.CopyOf + " for CopyOf reference")
	
	# Create animations in scene
	for anim in anims:
		print("Creating animation: %s" % anim)
		if anim.FrameWidth <= 0 or anim.FrameHeight <= 0:
			print("Skipping because Frame Width/Height are invalid")
			continue  # Skip invalid animations
		
		# Check if the animation already exists
		if sprite_animations.has_node(anim.Name):
			print("Skipping because the sprite & animation already exists")
			continue  # Skip existing animations
		
		# Create sprite node
		var sprite = Sprite2D.new()
		sprite.name = anim.Name
		# If the animation contains 'Idle' inits name, make it visible. Otherwise, all other sprites will be hidden by default.
		sprite.visible = anim.Name.to_lower().find("idle") != -1
		sprite_animations.add_child(sprite)
		sprite.owner = root
		
		# Create animation player
		var anim_player = AnimationPlayer.new()
		anim_player.name = "AnimationPlayer"
		sprite.add_child(anim_player)
		anim_player.owner = root
		
		# Set texture path
		var texture_path = "res://assets/sprites/pokemon/" + scene_name + "/" + anim.Name + "-Anim.png"
		var texture = load(texture_path)
		
		if texture:
			sprite.texture = texture
			
			# Calculate frames
			sprite.hframes = texture.get_width() / anim.FrameWidth
			sprite.vframes = texture.get_height() / anim.FrameHeight
			
			var anim_lib = AnimationLibrary.new()
			# Create animations for each direction (row in the sprite sheet)
			for i in range(sprite.vframes):
				# Create animation
				var animation = Animation.new()
				var track_index = animation.add_track(Animation.TYPE_VALUE)
				animation.track_set_path(track_index, ":frame_coords")
				animation.value_track_set_update_mode(track_index, Animation.UPDATE_DISCRETE)
				
				# Set up keyframes
				var time = 0.0
				for j in range(anim.Durations.size()):
					# Convert duration from frames to seconds (assuming 60fps)
					var frame_time = anim.Durations[j] / 60.0
					animation.track_insert_key(track_index, time, Vector2i(j, i))
					time += frame_time
				
				# Set length and looping
				animation.length = time
				# If the anim has rush, hit or return frames, do NOT loop
				if anim.RushFrame != -1 or anim.HitFrame != -1 or anim.ReturnFrame != -1:
					animation.loop_mode = Animation.LOOP_NONE
				else:
					# Otherwise, loop the animation
					animation.loop_mode = Animation.LOOP_LINEAR
				
				# Add to animation player
				# If there are 8 vframes, we can assume that i = 0 is down, i = 1 is down/right, i = 2 is right, i = 3 is up/right, i = 4 is up, i = 5 is up/left, i = 6 is left, i = 7 is down/left
				# Create a unique name for the animation based on the direction
				# and the animation index
				var anim_name
				if sprite.vframes == 8:
					var directions = ["Down", "Down_Right", "Right", "Up_Right", "Up", "Up_Left", "Left", "Down_Left"]
					anim_name = anim.Name + "_" + directions[i]
				else:
					anim_name = anim.Name + "_" + str(i)

				
				anim_lib.add_animation(anim_name, animation)
				print("Added animation %s to the animation library" % anim_name)
			
			anim_player.add_animation_library("", anim_lib)
			anim_player.autoplay = "Idle_Down"
		else:
			printerr("Could not load texture: " + texture_path)
	
	print("Successfully imported animations for " + scene_name)
