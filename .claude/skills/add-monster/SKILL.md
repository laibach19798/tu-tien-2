---
name: add-monster
description: Thêm loại quái mới (hoặc boss) cho game Tu Tien 2D — Monster.KINDS, sprite frames, rơi đồ, đặt vào bản đồ.
---

# Thêm quái

1. `scripts/monster.gd` → `KINDS`: copy một entry gần giống (`wolf`, `goblin`) rồi chỉnh: `hp, dmg, speed, aggro, leash, reach, windup, recover, xp, stones:[min,max], drops:{item:xác_suất}, frames, center, shadow, tint, sprite_tint, size, bar`. Boss thêm `"boss": true, "respawn": giây`.
2. Sprite: có thể tái dùng `res://character/monsters/<wolf|goblin>/frames.tres` + `sprite_tint`/`size` để tạo biến thể. Quái mới hoàn toàn: sinh ảnh bằng Pixellab rồi import qua `tools/import_monster.ps1`, chạy `--import`.
3. Đặt quái: thêm spawn trong `scripts/world_expansion.gd` (các vùng Hắc Lâm, Kiếm Tông, Hang Linh Mạch) hoặc `main.gd` cho làng. Tọa độ thế giới 4096x2816.
4. Thêm id vật phẩm rơi vào `scripts/items.gd` nếu mới (skill `add-item`); nhiệm vụ diệt quái dùng `Quests.add_kill(mob)`.
5. Kiểm tra: `tools/monster_test.gd`, `smoke_test.gd` (skill `godot-test`).
