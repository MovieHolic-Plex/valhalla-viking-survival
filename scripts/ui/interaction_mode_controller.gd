class_name InteractionModeController
extends Node
## Single writer for gameplay input lock, mouse capture and offline pause.

signal mode_changed(previous: Mode, current: Mode)

enum Mode {
	GAMEPLAY,
	INVENTORY_CRAFT_BUILD_MENU,
	CHAT,
	SETTINGS_HELP,
	PAUSE,
	DEATH,
	TRANSITION,
	DISCONNECTED,
}

var current_mode: Mode = Mode.GAMEPLAY
var _player: Player
var _active: Dictionary = {}
var _focus_targets: Dictionary = {}
var _focus_generation := 0
var _offline_pause_claimed := false



func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func bind_player(player: Player) -> void:
	_player = player
	_apply_effects()


func set_mode_active(mode: Mode, active: bool, focus_target: Control = null) -> void:
	if mode == Mode.GAMEPLAY:
		return
	var was_active := bool(_active.get(mode, false))
	var focus_changed: bool = focus_target != null and _focus_targets.get(mode) != focus_target
	if active:
		_active[mode] = true
		if focus_target != null:
			_focus_targets[mode] = focus_target
	else:
		_active.erase(mode)
		_focus_targets.erase(mode)
	if was_active != active or focus_changed:
		_resolve_mode()

func set_mode_states(states: Dictionary, focus_targets: Dictionary = {}) -> void:
	var changed := false
	for mode in states:
		var active := bool(states[mode])
		var was_active := bool(_active.get(mode, false))
		if active:
			_active[mode] = true
			var target := focus_targets.get(mode) as Control
			if target != null and _focus_targets.get(mode) != target:
				_focus_targets[mode] = target
				changed = true
		else:
			_active.erase(mode)
			_focus_targets.erase(mode)
		if active != was_active:
			changed = true
	if changed:
		_resolve_mode()
	else:
		_apply_effects()

func set_offline_pause_claimed(active: bool) -> void:
	if _offline_pause_claimed == active:
		return
	_offline_pause_claimed = active
	_apply_effects()


func clear_modes() -> void:
	if _active.is_empty() and _focus_targets.is_empty():
		return
	_active.clear()
	_focus_targets.clear()
	_resolve_mode()


func is_gameplay() -> bool:
	return current_mode == Mode.GAMEPLAY


func blocks_gameplay_input() -> bool:
	return not is_gameplay()


func _resolve_mode() -> void:
	var next := Mode.GAMEPLAY
	for candidate in [Mode.DISCONNECTED, Mode.TRANSITION, Mode.DEATH, Mode.PAUSE,
			Mode.SETTINGS_HELP, Mode.CHAT, Mode.INVENTORY_CRAFT_BUILD_MENU]:
		if bool(_active.get(candidate, false)):
			next = candidate
			break
	var previous := current_mode
	current_mode = next
	_apply_effects()
	if previous != current_mode:
		mode_changed.emit(previous, current_mode)


func _apply_effects() -> void:
	var locked := current_mode != Mode.GAMEPLAY
	if _player != null and is_instance_valid(_player):
		_player.input_locked = locked
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if locked else Input.MOUSE_MODE_CAPTURED
	# Network sessions must keep simulation running. The pause menu still locks local input.
	get_tree().paused = _offline_pause_claimed and not Net.is_online
	_restore_focus()


func _restore_focus() -> void:
	_focus_generation += 1
	var generation := _focus_generation
	var owner := get_viewport().gui_get_focus_owner()
	if owner != null:
		owner.release_focus()
	if current_mode == Mode.GAMEPLAY:
		return
	var target := _focus_targets.get(current_mode) as Control
	if target == null or not is_instance_valid(target) or not target.is_visible_in_tree():
		return
	var focusable := _first_focusable(target)
	if focusable != null:
		_grab_focus_if_current.call_deferred(generation, current_mode, focusable)


func _grab_focus_if_current(generation: int, mode: Mode, target: Control) -> void:
	if generation != _focus_generation or mode != current_mode:
		return
	if is_instance_valid(target) and target.is_visible_in_tree():
		target.grab_focus()


func _first_focusable(root: Control) -> Control:
	var actionable := _first_actionable(root)
	if actionable != null:
		return actionable
	return _first_visible_focusable(root)


func _first_actionable(root: Control) -> Control:
	if _is_actionable(root):
		return root
	for child in root.get_children():
		if child is Control:
			var found := _first_actionable(child as Control)
			if found != null:
				return found
	return null


func _first_visible_focusable(root: Control) -> Control:
	if root.focus_mode != Control.FOCUS_NONE and root.is_visible_in_tree():
		return root
	for child in root.get_children():
		if child is Control:
			var found := _first_visible_focusable(child as Control)
			if found != null:
				return found
	return null


func _is_actionable(control: Control) -> bool:
	if control.focus_mode == Control.FOCUS_NONE or not control.is_visible_in_tree():
		return false
	if bool(control.get_meta("keyboard_actionable", false)):
		return true
	if control is BaseButton:
		return not (control as BaseButton).disabled
	if control is LineEdit:
		return (control as LineEdit).editable
	if control is TextEdit:
		return (control as TextEdit).editable
	return control is Range or control is ItemList or control is Tree
