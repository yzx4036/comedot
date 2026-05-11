## Editor-side helper for creating a minimal game project scaffold inside `res://Game/`.
## The generated files follow the current Comedot game-layer boundary: framework files stay outside `Game/`, and game-specific files live under `Game/<ProjectName>/`.

@tool
class_name GameProjectInitializer
extends RefCounted


#region Constants

const gameRootPath := "res://Game"
const defaultProjectFolderName := "MyGame"
const defaultScriptPrefix := "MyGame"

const leafFolders: Array[String] = [
	"Assets/Audio",
	"Assets/Fonts",
	"Assets/Images",
	"Assets/Shaders",
	"Assets/Themes",
	"Components/Combat",
	"Components/Control",
	"Components/Interaction",
	"Components/Movement",
	"Components/UI",
	"Entities/Characters",
	"Entities/Objects",
	"Entities/World",
	"Resources/Actions",
	"Resources/Config",
	"Resources/Items",
	"Resources/Stats",
	"Scenes/Boot",
	"Scenes/Launch",
	"Scenes/Levels",
	"Scenes/Menus",
	"Scenes/Testbeds",
	"Scripts/Boot",
	"Scripts/Gameplay",
	"Scripts/UI",
	"Scripts/Utils",
	"UI/HUD",
	"UI/Menus",
	"UI/Widgets",
	"Tests/Manual",
	"Tests/Regression",
	"Docs",
]

#endregion


#region State

var plugin: EditorPlugin
var dialog: ConfirmationDialog
var resultDialog: AcceptDialog

var projectFolderLineEdit: LineEdit
var titleLineEdit: LineEdit
var scriptPrefixLineEdit: LineEdit
var shouldUpdateOverrideCheckBox: CheckBox

var createdItems: PackedStringArray
var skippedItems: PackedStringArray
var errors: PackedStringArray

#endregion


func _init(editorPlugin: EditorPlugin = null) -> void:
	plugin = editorPlugin


func dispose() -> void:
	if is_instance_valid(dialog):
		dialog.queue_free()
	if is_instance_valid(resultDialog):
		resultDialog.queue_free()

	dialog = null
	resultDialog = null


func showDialog() -> void:
	if not is_instance_valid(dialog):
		createDialog()

	projectFolderLineEdit.text = defaultProjectFolderName
	titleLineEdit.text = defaultProjectFolderName
	scriptPrefixLineEdit.text = defaultScriptPrefix
	shouldUpdateOverrideCheckBox.button_pressed = not FileAccess.file_exists(gameRootPath.path_join("override.cfg"))

	dialog.popup_centered(Vector2i(520, 300))
	projectFolderLineEdit.grab_focus()
	projectFolderLineEdit.select_all()


func createDialog() -> void:
	dialog = ConfirmationDialog.new()
	dialog.title = "Initialize Game Structure"
	dialog.ok_button_text = "Create"
	dialog.dialog_text = "Create the minimal Game/<ProjectName>/ folder structure and starter scenes."
	dialog.confirmed.connect(onDialog_confirmed)

	var fieldsContainer: GridContainer = GridContainer.new()
	fieldsContainer.columns = 2
	fieldsContainer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialog.add_child(fieldsContainer)

	addLabel(fieldsContainer, "Project Folder")
	projectFolderLineEdit = LineEdit.new()
	projectFolderLineEdit.placeholder_text = defaultProjectFolderName
	projectFolderLineEdit.text_changed.connect(onProjectFolder_textChanged)
	fieldsContainer.add_child(projectFolderLineEdit)

	addLabel(fieldsContainer, "Project Title")
	titleLineEdit = LineEdit.new()
	titleLineEdit.placeholder_text = defaultProjectFolderName
	fieldsContainer.add_child(titleLineEdit)

	addLabel(fieldsContainer, "Script Prefix")
	scriptPrefixLineEdit = LineEdit.new()
	scriptPrefixLineEdit.placeholder_text = defaultScriptPrefix
	fieldsContainer.add_child(scriptPrefixLineEdit)

	var spacer: Control = Control.new()
	fieldsContainer.add_child(spacer)

	shouldUpdateOverrideCheckBox = CheckBox.new()
	shouldUpdateOverrideCheckBox.text = "Set Game/override.cfg as the active boot scene"
	shouldUpdateOverrideCheckBox.tooltip_text = "Writes res://Game/override.cfg. Existing game project files under Game/<ProjectName>/ are never overwritten."
	fieldsContainer.add_child(shouldUpdateOverrideCheckBox)

	EditorInterface.get_base_control().add_child(dialog)


