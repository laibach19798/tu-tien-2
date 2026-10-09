extends RefCounted
class_name Dir
## 8 hướng la bàn dùng cho nhân vật. Tên trùng với hậu tố animation: idle_south, walk_north-east, ...

const ALL := ["south", "south-east", "east", "north-east", "north", "north-west", "west", "south-west"]
const LEGACY := {"front": "south", "back": "north", "left": "west", "right": "east", "side": "east"}
const BY_SECTOR := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]


static func normalize(name: String) -> String:
	return LEGACY.get(name, name)


## Hướng gần nhất với vector v (trục y hướng xuống như trong Godot). v = 0 trả về `fallback`.
static func from_vector(v: Vector2, fallback := "south") -> String:
	if v.length_squared() < 0.0001:
		return fallback
	var sector := int(round(atan2(v.y, v.x) / (PI / 4.0)))   # east = 0, south-east = 1, south = 2, ...
	return BY_SECTOR[posmod(sector, 8)]


static func to_vector(name: String) -> Vector2:
	match normalize(name):
		"east": return Vector2.RIGHT
		"south-east": return Vector2(1, 1).normalized()
		"south": return Vector2.DOWN
		"south-west": return Vector2(-1, 1).normalized()
		"west": return Vector2.LEFT
		"north-west": return Vector2(-1, -1).normalized()
		"north": return Vector2.UP
		"north-east": return Vector2(1, -1).normalized()
	return Vector2.DOWN
