extends SceneTree

func _initialize() -> void:
	var f := FontFile.new()
	f.load_dynamic_font("res://assets/fonts/VT323-Regular.ttf")
	var text := "ạảãàáâấầẩẫậăắằẳẵặđêếềểễệôốồổỗộơớờởỡợưứừửữựíìỉĩịúùủũụýỳỷỹỵóòỏõọéèẻẽẹ ĐÂÊÔƠƯĂ"
	var missing := ""
	for c in text:
		if not f.has_char(c.unicode_at(0)):
			missing += c
	print("thieu: [", missing, "] / ", text.length(), " ky tu")
	quit()