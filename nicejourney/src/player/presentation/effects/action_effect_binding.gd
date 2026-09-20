class_name ActionEffectBinding
extends Resource

@export var action_id: StringName = &""
@export var effect_profile: EffectVisualProfile

func validate_binding() -> PackedStringArray:
	var errors := PackedStringArray()
	if not StableId.is_valid(String(action_id)):
		errors.append("action_id must be a stable ID")
	if effect_profile == null:
		errors.append("effect_profile is required")
	else:
		for error: String in effect_profile.validate_profile():
			errors.append("effect_profile: %s" % error)
	return errors
