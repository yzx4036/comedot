@tool
extends EditorScript


func _run() -> void:
	if LubanConfigNameGenerator.generate():
		EditorInterface.get_resource_filesystem().scan()
