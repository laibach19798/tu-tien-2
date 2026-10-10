---
name: add-map
description: Thêm map phụ (khu săn quái) mới cho game Tu Tien 2D — Maps.DEFS, cổng dịch chuyển, ảnh nền/prop bằng Pixellab, quái, đồ rơi theo map.
---

# Thêm map

Thế giới gốc ("overworld": làng, Hắc Lâm, Kiếm Tông, Hang Linh Mạch) không có quái. Quái nằm trong các map phụ, vào qua cổng dịch chuyển. Cơ chế đổi map: `main.gd` (`travel_to`, `switch_map_now`, `_enter_extra`, `_leave_map`); dữ liệu: `scripts/maps.gd`; dựng map: `scripts/map_builder.gd`.

1. **Ảnh nền** (Pixellab `create_tiles_pro`, `tile_type=square_topdown`, `tile_size=64`, `tile_view=top-down`, `outline_mode=segmentation`, mô tả đánh số `1). nền 2). nền phụ 3). đường mòn 4). đá`). Tải zip, ra 16 ảnh = 4 hàng x 4 biến thể. Lưu thành `assets/ground/<tên>_<base|alt|path|rock>_<0..3>.png` (hàng 0 = base, 1 = alt, 2 = path, 3 = rock).
2. **Prop riêng** (Pixellab `create_map_object`, `view=low top-down`, `detail=high detail`, `shading=detailed shading`, `outline=selective outline`; cao 64-160px). Tải về `assets/props/<tên>.png`. Có thể trả về nền đặc (xám): xoá nền bằng flood fill từ góc. Tên bắt đầu `tree`/`bush`/`bamboo` sẽ có hiệu ứng lay theo gió.
3. **Dữ liệu**: thêm mục vào `Maps.DEFS` (copy một map gần giống). Chú ý `entry` (chỗ đến, phải nằm trong `safe` và cách cổng ra > 56px), `gates` (cổng ra về `overworld`), `groups` (quái), `props`, `border`, `path`, `qi`, `areas`, `mm`.
4. **Cổng vào**: thêm vào `Maps.OVERWORLD_GATES` (`pos`, `to`, `label`, `tint`). `pos` và `pos + Maps.BACK_OFFSET` phải đi được; kiểm tra bằng `tools/map_test.gd`.
5. **Đồ rơi theo map**: `drop.region` trong `Wardrobe.ITEMS` là id map (ví dụ `"linh_mach_dong"`); thêm tên vào `Wardrobe.REGION_NAMES`.
6. **Nhiệm vụ / lời thoại** nhắc vị trí quái: sửa trong `quests.gd` và `main.gd` (`_lore`).
7. Kiểm tra: `tools/map_test.gd` (cổng, quái, đồ rơi, lưu/tải), chụp ảnh bằng `tools/map_demo.gd --write-movie`. Sau khi thêm/đổi ảnh PHẢI chạy `godot --headless --path . --import` (ảnh đổi mà chưa import lại thì game vẫn dùng bản cũ).

## Tiểu Thế Giới (chiến sự tông môn)
Map `tieu_gioi` (`"war": true`) dùng `MapBuilder._war_world`; dữ liệu 5 tông và 12 địa bàn nằm trong `scripts/sect_war.gd` (`SECTS`, `TERRITORIES`). Thêm địa bàn: thêm vào `TERRITORIES` (id, name, pos, owner, theme, type, income, guards cho địa bàn vô chủ) và tên vùng vào `areas` của map. Thêm tông: thêm vào `SECTS` (hq, color, theme, bộ trang phục disciple/elder). Chủ đề nền (`theme`) là tên bộ ảnh trong `assets/ground/` (meadow, swamp, snow, cave, lava, cobble). Test: `tools/war_test.gd`.

## Tông môn (map riêng mỗi tông)
Mỗi tông trong `SectWar.SECTS` tự sinh map `sect_<id>` (`Maps._sect_def`, khuôn chung `Maps.COMPOUND_*`, dựng bởi `MapBuilder._compound`). Trong Tiểu Thế Giới mỗi căn cứ chỉ có MỘT cổng vào tông. Điện: `Maps.COMPOUND_HALLS` (ảnh `assets/props/hall_*.png`, `sc` = tỉ lệ); chức năng điện Kiếm Tông gắn vào NPC ở `MapBuilder._compound_npcs` + `main.gd` (`_menu_options`, `_lore`): Chưởng Môn Điện (nhiệm vụ), Tàng Bảo Các (đổi đồ), Tàng Kinh Các (`_study_scripture`), Chiến Sự Đường (bảng chiến sự), Luyện Đan Phòng (lò), Diễn Võ Đường (mộc nhân), Trận Pháp Đường (`_teleport_territory`), Linh Tuyền Thiền Viện (thiền hồi khí huyết, `qi.heal`), Tàng Y Các (tiệm may). Đặc điểm riêng: `SECTS[...]["trait"]` (atk/def/freq/ambush/income), mái nhuộm màu `roof`, công trình riêng `assets/props/sig_<id>.png`. Ảnh Pixellab có nền đặc: chạy `tools/clean_bg.gd -- <tên prop>`. Test: `tools/compound_test.gd`.
