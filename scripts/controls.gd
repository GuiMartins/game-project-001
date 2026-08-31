extends Node
## Registra o mapa de acoes em runtime.
##
## Prototipo: manter o input map em codigo (e nao no project.godot) deixa o
## remapeamento legivel e versionavel em texto. Migrar para o InputMap do editor
## quando o esquema de controle estabilizar.

const ACTIONS: Dictionary = {
	"ride_throttle": [KEY_W, KEY_UP],
	"ride_brake": [KEY_S, KEY_DOWN],
	"ride_left": [KEY_A, KEY_LEFT],
	"ride_right": [KEY_D, KEY_RIGHT],
	"ride_boost": [KEY_SHIFT],
	"hit_left": [KEY_Q],
	"hit_right": [KEY_E],
	"debug_pixel_toggle": [KEY_F1],
	"debug_camera_cycle": [KEY_F2],
	"debug_tuning_panel": [KEY_F3],
	"debug_restart": [KEY_R],
}

const JOY_ACTIONS: Dictionary = {
	"ride_throttle": JOY_BUTTON_A,
	"ride_brake": JOY_BUTTON_B,
	"ride_boost": JOY_BUTTON_RIGHT_SHOULDER,
	"hit_left": JOY_BUTTON_X,
	"hit_right": JOY_BUTTON_Y,
}


func _ready() -> void:
	for action_name: String in ACTIONS:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		for keycode: Key in ACTIONS[action_name]:
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode
			InputMap.action_add_event(action_name, ev)

	for action_name: String in JOY_ACTIONS:
		var ev := InputEventJoypadButton.new()
		ev.button_index = JOY_ACTIONS[action_name]
		InputMap.action_add_event(action_name, ev)

	# Analogico: stick esquerdo controla a inclinacao.
	_add_axis("ride_left", JOY_AXIS_LEFT_X, -1.0)
	_add_axis("ride_right", JOY_AXIS_LEFT_X, 1.0)


func _add_axis(action_name: String, axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action_name, ev)


## Eixo de inclinacao (-1 esquerda .. +1 direita), ja com deadzone do InputMap.
static func steer_axis() -> float:
	return Input.get_axis("ride_left", "ride_right")
