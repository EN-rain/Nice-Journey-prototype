class_name HealthTuning
extends Resource

# Initial shared prototype HP tuning. Exact class/equipment scaling remains tunable.
@export_range(1, 100000, 1) var max_hp: int = 100
