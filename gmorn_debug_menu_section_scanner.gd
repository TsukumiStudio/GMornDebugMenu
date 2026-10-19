extends RefCounted

## `gmorn_debug_menu_section.gd` を継承した `.tres` を列挙する。Editor に依存しない。

const SectionScript := preload("gmorn_debug_menu_section.gd")
const SETTING_KEY := "gmorn_debug_menu/section_dir"
const DEFAULT_DIR := "res://assets/debug_sections/"

static func section_dir() -> String:
	if ProjectSettings.has_setting(SETTING_KEY):
		return String(ProjectSettings.get_setting(SETTING_KEY, DEFAULT_DIR))
	return DEFAULT_DIR

## ファイル名順。置き場が無くても落ちず、継承していない `.tres` は無視する。
static func scan(dir: String = "") -> Array[Resource]:
	var target := dir if not dir.is_empty() else section_dir()
	var sections: Array[Resource] = []
	if not DirAccess.dir_exists_absolute(target):
		return sections
	var file_names := DirAccess.get_files_at(target)
	file_names.sort()
	for file_name: String in file_names:
		if not file_name.ends_with(".tres"):
			continue
		var resource: Resource = ResourceLoader.load(target.path_join(file_name))
		if resource is SectionScript:
			sections.append(resource)
	return sections

## `section_id` が空ならファイル名（拡張子抜き）から作る。
static func section_id(section: Resource) -> StringName:
	if section.section_id != &"":
		return section.section_id
	return StringName(section.resource_path.get_file().get_basename())
