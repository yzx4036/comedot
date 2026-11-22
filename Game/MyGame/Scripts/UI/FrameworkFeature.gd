class_name FrameworkFeature
extends RefCounted

## comedot 框架的一项功能：可查阅，也可能带一个可直接运行的演示场景。
## 由 [FrameworkFeatureCatalog] 构建；本类只装数据，不做任何 I/O。


#region 属性

## 功能名，通常等于组件类名（如 `HealthComponent`）
var title: String

## 所属类别（战斗/控制/运行时/UI…），用于分组与筛选
var category: String

## 一句话说明
var summary: String

## 主脚本或资源路径（`res://`），详情面板显示，也是自检的存在性依据
var sourcePath: String

## 可直接运行的演示场景（`res://`）；空字符串表示只读条目
var demoScenePath: String

#endregion


func _init(pTitle: String, pCategory: String, pSummary: String, pSourcePath: String, pDemoScenePath: String = "") -> void:
	title = pTitle
	category = pCategory
	summary = pSummary
	sourcePath = pSourcePath
	demoScenePath = pDemoScenePath


## 是否有可运行的演示场景
func hasDemo() -> bool:
	return not demoScenePath.is_empty()


## 组件通常与同名 `.tscn` 成对存在；有则返回其路径，否则返回空字符串
func getSceneSiblingPath() -> String:
	if not sourcePath.ends_with(".gd"):
		return ""
	var candidate: String = sourcePath.get_basename() + ".tscn"
	return candidate if ResourceLoader.exists(candidate) else ""


## 是否匹配搜索词（标题/说明/类别，忽略大小写）
func matchesQuery(query: String) -> bool:
	if query.is_empty():
		return true
	var lowerQuery: String = query.to_lower()
	return title.to_lower().contains(lowerQuery) \
		or summary.to_lower().contains(lowerQuery) \
		or category.to_lower().contains(lowerQuery)


## 按钮上显示的名字：去掉结尾的 `Component`，窄按钮里才放得下；
## 完整类名照旧在详情面板与 tooltip 里给出
func getDisplayTitle() -> String:
	const suffix: String = "Component"
	if title.length() > suffix.length() and title.ends_with(suffix):
		return title.substr(0, title.length() - suffix.length())
	return title
