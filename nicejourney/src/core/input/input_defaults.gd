## Seeds the prototype's rebindable InputMap with specification-aligned defaults.
## This autoload owns only global input-map defaults; gameplay admission stays in scenes/components.
extends Node

func _enter_tree() -> void:
    for action_variant: Variant in InputDefaultBindings.DEFAULT_BINDINGS.keys():
        var action: StringName = StringName(action_variant)
        if _ensure_action(action):
            InputMap.action_add_event(action, InputDefaultBindings.make_default_event(action))

func _ensure_action(action: StringName) -> bool:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    return InputMap.action_get_events(action).is_empty()
