@tool
@icon("./quit_button.svg")
class_name QuitButton
extends Button

## QuitButton
##
## Quits the application when pressed,
## falling back to a defined [member alternative_behaviour] if doing so is impossible.[br]
## NOTE: It's highly suggested to modify the [member Button.process_mode] of this
## in order for it to process in the tree's [member SceneTree.paused] state.

## An enumeration outlining method of how this button should remove itself when
## the given environment (ex. a Web Browser, a [i]compliant[/i] iOS app) cannot
## allow for the user quit the application by pressing a button like this.
enum AlternativeBehaviour{
	NONE, ## Do not remove
	FREE, ## Free the button
	HIDE, ## Make the button invisible
	DISABLE, ## Visibly disable the button
	## Show a [method OS.alert] dialog with the message specified in [member alert_instructions].
	ALERT_INSTRUCTIONS,
}

## Names (as returned by [method OS.get_name], matching case) of platforms that
## will not allow (both because it's impossible (ex. Web),
## or because it is not allowed (ex. iOS)) for [method SceneTree.quit] to work as expected.
const IMPOSSIBLE_PLATFORMS := ["Web", "iOS"]

## When the target environment is unquitable for whatever reason,
## this the button will use this [enum AlternativeBehaviour].[br]
## See [enum AlternativeBehaviour] for information on what each setting does,
## and [method use_alternate] to check when this applies.
@export_enum("None", "Free", "Hide", "Disable", "Alert")
var alternative_behaviour:int = AlternativeBehaviour.FREE:
	get:
		return alternative_behaviour
	set(_value):
		alternative_behaviour = _value
		notify_property_list_changed()

## The content of the popup to show when this button is pressed and this button uses
## [constant ALERT_INSTRUCTIONS].
## Has no effect when [member alternative_behaviour] is not set to
## [constant ALERT_INSTRUCTIONS] or when [method use_alternate]
## is [code]false[/code].
@export_multiline var alert_instructions:String = "You may manually exit this software."

@export_group("Exit Behaviour")
## Exit code to used when exiting.
@export var exit_code:int = 0

## Unpause the tree before quitting.
@export var unpause_before_quit := true

## Propagate a [constant Node.NOTIFICATION_WM_CLOSE_REQUEST] notification from the
## root node of the current tree before quitting.[br]
## Done [i]after[/i] [member unpause_before_quit].
@export var send_close_request_notification := true

@export_group("Extra Input Handling")

## The [StringName] of an [Input] action to use as another
## means of activation (outside and ignoring the traditional means of ui focus
## and the [code]"ui_accept"[/code] input action, which will still applies separately).[br]
## When empty, this will ignore any inputs outside that of any other button.[br]
## This is only suggested in to be used in situations where the input event
## will not be used for any other purpose
## (ex, not in a pause menu that appears over a game, but instead in a game's main menu).
@export var catch_input_action:StringName = "":
	get:
		return catch_input_action
	set(_value):
		catch_input_action = _value
		notify_property_list_changed()

## When set, this button will only receive inputs from [method Control._gui_input],
## which confines the input event se in [member catch_input_action] to only be caught
## when this or one fo it's ancestors has gui focus,
## and after handling all [method Node._input] methods.
## Toggling this off allows for this to receive [member catch_input_action]
## outside of the usual gui hierarchy; potentially fixing instances where
## the input event may not be recognised but possibly overriding other
## valid uses of this event. This is not suggested to be turned off
## unless the hierarchy of the scene this is used in requires it.
## NOTE: For safety this will never be caught when running in editor,
## even when attached to something other than scenes being edited.
@export var catch_only_gui_input := true

## Weather or not a valid caught [InputEvent] should be matched exactly
## (just like [method InputEvent.is_action_pressed]'s [param exact_match]).
@export var catch_input_action_exact := true

## Weather or not a valid caught [InputEvent] should match echo events
## (just like [method InputEvent.is_action_pressed]'s [param allow_echo]).
@export var catch_input_action_echo := false

## Returns [code]true[/code] when this button should not attempt to quit
## and instead act as specified by [member alternative_behaviour].[br]
## NOTE: While having [method OS.get_name] return a name thats in
## [constant IMPOSSIBLE_PLATFORMS] will result in this returning true,
## this also returns true when this button is not in a tree
## (a tree reference is necessary in order to call [method SceneTree.quit] in the first place).
func use_alternate() -> bool:
	return (not is_inside_tree()) or OS.get_name() in IMPOSSIBLE_PLATFORMS

func _ready():
	if Engine.is_editor_hint():
		return
	toggle_mode = false
	if use_alternate():
		match(alternative_behaviour):
			AlternativeBehaviour.FREE:
				queue_free()
			AlternativeBehaviour.HIDE:
				hide()
			AlternativeBehaviour.DISABLE:
				disabled = true
			AlternativeBehaviour.NONE, AlternativeBehaviour.ALERT_INSTRUCTIONS:
				pass
			var x:
				push_warning("Unknown AlternativeBehaviour: " + str(x))

func _property_can_revert(property: StringName) -> bool:
	match(property):
		"text", "process_mode":
			return true
	return false

func _property_get_revert(property: StringName) -> Variant:
	match(property):
		"text":
			return tr("Quit")
		"process_mode":
			return PROCESS_MODE_ALWAYS
	return null

func _validate_property(property: Dictionary):
	match(property.name):
		"toggle_mode":
			property.usage &= ~PROPERTY_USAGE_EDITOR | ~PROPERTY_USAGE_STORAGE
		"alert_instructions" when alternative_behaviour != AlternativeBehaviour.ALERT_INSTRUCTIONS:
			property.usage &= ~PROPERTY_USAGE_EDITOR
		"catch_only_gui_input",\
		"catch_input_action_exact",\
		"catch_input_action_echo" when catch_input_action.is_empty():
			property.usage &= ~PROPERTY_USAGE_EDITOR

func _pressed():
	_on_quit()

func _input(event: InputEvent) -> void:
	if catch_only_gui_input or catch_input_action.is_empty():
		return
	_on_input(event)

func _gui_input(event: InputEvent) -> void:
	if catch_input_action.is_empty():
		return
	_on_input(event)

func _on_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event.is_action_pressed(catch_input_action, catch_input_action_echo, catch_input_action_exact):
		if action_mode == ActionMode.ACTION_MODE_BUTTON_PRESS:
			_on_quit()
		else:
			set_pressed_no_signal(true)
		get_viewport().set_input_as_handled()
	elif event.is_action_released(catch_input_action, catch_input_action_exact):
		if action_mode == ActionMode.ACTION_MODE_BUTTON_RELEASE:
			_on_quit()
			get_viewport().set_input_as_handled()

func _on_quit():
	if use_alternate():
		if alternative_behaviour == AlternativeBehaviour.ALERT_INSTRUCTIONS:
			OS.alert(alert_instructions, tr("Quit"))
	else:
		var tree := get_tree()
		if tree != null:
			if unpause_before_quit:
				tree.paused = false
			if send_close_request_notification:
				tree.root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
			tree.call_deferred("quit", exit_code)
