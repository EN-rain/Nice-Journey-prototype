class_name EquipmentItemCatalog
extends Resource

@export var definitions: Array[EquipmentItemDefinition] = []

func get_definition(definition_id: StringName) -> EquipmentItemDefinition:
	for definition: EquipmentItemDefinition in definitions:
		if definition != null and definition.definition_id == definition_id:
			return definition
	return null

func validate_catalog() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen: Dictionary = {}
	for index: int in range(definitions.size()):
		var definition := definitions[index]
		if definition == null:
			errors.append("definitions[%d] must not be null" % index)
			continue
		for definition_error: String in definition.validate_definition():
			errors.append("definitions[%d]: %s" % [index, definition_error])
		if seen.has(definition.definition_id):
			errors.append("duplicate definition_id %s" % String(definition.definition_id))
		seen[definition.definition_id] = true
	return errors