func addLabel(parent: Control, text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	parent.add_child(label)


func onProjectFolder_textChanged(newText: String) -> void:
	if titleLineEdit.text.is_empty() or titleLineEdit.text == defaultProjectFolderName:
		titleLineEdit.text = newText

	if scriptPrefixLineEdit.text.is_empty() or scriptPrefixLineEdit.text == defaultScriptPrefix:
		scriptPrefixLineEdit.text = sanitizeScriptPrefix(newText)


func onDialog_confirmed() -> void:
	initializeProject(
		projectFolderLineEdit.text.strip_edges(),
		titleLineEdit.text.strip_edges(),
		scriptPrefixLineEdit.text.strip_edges(),
		shouldUpdateOverrideCheckBox.button_pressed,
	)


func initializeProject(projectFolderName: String, projectTitle: String, scriptPrefix: String, shouldUpdateOverride: bool) -> void:
	createdItems.clear()
	skippedItems.clear()
	errors.clear()

	if not validateInputs(projectFolderName, scriptTitleOrFallback(projectTitle, projectFolderName), scriptPrefix):
		showResultDialog()
		return

	var title: String = scriptTitleOrFallback(projectTitle, projectFolderName)
	var projectRootPath: String = gameRootPath.path_join(projectFolderName)
	var bootScenePath: String = projectRootPath.path_join("Scenes/Boot").path_join(scriptPrefix + "Start.tscn")
	var mainScenePath: String = projectRootPath.path_join("Scenes/Levels").path_join(scriptPrefix + "Main.tscn")
	var bootScriptPath: String = projectRootPath.path_join("Scripts/Boot").path_join(scriptPrefix + "Start.gd")

	createDirectory(gameRootPath)
	createDirectory(projectRootPath)

	for folder in leafFolders:
		var fullFolderPath: String = projectRootPath.path_join(folder)
		createDirectory(fullFolderPath)
		createFileIfMissing(fullFolderPath.path_join(".gitkeep"), "")

	createFileIfMissing(projectRootPath.path_join("README.md"), createProjectReadme(projectFolderName, title))
	createFileIfMissing(projectRootPath.path_join("Docs/README.md"), createDocsReadme(projectFolderName))
	createFileIfMissing(bootScriptPath, createBootScript(title))
	createFileIfMissing(bootScenePath, createBootScene(projectFolderName, title, scriptPrefix, bootScriptPath, mainScenePath))
	createFileIfMissing(mainScenePath, createMainScene(projectFolderName, title, scriptPrefix))

	if shouldUpdateOverride:
		writeFile(gameRootPath.path_join("override.cfg"), createOverrideConfig(title, bootScenePath), true)

	refreshEditorFileSystem()
	showResultDialog(projectRootPath)


func validateInputs(projectFolderName: String, projectTitle: String, scriptPrefix: String) -> bool:
	var isValid: bool = true

	if projectFolderName.is_empty():
		errors.append("Project Folder is required.")
		isValid = false
	elif not projectFolderName.is_valid_filename() or projectFolderName.contains("/") or projectFolderName.contains("\\"):
		errors.append("Project Folder must be a single valid folder name.")
		isValid = false

	if projectTitle.is_empty():
		errors.append("Project Title is required.")
		isValid = false

	if scriptPrefix.is_empty():
		errors.append("Script Prefix is required.")
		isValid = false
	elif not scriptPrefix.is_valid_identifier():
		errors.append("Script Prefix must be a valid GDScript identifier, such as MyGame or GP.")
		isValid = false

	return isValid


func scriptTitleOrFallback(projectTitle: String, projectFolderName: String) -> String:
	return projectFolderName if projectTitle.is_empty() else projectTitle


func sanitizeScriptPrefix(text: String) -> String:
	var result: String
	var shouldCapitalizeNext: bool = true

	for characterIndex in text.length():
		var character: String = text.substr(characterIndex, 1)
		var isLetter: bool = (character >= "a" and character <= "z") or (character >= "A" and character <= "Z")
		var isDigit: bool = character >= "0" and character <= "9"

		if isLetter or isDigit:
			if result.is_empty() and isDigit:
				result += defaultScriptPrefix
			result += character.to_upper() if shouldCapitalizeNext else character
			shouldCapitalizeNext = false
		else:
			shouldCapitalizeNext = true

	return defaultScriptPrefix if result.is_empty() else result


func createDirectory(path: String) -> bool:
	if DirAccess.dir_exists_absolute(path):
		skippedItems.append(path)
		return true

	var result: Error = DirAccess.make_dir_recursive_absolute(path)
	if result != OK:
		errors.append("Could not create directory: " + path + " (" + error_string(result) + ")")
		return false

	createdItems.append(path)
	return true


func createFileIfMissing(path: String, contents: String) -> bool:
	if FileAccess.file_exists(path):
		skippedItems.append(path)
		return true

	return writeFile(path, contents, false)


func writeFile(path: String, contents: String, shouldOverwrite: bool) -> bool:
	if FileAccess.file_exists(path) and not shouldOverwrite:
		skippedItems.append(path)
		return true

	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		errors.append("Could not write file: " + path + " (" + error_string(FileAccess.get_open_error()) + ")")
		return false

	file.store_string(contents)
	file.close()
	createdItems.append(path)
	return true


func refreshEditorFileSystem() -> void:
	var fileSystem: EditorFileSystem = EditorInterface.get_resource_filesystem()
	if fileSystem:
		fileSystem.scan()


func showResultDialog(projectRootPath: String = "") -> void:
	if not is_instance_valid(resultDialog):
		resultDialog = AcceptDialog.new()
		resultDialog.title = "Game Structure Initialization"
		EditorInterface.get_base_control().add_child(resultDialog)

	var messageLines: PackedStringArray

	if errors.is_empty():
		messageLines.append("Initialized: " + projectRootPath)
		messageLines.append(str("Created/updated: ", createdItems.size()))
		messageLines.append(str("Already existed: ", skippedItems.size()))
	else:
		messageLines.append("Initialization failed.")
		messageLines.append_array(errors)

	resultDialog.dialog_text = "\n".join(messageLines)
	resultDialog.popup_centered(Vector2i(520, 220))

	if errors.is_empty():
		ComedotPlugin.printLog(messageLines[0])
	else:
		for error in errors:
			ComedotPlugin.printError(error)


func quoteString(value: String) -> String:
	return value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n")


func createProjectReadme(projectFolderName: String, title: String) -> String:
	return "# " + title + "\n\n" \
		+ "Game-specific files for `" + projectFolderName + "` live here.\n\n" \
		+ "Keep reusable framework code outside `Game/`, and keep project-specific assets, scenes, scripts, UI, resources, tests, and docs under this folder.\n"


func createDocsReadme(projectFolderName: String) -> String:
	return "# Docs\n\n" \
		+ "Project notes and design documents for `Game/" + projectFolderName + "/`.\n"


func createBootScript(title: String) -> String:
	return "## Minimal starter boot scene for a game living inside `Game/`.\n" \
		+ "## This keeps the framework boot isolated from game content and points `GameState.startMainScene()` to the real playable scene.\n\n" \
		+ "extends Start\n\n\n" \
		+ "@export var titleText: String = \"" + quoteString(title) + "\"\n\n" \
		+ "@onready var titleLabel: Label = $MarginContainer/VBoxContainer/TitleLabel\n" \
		+ "@onready var startButton: Button = $MarginContainer/VBoxContainer/StartButton\n\n\n" \
		+ "func _ready() -> void:\n" \
		+ "\tsuper._ready()\n" \
		+ "\ttitleLabel.text = titleText\n" \
		+ "\tstartButton.pressed.connect(GameState.startMainScene)\n" \
		+ "\tGlobalInput.isPauseShortcutAllowed = false\n"


func createBootScene(projectFolderName: String, title: String, scriptPrefix: String, bootScriptPath: String, mainScenePath: String) -> String:
	return "[gd_scene format=3]\n\n" \
		+ "[ext_resource type=\"Script\" path=\"" + bootScriptPath + "\" id=\"1_start\"]\n" \
		+ "[ext_resource type=\"Theme\" path=\"res://Assets/Themes/Comedot Default.tres\" id=\"2_theme\"]\n\n" \
		+ "[node name=\"" + scriptPrefix + "Start\" type=\"Control\"]\n" \
		+ "layout_mode = 3\n" \
		+ "anchors_preset = 15\n" \
		+ "anchor_right = 1.0\n" \
		+ "anchor_bottom = 1.0\n" \
		+ "grow_horizontal = 2\n" \
		+ "grow_vertical = 2\n" \
		+ "script = ExtResource(\"1_start\")\n" \
		+ "mainGameScenePath = \"" + mainScenePath + "\"\n" \
		+ "titleText = \"" + quoteString(title) + "\"\n\n" \
		+ "[node name=\"ColorRect\" type=\"ColorRect\" parent=\".\"]\n" \
		+ "layout_mode = 1\n" \
		+ "anchors_preset = 15\n" \
		+ "anchor_right = 1.0\n" \
		+ "anchor_bottom = 1.0\n" \
		+ "grow_horizontal = 2\n" \
		+ "grow_vertical = 2\n" \
		+ "color = Color(0.0666667, 0.0588235, 0.109804, 1)\n\n" \
		+ "[node name=\"MarginContainer\" type=\"MarginContainer\" parent=\".\"]\n" \
		+ "layout_mode = 1\n" \
		+ "anchors_preset = 15\n" \
		+ "anchor_right = 1.0\n" \
		+ "anchor_bottom = 1.0\n" \
		+ "grow_horizontal = 2\n" \
		+ "grow_vertical = 2\n" \
		+ "theme = ExtResource(\"2_theme\")\n" \
		+ "theme_override_constants/margin_left = 16\n" \
		+ "theme_override_constants/margin_top = 16\n" \
		+ "theme_override_constants/margin_right = 16\n" \
		+ "theme_override_constants/margin_bottom = 16\n\n" \
		+ "[node name=\"VBoxContainer\" type=\"VBoxContainer\" parent=\"MarginContainer\"]\n" \
		+ "layout_mode = 2\n" \
		+ "size_flags_horizontal = 4\n" \
		+ "size_flags_vertical = 4\n" \
		+ "theme_override_constants/separation = 8\n\n" \
		+ "[node name=\"TitleLabel\" type=\"Label\" parent=\"MarginContainer/VBoxContainer\"]\n" \
		+ "layout_mode = 2\n" \
		+ "size_flags_horizontal = 4\n" \
		+ "text = \"" + quoteString(title) + "\"\n" \
		+ "horizontal_alignment = 1\n\n" \
		+ "[node name=\"DescriptionLabel\" type=\"Label\" parent=\"MarginContainer/VBoxContainer\"]\n" \
		+ "layout_mode = 2\n" \
		+ "size_flags_horizontal = 4\n" \
		+ "text = \"Starter boot scene inside Game/" + quoteString(projectFolderName) + ".\\nPress Start to load the playable scene.\"\n" \
		+ "horizontal_alignment = 1\n\n" \
		+ "[node name=\"StartButton\" type=\"Button\" parent=\"MarginContainer/VBoxContainer\"]\n" \
		+ "layout_mode = 2\n" \
		+ "size_flags_horizontal = 4\n" \
		+ "text = \"Start\"\n"


func createMainScene(projectFolderName: String, title: String, scriptPrefix: String) -> String:
	return "[gd_scene format=3]\n\n" \
		+ "[ext_resource type=\"Theme\" path=\"res://Assets/Themes/Comedot Default.tres\" id=\"1_theme\"]\n\n" \
		+ "[node name=\"" + scriptPrefix + "Main\" type=\"Node2D\"]\n\n" \
		+ "[node name=\"CanvasLayer\" type=\"CanvasLayer\" parent=\".\"]\n\n" \
		+ "[node name=\"MarginContainer\" type=\"MarginContainer\" parent=\"CanvasLayer\"]\n" \
		+ "anchors_preset = -1\n" \
		+ "anchor_right = 1.0\n" \
		+ "anchor_bottom = 1.0\n" \
		+ "grow_horizontal = 2\n" \
		+ "grow_vertical = 2\n" \
		+ "theme = ExtResource(\"1_theme\")\n" \
		+ "theme_override_constants/margin_left = 16\n" \
		+ "theme_override_constants/margin_top = 16\n" \
		+ "theme_override_constants/margin_right = 16\n" \
		+ "theme_override_constants/margin_bottom = 16\n\n" \
		+ "[node name=\"VBoxContainer\" type=\"VBoxContainer\" parent=\"CanvasLayer/MarginContainer\"]\n" \
		+ "layout_mode = 2\n" \
		+ "size_flags_horizontal = 4\n" \
		+ "size_flags_vertical = 4\n" \
		+ "theme_override_constants/separation = 8\n\n" \
		+ "[node name=\"TitleLabel\" type=\"Label\" parent=\"CanvasLayer/MarginContainer/VBoxContainer\"]\n" \
		+ "layout_mode = 2\n" \
		+ "size_flags_horizontal = 4\n" \
		+ "text = \"" + quoteString(title) + " Main Scene\"\n" \
		+ "horizontal_alignment = 1\n\n" \
		+ "[node name=\"HintLabel\" type=\"Label\" parent=\"CanvasLayer/MarginContainer/VBoxContainer\"]\n" \
		+ "layout_mode = 2\n" \
		+ "text = \"Replace this scene with real gameplay, or start adding entities and components under Game/" + quoteString(projectFolderName) + ".\"\n" \
		+ "horizontal_alignment = 1\n" \
		+ "autowrap_mode = 1\n"


func createOverrideConfig(title: String, bootScenePath: String) -> String:
	return "; Game-local project setting overrides.\n" \
		+ "; Keep this file at Game/ root because project.godot points to res://Game/override.cfg\n\n" \
		+ "[application]\n" \
		+ "config/name=\"" + quoteString(title) + "\"\n" \
		+ "run/main_scene=\"" + bootScenePath + "\"\n"
