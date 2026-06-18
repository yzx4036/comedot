## Command-line runner for LubanConfigNameGenerator.
## Called from gen_code_client.bat after Luban C# / .bytes generation.
## Usage: godot --headless --script res://Scripts/Tools/RunLubanConfigGeneration.gd
extends SceneTree


func _init() -> void:
	print("=== Generating GDScript config constants, typed Row classes, and Loader skeletons ===")
	var success: bool = LubanConfigNameGenerator.generate()
	if success:
		print("=== GDScript generation completed successfully ===")
	else:
		push_error("=== GDScript generation FAILED ===")
	quit(0 if success else 1)
