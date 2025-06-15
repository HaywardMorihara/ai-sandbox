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
		

	# Get or create single Sprite2D and AnimationPlayer
	var sprite = root.get_node_or_null("Sprite2D")
	if not sprite:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		root.add_child(sprite)
		sprite.owner = root

	var anim_player = root.get_node_or_null("AnimationPlayer")
	if not anim_player:
		anim_player = AnimationPlayer.new()
		anim_player.name = "AnimationPlayer"
		root.add_child(anim_player)
		anim_player.owner = root

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
	
	var default_texture : Texture
	for anim in anims:
		var texture_name = anim.Name
		if not anim.CopyOf.is_empty():
			texture_name = anim.CopyOf
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
		
		if anim.FrameWidth <= 0 or anim.FrameHeight <= 0:
			continue

		var texture_path = "res://assets/sprites/pokemon/" + scene_name + "/" + texture_name + "-Anim.png"
		var texture = load(texture_path)
		if not texture:
			printerr("Could not load texture: " + texture_path)
			continue
		if anim.Name == "Idle":
			default_texture = texture

		# Calculate frames
		var hframes = texture.get_width() / anim.FrameWidth
		var vframes = texture.get_height() / anim.FrameHeight

		var anim_lib = AnimationLibrary.new()
		for i in range(vframes):
			var animation = Animation.new()
			# Track 0: Set texture at time 0
			var tex_track = animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_path(tex_track, NodePath("Sprite2D:texture"))
			animation.value_track_set_update_mode(tex_track, Animation.UPDATE_DISCRETE)
			animation.track_insert_key(tex_track, 0.0, texture)

			# Track 1: Set the hframes & vframes
			var hframes_track = animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_path(hframes_track, NodePath("Sprite2D:hframes"))
			animation.value_track_set_update_mode(hframes_track, Animation.UPDATE_DISCRETE)
			animation.track_insert_key(hframes_track, 0.0, hframes)
			var vframes_track = animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_path(vframes_track, NodePath("Sprite2D:vframes"))
			animation.value_track_set_update_mode(vframes_track, Animation.UPDATE_DISCRETE)
			animation.track_insert_key(vframes_track, 0.0, vframes)

			# Track 3: Animate frame_coords
			var frame_track = animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_path(frame_track, NodePath("Sprite2D:frame_coords"))
			animation.value_track_set_update_mode(frame_track, Animation.UPDATE_DISCRETE)

			var time = 0.0
			for j in range(anim.Durations.size()):
				var frame_time = anim.Durations[j] / 60.0
				animation.track_insert_key(frame_track, time, Vector2i(j, i))
				time += frame_time

			animation.length = time
			if anim.RushFrame != -1 or anim.HitFrame != -1 or anim.ReturnFrame != -1:
				animation.loop_mode = Animation.LOOP_NONE
			else:
				animation.loop_mode = Animation.LOOP_LINEAR

			var anim_name = anim.Name
			if vframes == 8:
				var directions = ["Down", "Down_Right", "Right", "Up_Right", "Up", "Up_Left", "Left", "Down_Left"]
				anim_name = directions[i]
			elif vframes > 1:
				anim_name = str(i)

			anim_lib.add_animation(anim_name, animation)
		anim_player.add_animation_library(anim.Name, anim_lib)
	
	sprite.texture = default_texture
	anim_player.autoplay = "Idle/Down"

	print("Successfully imported all animations into a single Sprite2D and AnimationPlayer.")
