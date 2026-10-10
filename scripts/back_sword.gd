extends SwordVisual
## Kiếm đeo lưng của trang phục (slot "sword"): chuôi nhô qua vai, vỏ chạy chéo xuống hông.
## Dùng bảng tư thế của Kiếm Tông (SwordSchool.SHEATH_POSE). Quay lưng thì nằm trước thân, còn lại nằm sau thân.
## Khi nhân vật đang vung kiếm (meta "sword_drawn") thì ẩn đi, vì kiếm đang ở trên tay.

const POSE_BASE_ANGLE := 0.0


func _ready() -> void:
	sheath = true
	length = 26.0


func _process(_delta: float) -> void:
	var parent := get_parent()
	visible = not bool(parent.get_meta("sword_drawn", false))
	var facing := Dir.normalize(str(parent.get("facing")) if parent.get("facing") != null else "south")
	var pose: Array = SwordSchool.SHEATH_POSE.get(facing, SwordSchool.SHEATH_POSE["south"])
	position = pose[0]
	rotation = deg_to_rad(float(pose[1]))
	_order(bool(pose[2]), parent)


func _order(in_front: bool, parent: Node) -> void:
	# chỉ đổi thứ tự khi cần để không giành chỗ với hào quang và áo choàng linh khí
	if in_front:
		var hair_front := parent.get_node_or_null("HairFront")
		if hair_front != null and get_index() < hair_front.get_index():
			parent.move_child(self, parent.get_child_count() - 1)
	else:
		var hair_back := parent.get_node_or_null("HairBack")
		if hair_back != null and get_index() > hair_back.get_index():
			parent.move_child(self, hair_back.get_index())
