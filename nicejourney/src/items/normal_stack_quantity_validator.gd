class_name NormalStackQuantityValidator
extends RefCounted

const MIN_QUANTITY: int = 1
const MAX_QUANTITY: int = 99

static func is_valid(raw_quantity: Variant) -> bool:
	if typeof(raw_quantity) != TYPE_INT:
		return false

	var quantity: int = int(raw_quantity)
	return quantity >= MIN_QUANTITY and quantity <= MAX_QUANTITY
