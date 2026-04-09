@tool
@icon("./restart_button.svg")
class_name RestartButton
extends QuitButton

## RestartButton
##
## An extension of [QuitButton] that allows for the entire application to be quit
## and then relaunched.[br]
## For more information, see [QuitButton].[br][br]
## NOTE: Using [method OS.set_restart_on_exit] just before this button quits this software
## (like in situations where it propagates the [constant NOTIFICATION_WM_CLOSE_REQUEST]
## notification) will override the behaviour of this button.[br]
## NOTE: When you desire to switch back or reload some main or central scene, it's
## highly suggested that you avoid using this (which relaunches the application entirely)
## as opposed to switching/reloading that scene in some fashion.
## This button is only best in situations involving debugging,
## reloading when internal packed resources change (such as the addition of mods),
## or when your really - [i]really[/i] - that screwed
## and this is the only option left that actually works.

func _property_can_revert(property: StringName) -> bool:
	match(property):
		"text":
			return true
	return false

func _property_get_revert(property: StringName) -> Variant:
	match(property):
		"text":
			return tr("Restart")
	return null

func _on_quit():
	if not use_alternate() and not Engine.is_editor_hint():
		OS.set_restart_on_exit(true, OS.get_cmdline_args())
	super()
