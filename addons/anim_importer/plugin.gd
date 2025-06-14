@tool
extends EditorPlugin

var import_button: Button
var script_instance = preload("res://addons/anim_importer/import_anim_data_xml.gd").new()

func _enter_tree() -> void:
    import_button = Button.new()
    import_button.text = "Import Animation"
    import_button.pressed.connect(_on_import_button_pressed)
    
    # Add to editor toolbar
    add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, import_button)

func _exit_tree() -> void:
    if import_button:
        remove_control_from_container(EditorPlugin.CONTAINER_TOOLBAR, import_button)
        import_button.queue_free()

func _on_import_button_pressed() -> void:
    script_instance._run()