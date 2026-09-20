extends SceneTree

var _failures: int = 0

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	_expect(NormalStackQuantityValidator.is_valid(1), "minimum legal normal stack quantity is accepted")
	_expect(NormalStackQuantityValidator.is_valid(99), "maximum legal normal stack quantity is accepted")
	_expect(NormalStackQuantityValidator.is_valid(42), "in-range normal stack quantity is accepted")

	_expect(not NormalStackQuantityValidator.is_valid(0), "zero normal stack quantity is rejected")
	_expect(not NormalStackQuantityValidator.is_valid(-1), "negative normal stack quantity is rejected")
	_expect(not NormalStackQuantityValidator.is_valid(-99), "larger negative normal stack quantity is rejected")
	_expect(not NormalStackQuantityValidator.is_valid(100), "normal stack quantity above the cap is rejected")
	_expect(not NormalStackQuantityValidator.is_valid(1000), "normal stack quantity far above the cap is rejected")

	_expect(not NormalStackQuantityValidator.is_valid(1.0), "floating-point quantity is rejected even when numerically integral")
	_expect(not NormalStackQuantityValidator.is_valid("1"), "string quantity is rejected")
	_expect(not NormalStackQuantityValidator.is_valid(true), "boolean quantity is rejected")
	_expect(not NormalStackQuantityValidator.is_valid(null), "null quantity is rejected")

	var caller_quantity: int = 17
	var caller_quantity_before: int = caller_quantity
	var first_result: bool = NormalStackQuantityValidator.is_valid(caller_quantity)
	var second_result: bool = NormalStackQuantityValidator.is_valid(caller_quantity)
	_expect(first_result == second_result, "repeated validation is deterministic")
	_expect(caller_quantity == caller_quantity_before, "validation does not mutate caller quantity")

	if _failures == 0:
		print("NORMAL STACK QUANTITY TEST PASS")
	else:
		push_error("NORMAL STACK QUANTITY TEST FAILURES: %d" % _failures)
	quit(_failures)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failures += 1
	push_error("FAIL: %s" % message)
