## GDScript facade for [LubanConfigService].
## Game scripts should use this wrapper instead of hand-writing C# method names.

class_name Tb
extends RefCounted

const loadMethod: StringName = &"LoadConfigs"
const reloadMethod: StringName = &"ReloadConfigs"
const unloadMethod: StringName = &"UnloadConfigs"
const namesMethod: StringName = &"GetConfigNames"
const hasTableMethod: StringName = &"HasTable"
const hasRecordMethod: StringName = &"HasRecord"
const modeMethod: StringName = &"GetTableMode"
const validateRecordMethod: StringName = &"ValidateRecord"
const recordMethod: StringName = &"GetRecord"
const recordsMethod: StringName = &"GetRecords"
const valueMethod: StringName = &"GetValue"
const oneMethod: StringName = &"GetSingleton"
const oneValueMethod: StringName = &"GetSingletonValue"

var service: Node


func _init(configService: Node = null) -> void:
	service = configService


func bind(configService: Node) -> RefCounted:
	service = configService
	return self


func load() -> bool:
	if not hasService(): return false
	return bool(service.call(loadMethod))


func reload() -> bool:
	if not hasService(): return false
	return bool(service.call(reloadMethod))


func unload() -> void:
	if not hasService(): return
	service.call(unloadMethod)


func names() -> Array:
	if not hasService(): return []
	var result: Variant = service.call(namesMethod)
	if result is Array:
		return result
	return []


func has(configName: StringName) -> bool:
	if not hasService(): return false
	return bool(service.call(hasTableMethod, configName))


func hasId(configName: StringName, key: Variant) -> bool:
	if not hasService(): return false
	return bool(service.call(hasRecordMethod, configName, key))


func mode(configName: StringName) -> String:
	if not hasService(): return ""
	return str(service.call(modeMethod, configName))


func check(configName: StringName, key: Variant, requiredFields: Array = []) -> Dictionary:
	if not hasService(): return {}
	var result: Variant = service.call(validateRecordMethod, configName, key, requiredFields)
	if result is Dictionary:
		return result
	return {}


func row(configName: StringName, key: Variant) -> Dictionary:
	if not hasService(): return {}
	var result: Variant = service.call(recordMethod, configName, key)
	if result is Dictionary:
		return result
	return {}


func rows(configName: StringName) -> Array:
	if not hasService(): return []
	var result: Variant = service.call(recordsMethod, configName)
	if result is Array:
		return result
	return []


func val(configName: StringName, key: Variant, fieldName: StringName) -> Variant:
	if not hasService(): return null
	return service.call(valueMethod, configName, key, fieldName)


func one(configName: StringName) -> Dictionary:
	if not hasService(): return {}
	var result: Variant = service.call(oneMethod, configName)
	if result is Dictionary:
		return result
	return {}


func oneVal(configName: StringName, fieldName: StringName) -> Variant:
	if not hasService(): return null
	return service.call(oneValueMethod, configName, fieldName)


func hasService() -> bool:
	if service != null and is_instance_valid(service):
		return true

	push_error("Tb has no valid LubanConfigService node.")
	return false
