---
name: godot-gdscript-conventions
description: Quy ước viết GDScript cho game Tu Tien 2D (Godot 4.7) — cấu trúc thư mục, phong cách, bẫy line-ending CRLF, lambda capture. Đọc trước khi sửa/viết script trong scripts/.
---

# Quy ước code

- Engine: Godot 4.7, GDScript, renderer gl_compatibility, viewport 1280x720, pixel art (filter nearest).
- Script game ở `scripts/`, scene ở `scenes/` (entry: `scenes/main.tscn` + `scripts/main.gd`), công cụ/test ở `tools/`.
- Dữ liệu tĩnh dạng `const DATA := {…}` trong class `RefCounted` có `class_name` (vd `Items`, `Monster.KINDS`, `Quests.QUESTS`). Thêm nội dung = thêm entry, không viết logic mới.
- Comment `##` và chuỗi hiển thị bằng **tiếng Việt có dấu**; id/biến dùng ASCII không dấu (`dan_tu_khi`, `soi_nanh`).
- UI dựng bằng code qua `UIKit` (`scripts/ui_kit.gd`), không dùng scene editor.
- Cẩn thận:
  - `scripts/main.gd` dùng **CRLF** — chuẩn hoá trước khi replace chuỗi nhiều dòng (Edit có thể không khớp).
  - Lambda bắt biến primitive **theo giá trị** → giữ trạng thái đổi trong `Array`/`Dictionary`.
  - `scripts/wardrobe.gd` có thể bị session khác sửa; grep id hiện tại trước khi gán outfit cho NPC.
  - Thêm `class_name` → chạy `--import` (xem skill `godot-test`).
  - Tài nguyên mới (ảnh, prop) phải được import mới thấy bằng `ResourceLoader.exists`.
- Sau khi sửa: chạy `smoke_test` + test liên quan. Lưu game phải tương thích ngược (`to_dict`/`from_dict` dùng `.get(key, default)`).
