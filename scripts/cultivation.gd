extends Node
class_name Cultivation
## Hệ thống tu luyện: hấp thụ linh khí -> luyện hoá thành tu vi -> lên tầng -> đột phá cảnh giới.

signal changed
signal message(text: String)

const REALMS := ["Phàm Nhân", "Luyện Khí", "Trúc Cơ", "Kim Đan", "Nguyên Anh", "Hóa Thần"]
const LAYERS := 9
const BREAKTHROUGH_CHANCE := 0.75

var realm := 1          # chỉ số trong REALMS (bắt đầu: Luyện Khí)
var layer := 1          # tầng 1..9
var xp := 0.0           # tu vi trong tầng hiện tại
var qi := 0.0           # linh khí đã hấp thụ, chờ luyện hoá
var ready_breakthrough := false


func step_index() -> int:
	return (realm - 1) * LAYERS + (layer - 1)


func xp_needed() -> float:
	return 60.0 * pow(1.28, step_index())


func qi_max() -> float:
	return 100.0 + 40.0 * step_index()


func realm_name() -> String:
	return "%s tầng %d" % [REALMS[realm], layer]


## density: 1.0 ở nơi thường, cao hơn ở linh mạch.
func meditate(delta: float, density: float) -> void:
	qi = minf(qi_max(), qi + 10.0 * density * delta)
	if ready_breakthrough:
		changed.emit()
		return
	var amt := minf(qi, 4.0 * density * delta)
	qi -= amt
	add_xp(amt)


## Cộng tu vi (từ thiền hoặc đan dược), tự lên tầng khi đủ.
func add_xp(amount: float) -> void:
	if ready_breakthrough:
		return
	xp += amount
	while xp >= xp_needed():
		if layer < LAYERS:
			xp -= xp_needed()
			layer += 1
			Sfx.play("levelup")
			message.emit("Đột phá tiểu cảnh giới: %s" % realm_name())
		else:
			xp = xp_needed()
			ready_breakthrough = true
			message.emit("Tu vi đã viên mãn. Nhấn B để đột phá cảnh giới!")
			break
	changed.emit()


func try_breakthrough() -> void:
	if not ready_breakthrough:
		message.emit("Chưa đủ tu vi để đột phá.")
		return
	if realm >= REALMS.size() - 1:
		message.emit("Đã đạt cảnh giới cao nhất hiện có.")
		return
	if randf() < BREAKTHROUGH_CHANCE:
		realm += 1
		Sfx.play("breakthrough")
		layer = 1
		xp = 0.0
		qi = 0.0
		ready_breakthrough = false
		message.emit("ĐỘT PHÁ THÀNH CÔNG! Cảnh giới mới: %s" % realm_name())
	else:
		xp = xp_needed() * 0.5
		Sfx.play("fail")
		ready_breakthrough = false
		message.emit("Đột phá thất bại, tu vi tổn hao. Hãy tu luyện lại.")
	changed.emit()


func to_dict() -> Dictionary:
	return {"realm": realm, "layer": layer, "xp": xp, "qi": qi, "ready": ready_breakthrough}


func from_dict(d: Dictionary) -> void:
	realm = int(d.get("realm", 1))
	layer = int(d.get("layer", 1))
	xp = float(d.get("xp", 0.0))
	qi = float(d.get("qi", 0.0))
	ready_breakthrough = bool(d.get("ready", false))
	changed.emit()
