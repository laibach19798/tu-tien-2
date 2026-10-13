---
name: add-sfx
description: Thêm âm thanh (SFX/nhạc vùng) mới vào game Tu Tien 2D — âm thanh được tổng hợp bằng code trong scripts/sfx.gd, không dùng file audio.
---

# Thêm âm thanh

- Mọi SFX nằm trong `Sfx._make(id)` (bảng `match`). Thêm case mới dùng `_gen(dur, func(t, k): …)`; trạng thái thay đổi để trong mảng `st` (lambda bắt primitive theo giá trị).
- Gọi: `Sfx.play("id", pitch, vol_db)` — là no-op khi chưa `setup` (test headless an toàn).
- Nhạc nền theo vùng: `THEMES` (village/forest/sect/cave), đổi bằng `Sfx.set_theme`; vùng chọn trong `main.music_theme_at`. Tần số nhạc phải qua `_loopf` để vòng lặp không bị click.
- Bước chân: `Sfx.step(surface, run)` với `main.surface_at` (grass/stone/rock).
- Kiểm tra bằng `tools/sfx_check.gd` (in peak/tail/độ dài mọi âm) và `tools/music_test.gd`.
- Công tắc nhạc/SFX nằm trong pause menu, lưu ở `user://settings.cfg` [audio].
