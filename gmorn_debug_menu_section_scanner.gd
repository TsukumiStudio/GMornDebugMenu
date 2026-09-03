extends RefCounted

## `gmorn_debug_menu_section.gd` を継承した `.tres` を列挙する。
##
## `plugin.gd` がエディタに入るときに呼ぶ（ドックへセクションとして足すため）が、
## `Resource` の読み込みとフォルダ走査だけなので `verify.gd` から直に呼んで
## 確かめられる。

const SectionScript := preload("gmorn_debug_menu_section.gd")
const SETTING_KEY := "gmorn_debug_menu/section_dir"
const DEFAULT_DIR := "res://assets/debug_sections/"

## セクションを探す置き場。プロジェクト設定が無ければ既定を使う。
static func section_dir() -> String:
	if ProjectSettings.has_setting(SETTING_KEY):
		return String(ProjectSettings.get_setting(SETTING_KEY, DEFAULT_DIR))
	return DEFAULT_DIR

## `dir` 直下の `.tres` をファイル名順に読み、`gmorn_debug_menu_section.gd` を
## 継承したものだけ返す。置き場が無ければ空を返す（`.tres` をまだ1つも
## 置いていないプロジェクトでも落ちないようにするため）。他の用途の `.tres`
## が同じ置き場に混ざっていても、継承していなければ無視する。
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

## `register_section()` に渡す id。`section.section_id` を指定していればそれを、
## 空ならリソースの置き場（拡張子を除いたファイル名）から作る。
static func section_id(section: Resource) -> StringName:
	if section.section_id != &"":
		return section.section_id
	return StringName(section.resource_path.get_file().get_basename())
