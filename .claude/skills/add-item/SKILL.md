---
name: add-item
description: Thêm vật phẩm mới (đan dược, nguyên liệu, trang bị) vào game Tu Tien 2D — scripts/items.gd, cửa hàng, rơi đồ từ quái, phần thưởng nhiệm vụ.
---

# Thêm vật phẩm

1. Mở `scripts/items.gd`, thêm entry vào `DATA`:
   ```gdscript
   "dan_moi": {
       "name": "Tên hiển thị", "desc": "Mô tả ngắn.",
       "sell": 12, "buy": 30, "usable": true, "qi": 40,   # hiệu quả: "xp" | "qi" | "hp"
       "icon": "pill", "tint": Color(0.4, 0.8, 0.5),
   },
   ```
   - `buy = 0`: không bán ở shop; `sell = 0`: không thu mua; `usable=false` cho nguyên liệu.
   - `icon` phải có trong `UIKit.ICONS` (pill, herb, fang, hide…); muốn icon mới → thêm vào `scripts/ui_kit.gd`.
2. Nguồn có được vật phẩm (chọn tuỳ ý):
   - Quái rơi: thêm `"id": xác_suất` vào `drops` của kind trong `Monster.KINDS`.
   - Shop: tự xuất hiện nếu `buy > 0` (xem `scripts/shop.gd`).
   - Nhiệm vụ: `"reward": {"items": {"id": n}}` trong `Quests.QUESTS`.
   - Luyện đan: xem `scripts/alchemy_ui.gd` / `furnace.gd`.
3. Kiểm tra: `--import` rồi chạy `smoke_test` (skill `godot-test`).
