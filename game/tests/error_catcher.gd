class_name ErrorCatcher
extends Logger
## Collects engine and script errors so headless checks can fail on them
## (a GDScript runtime error otherwise just aborts the function and lets the run continue).

var errors: Array[String] = []


func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, _error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
	errors.append("%s (%s:%d)" % [rationale if rationale != "" else code, file.get_file(), line])


func _log_message(_message: String, _error: bool) -> void:
	pass
