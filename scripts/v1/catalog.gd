extends RefCounted
## Định nghĩa bất biến. Mọi giá trị cân bằng mẫu nằm trong JSON, không gắn cặp bí tịch.
static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/cultivation_v1.json"))
	return _data

static func balance(key: String) -> float:
	return float(data().balance[key])

static func definition(id: String) -> Dictionary:
	for group in ["books", "equipment"]:
		for item in data()[group]:
			if item.id == id:
				return item
	return {}

## Tên cảnh giới/tầng ứng với step_index() của Cultivation (0 = Luyện Khí tầng 1).
static func step_name(step: int) -> String:
	return "%s tầng %d" % [Cultivation.REALMS[1 + step / Cultivation.LAYERS], step % Cultivation.LAYERS + 1]


static func effect(id: String) -> Dictionary:
	return data().effects.get(id, {})

## pool: các dòng phụ mà bí tịch này có thể roll (rỗng = toàn bộ).
static func weighted_affix(rng: RandomNumberGenerator, excluded: Array = [], pool: Array = []) -> String:
	var total := 0
	for id in data().affixes:
		if id not in excluded and (pool.is_empty() or id in pool):
			total += int(data().affixes[id].weight)
	var value := rng.randi_range(1, maxi(1, total))
	for id in data().affixes:
		if id in excluded or (not pool.is_empty() and id not in pool):
			continue
		value -= int(data().affixes[id].weight)
		if value <= 0:
			return id
	return ""
