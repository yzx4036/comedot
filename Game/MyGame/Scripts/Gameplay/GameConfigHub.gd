extends Node

## 全项目唯一的 Luban 配置服务持有者（autoload）。
##
## 为什么必须唯一：
##   Luban 生成的表类（`TbExampleBasic.Instance` 等）是 **C# 静态单例**。
##   同一进程里 new 第二个 `LubanConfigService` 会报
##   `singleton register twice! TbExampleBasic` 并整体加载失败。
##   ⇒ 任何场景都不能各自 new 一个，必须从这里取。
##
## 用法：
##   var service: Node = GameConfigHub.getService()
##   var config := GameConfig.new(service)
##
## 未编译 C# 时 getService() 返回 null 并打印原因（不会抛异常）。

const logName: String = "GameConfigHub"

const SERVICE_SCRIPT: String = "res://Scripts/Mono/Luban/LubanConfigService.cs"
const CONFIG_DIR: String = "res://Assets/Configs/GameConfigs"

## 持有唯一实例的组名（老代码/外部脚本靠 group 查找，避免依赖本 autoload 的名字）
const SERVICE_GROUP: StringName = &"lubanConfigService"

var _service: Node


func _ready() -> void:
	# 交给场景自行决定何时需要；这里只做「首次使用时才加载」，避免拖慢启动
	pass


## 返回唯一的配置服务节点；不可用时返回 null 并打印原因
func getService() -> Node:
	if is_instance_valid(_service):
		return _service

	# 场景里可能已经有别人放好的（比如热重载），优先复用
	for node in get_tree().get_nodes_in_group(SERVICE_GROUP):
		if node is Node and is_instance_valid(node):
			_service = node
			return _service

	var script: Script = load(SERVICE_SCRIPT)
	if script == null:
		push_error(str(logName, ": C# 未编译，无法加载配置表（先 dotnet build）"))
		return null

	var service: Node = script.new()
	service.name = "LubanConfigService"
	service.ConfigDirectory = CONFIG_DIR
	service.LoadOnReady = true
	service.add_to_group(SERVICE_GROUP)
	add_child(service)

	if not ("IsLoaded" in service) or not service.IsLoaded:
		push_error(str(logName, ": 配置表加载失败: ", CONFIG_DIR))
		return null

	_service = service
	return _service


## 是否已经能提供服务（不触发加载）
func hasService() -> bool:
	return is_instance_valid(_service)


## 重载配置表（改表后热应用；仍复用同一实例，不会触发「单例重复注册」）
func reload() -> bool:
	var service: Node = getService()
	if service == null:
		return false
	return bool(service.call("ReloadConfigs"))
