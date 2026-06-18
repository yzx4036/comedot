## Base class for Luban config data loaders.
## Provides common patterns for loading and converting config table rows
## into typed game runtime objects.
##
## Subclasses (or static callers) define how each row maps to a game object,
## while this base handles iteration, error handling and filtering.
##
## Usage:
##   var effects: Array = LubanLoader.loadAll(tb, TbCfg.myTable, MyLoader.convertRow)
##   var item: Variant = LubanLoader.loadFirst(tb, TbCfg.myTable, 1001, MyLoader.convertRow)

class_name LubanLoader
extends RefCounted


## Load all rows from a table and convert each via [param converter].
## [param converter] signature: (row: Dictionary) -> Variant
## Rows where converter returns null are skipped.
## Returns an Array of converted objects.
static func loadAll(tb: Tb, configName: StringName, converter: Callable) -> Array:
	var result: Array = []
	if tb == null or not tb.has(configName):
		return result

	for row: Dictionary in tb.rows(configName):
		if row.is_empty():
			continue
		var converted: Variant = converter.call(row)
		if converted != null:
			result.append(converted)
	return result


## Load a single row by key and convert it.
## Returns null if the row doesn't exist or converter returns null.
static func loadFirst(tb: Tb, configName: StringName, key: Variant, converter: Callable) -> Variant:
	if tb == null:
		return null
	var row: Dictionary = tb.row(configName, key)
	if row.is_empty():
		return null
	return converter.call(row)


## Filter an array of converted objects by a predicate.
## [param predicate] signature: (item: Variant) -> bool
static func filter(items: Array, predicate: Callable) -> Array:
	var result: Array = []
	for item: Variant in items:
		if predicate.call(item):
			result.append(item)
	return result


## Load all rows and group them by a key extracted from each converted object.
## [param keyExtractor] signature: (item: Variant) -> Variant (the group key)
## Returns a Dictionary mapping group keys to arrays of objects.
static func loadGrouped(tb: Tb, configName: StringName, converter: Callable, keyExtractor: Callable) -> Dictionary:
	var groups: Dictionary = {}
	var items: Array = loadAll(tb, configName, converter)
	for item: Variant in items:
		var groupKey: Variant = keyExtractor.call(item)
		if not groups.has(groupKey):
			groups[groupKey] = []
		groups[groupKey].append(item)
	return groups
