class_name VendorStockDefinition
extends Resource

const RESTOCK_POLICY_FIXED_NO_RESTOCK: StringName = &"fixed_no_restock"
const RESTOCK_POLICY_EVENT_DRIVEN: StringName = &"event_driven"
const SUPPORTED_RESTOCK_POLICIES: Array[StringName] = [
    RESTOCK_POLICY_FIXED_NO_RESTOCK,
    RESTOCK_POLICY_EVENT_DRIVEN,
]

@export var vendor_id: StringName = &""
@export var restock_rule_id: StringName = &""
@export var restock_policy: StringName = &""
@export var restock_event_id: StringName = &""
@export var availability_condition_ids: Array[StringName] = []
@export var availability_conditions_declared: bool = false
@export var stock: Dictionary = {}


func validate_definition() -> PackedStringArray:
    var errors := PackedStringArray()
    if not StableId.is_valid(String(vendor_id)):
        errors.append("vendor_id must be a stable ID")
    if not StableId.is_valid(String(restock_rule_id)):
        errors.append("restock_rule_id must be a stable ID")
    if restock_policy != &"" and not SUPPORTED_RESTOCK_POLICIES.has(restock_policy):
        errors.append("restock_policy must be fixed_no_restock or event_driven")
    if restock_event_id != &"" and not StableId.is_valid(String(restock_event_id)):
        errors.append("restock_event_id must be empty or a stable ID")
    if restock_policy == RESTOCK_POLICY_FIXED_NO_RESTOCK and restock_event_id != &"":
        errors.append("fixed_no_restock cannot declare a restock_event_id")
    if restock_policy == RESTOCK_POLICY_EVENT_DRIVEN and not StableId.is_valid(String(restock_event_id)):
        errors.append("event_driven restock requires a stable restock_event_id")
    var seen_conditions: Dictionary = {}
    for condition_id: StringName in availability_condition_ids:
        if not StableId.is_valid(String(condition_id)):
            errors.append("availability_condition_ids require stable IDs")
        elif seen_conditions.has(condition_id):
            errors.append("availability_condition_ids must be unique")
        seen_conditions[condition_id] = true
    if stock.is_empty():
        errors.append("stock must contain at least one authored item")
        return errors

    var runtime: VendorStockState = VendorStockState.new()
    if not runtime.configure(vendor_id, stock):
        errors.append("stock must contain exact valid prices, quantities and stackability")
    return errors


func validate_authored_definition() -> PackedStringArray:
    var errors := validate_definition()
    if not SUPPORTED_RESTOCK_POLICIES.has(restock_policy):
        errors.append("restock_policy must be explicitly authored")
    if not availability_conditions_declared:
        errors.append("availability conditions must be explicitly authored, including an explicit empty set")
    return errors


func unauthored_fields() -> PackedStringArray:
    var fields := PackedStringArray()
    if not StableId.is_valid(String(vendor_id)):
        fields.append("vendor_id")
    if stock.is_empty():
        fields.append("stock_manifest")
        fields.append("buy_prices")
        fields.append("sell_prices")
        fields.append("quantities")
    if not StableId.is_valid(String(restock_rule_id)):
        fields.append("restock_rule_id")
    if not SUPPORTED_RESTOCK_POLICIES.has(restock_policy):
        fields.append("restock_policy")
    if not availability_conditions_declared:
        fields.append("availability_conditions")
    if restock_policy == RESTOCK_POLICY_EVENT_DRIVEN and not StableId.is_valid(String(restock_event_id)):
        fields.append("restock_event_id")
    return fields


func instantiate_state() -> VendorStockState:
    if not validate_definition().is_empty():
        return null
    var runtime: VendorStockState = VendorStockState.new()
    if not runtime.configure(vendor_id, stock):
        return null
    return runtime


func build_state() -> VendorStockState:
    return instantiate_state()
