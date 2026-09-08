@tool
extends VBoxContainer

var action_text := "操作"
var action: Callable
var requires_confirmation := false
var is_playing: Callable = func() -> bool:
	return not Engine.is_editor_hint() or EditorInterface.is_playing_scene()
var _armed_until := 0

func _ready() -> void:
	$Action.pressed.connect(_pressed)
	_process(0.0)

func _process(_delta: float) -> void:
	$Status.visible = not $Status.text.is_empty()
	var playing := bool(is_playing.call())
	$Action.disabled = playing
	if playing or Time.get_ticks_msec() > _armed_until:
		_armed_until = 0
	$Action.text = "もう一度押して削除" if _armed_until > 0 else action_text
	$Action.tooltip_text = "ゲーム停止中のみ操作できます" if playing else action_text

func _pressed() -> void:
	# 無効ボタンのsignalを直接呼ばれても、再生中は実行しない。
	if bool(is_playing.call()):
		_armed_until = 0
		$Status.text = "ゲームを停止してから操作してください"
		_process(0.0)
		return
	if requires_confirmation and Time.get_ticks_msec() >= _armed_until:
		_armed_until = Time.get_ticks_msec() + 3000
		$Status.text = "本体・バックアップ・書きかけを削除します。3秒以内にもう一度押してください。"
		_process(0.0)
		return
	_armed_until = 0
	if action.is_valid():
		$Status.text = String(action.call())
	_process(0.0)
