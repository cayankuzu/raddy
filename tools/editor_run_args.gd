## Dev helper run inside the editor through Beckett (call_method target=res://tools/editor_run_args.gd):
## makes editor-launched games pass --accessibility disabled, the workaround for the AccessKit
## crash on this PC (see CLAUDE.md). Exported builds never include tools/.
static func apply() -> String:
	var settings := EditorInterface.get_editor_settings()
	settings.set_setting("run/main_run_args", "--accessibility disabled")
	return str(settings.get_setting("run/main_run_args"))
