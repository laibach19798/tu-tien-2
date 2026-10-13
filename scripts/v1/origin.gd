extends RefCounted
const Data = preload("res://scripts/v1/catalog.gd")

static func distribute(keys: Array, total: int, minimum: int, maximum: int, rng: RandomNumberGenerator) -> Dictionary:
	var out := {}
	for key in keys:
		out[key] = minimum
	for i in total - minimum * keys.size():
		var choices: Array = []
		for key in keys:
			if int(out[key]) < maximum:
				choices.append(key)
		out[choices[rng.randi_range(0, choices.size() - 1)]] += 1
	# Chuyển điểm ngẫu nhiên để roll không tập trung quá sát 50.
	for i in 120:
		var a = keys[rng.randi_range(0, keys.size() - 1)]
		var b = keys[rng.randi_range(0, keys.size() - 1)]
		if a != b:
			var amount = rng.randi_range(0, mini(int(out[a]) - minimum, maximum - int(out[b])))
			out[a] -= amount
			out[b] += amount
	return out

static func roll(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var fates: Array = Data.data().fates.keys()
	return {"version":1,"seed":seed_value,"attributes":distribute(Data.data().attributes.keys(), 300, 25, 75, rng),"roots":distribute(Data.data().elements.keys(), 100, 5, 80, rng),"fate":fates[rng.randi_range(0, fates.size()-1)],"confirmed":true}

static func sample() -> Dictionary:
	return {"version":1,"seed":1101,"attributes":{"constitution":54,"meridians":56,"insight":44,"awareness":51,"agility":49,"composure":46},"roots":{"kim":19,"moc":20,"thuy":17,"hoa":23,"tho":21},"fate":"hoi_nguyen","confirmed":true}

static func migrate(old: Dictionary) -> Dictionary:
	var result := sample()
	for id in result.attributes:
		result.attributes[id] = 50
	result.attributes.insight = clampi(int(old.get("comp",50)),25,75)
	result.attributes.awareness = clampi(int(old.get("spirit",50)),25,75)
	var sum := 0
	for value in result.attributes.values():
		sum += int(value)
	while sum != 300:
		for id in ["constitution","meridians","agility","composure"]:
			var step := 1 if sum < 300 else -1
			if sum != 300 and int(result.attributes[id])+step >= 25 and int(result.attributes[id])+step <= 75:
				result.attributes[id] += step
				sum += step
	for id in result.roots:
		result.roots[id] = 20
	result["migration"] = "v0_to_v1_normalized"
	return result

static func valid(d: Dictionary) -> bool:
	if not Data.data().fates.has(str(d.get("fate", ""))):
		return false
	for group in ["attributes", "roots"]:
		var sum := 0
		var keys: Array = Data.data().attributes.keys() if group == "attributes" else Data.data().elements.keys()
		for key in keys:
			var value = d.get(group, {}).get(key, -1)
			if float(value) != float(int(value)) or int(value) < (25 if group == "attributes" else 5):
				return false
			if group == "attributes" and int(value) > 75:
				return false
			sum += int(value)
		if sum != (300 if group == "attributes" else 100):
			return false
	return true
