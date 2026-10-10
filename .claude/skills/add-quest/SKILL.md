---
name: add-quest
description: Thêm nhiệm vụ mới cho game Tu Tien 2D — Quests.QUESTS (loại mục tiêu, thoại NPC, phần thưởng, mở khoá theo chuỗi).
---

# Thêm nhiệm vụ

Trong `scripts/quests.gd` thêm dict vào cuối `QUESTS` (thứ tự = chuỗi mở khoá, xem `_unlocked`):

```gdscript
{
    "id": "q_moi", "title": "Tên nhiệm vụ", "giver": "elder", "turn_in": "elder",
    "desc": "Mô tả mục tiêu ngắn",
    "obj": {"type": "kill", "mob": "wolf", "target": 5},
    "intro": ["Thoại nhận…", "…"],
    "remind": "Thoại nhắc khi chưa xong.",
    "ready": ["Thoại trả nhiệm vụ."],
    "reward": {"stones": 30, "items": {"dan_tu_khi": 2}},
},
```

- Loại `obj.type` đã có: `meditate`, `collect` (kèm `item`), kill (`mob`), visit (`area`), craft, hit — xem `progress()`/`add_*` để biết khoá chính xác; cần loại mới thì thêm `add_xxx()` và gọi từ hệ thống tương ứng.
- `giver`/`turn_in` là id NPC (xem `Quests.npc_name`, `scripts/npc.gd`). NPC mới cần được tạo trong `main.gd`.
- Dữ liệu lưu: `to_dict()`; nhiệm vụ mới không làm hỏng save cũ.
- Kiểm tra bằng `smoke_test` và `save_test` (skill `godot-test`).
