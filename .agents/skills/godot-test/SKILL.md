---
name: godot-test
description: Chạy và viết test headless cho game Godot 4.7 (Tu Tien 2D) — smoke test, import lại tài nguyên, kiểm tra lỗi script. Dùng sau khi sửa code game hoặc khi thêm class_name mới.
---

# Chạy test headless

Godot nằm ở `tools/Godot-4.7.2-stable-win64/app/Godot_v4.7.2-stable_win64_console.exe`.

```bash
GODOT="tools/Godot-4.7.2-stable-win64/app/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path . --import                       # SAU KHI thêm class_name/ảnh/prop mới
"$GODOT" --headless --path . --script res://tools/smoke_test.gd
```

Các test có sẵn trong `tools/`: `smoke_test`, `smoke_swing`, `monster_test`, `save_test`, `expansion_test`, `wardrobe_test`, `skin_test`, `sfx_check`, `music_test`.

## Quy tắc
- Test là `extends SceneTree`; `_initialize()` đặt `OS.set_environment("TUTIEN_NO_SAVE", "1")` để KHÔNG ghi đè save thật, rồi instantiate `res://scenes/main.tscn`.
- Điều khiển theo frame trong `_process` (`match frame:`), in kết quả bằng `print`, kết thúc bằng `quit(code)`.
- `class_name` mới phải chạy `--import` trước, nếu không script khác báo "Identifier not found".
- Đọc output tìm `SCRIPT ERROR` / `Parse Error` — exit code 0 vẫn có thể có lỗi.
- Test mới: copy `tools/smoke_test.gd`, đặt tên `tools/<tên>_test.gd`; commit cả file `.uid` sinh ra nếu repo đang theo dõi.
