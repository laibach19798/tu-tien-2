# Hệ tu luyện V1.1

Triển khai trên Godot 4.7.2, tích hợp vào project hiện có. Các giá trị cân bằng trong `data/cultivation_v1.json` là **GIÁ TRỊ TEST**.

## Chơi thử

Mở `project.godot` bằng Godot và nhấn F6/F5 chạy scene chính. Nhân vật mới có màn hình roll 6 tiên thiên, 5 linh căn, 1 mệnh cách và chọn một trong 5 tông môn. Có thể học bí tịch ngoại phái.

- **J**: Công Pháp hoặc Pháp Bảo được chọn làm nguồn chính.
- **Space**: Thân Pháp, có cửa sổ né hoàn hảo khi thực sự nhận đòn.
- **Y** (hoặc N): tiên thiên, 6 ô trang bị, bí tịch, tham ngộ, thu thập, nhật ký.
- **E** gần Thương nhân: mua bí tịch phổ truyền/trang bị. Gần Chấp sự truyền pháp ở thị trấn hoặc người quản Tàng Kinh: đổi công huân lấy bí tịch theo cấp.
- Quan hệ cá nhân với Thanh Dao mở đường nhận bí tịch ngoại phái một lần. Hạ địch trong Linh Mạch Động nhận tàn quyển theo chu kỳ, tham ngộ để phục hồi.
- Đoạt bí tịch tông chủ ghi nguồn gốc và tăng thù hận. Phẩm chất và độ bảo mật là hai thuộc tính riêng.

## Kiến trúc và file

| Module | Trách nhiệm |
| --- | --- |
| `data/cultivation_v1.json` | 5 phái, 30 bí tịch, 7 món trang bị, mệnh cách, affix, trạng thái, hiệu ứng, giá và thông số test |
| `scripts/v1/catalog.gd` | Đọc và tra định nghĩa, pool affix |
| `scripts/v1/origin.gd` | Roll hợp lệ, seed, chuyển tiên thiên cũ |
| `scripts/v1/progression.gd` | Instance riêng, 6 slot, học/trang bị, cấp tông môn, nguồn gốc, tham ngộ, serialization |
| `scripts/v1/combat_resolver.gd` | Tính chi phí thực trả, event/condition/action, trạng thái, cooldown, trace và giới hạn chuỗi |
| `scripts/v1/runtime.gd` | Adapter với nhân vật, mục tiêu, va chạm, sinh lực, NPC, drop, bản đồ và save hiện hữu |
| `scripts/v1/cultivation_ui.gd` | Màn roll, trang bị, tooltip, thu thập và combat log |

Các điểm tích hợp: `main.gd`, `vitals.gd`, `sword_school.gd`, `sect.gd`, `sect_war.gd`, `sect_life.gd`, `journal.gd`, `hud.gd`, `pause_menu.gd`. Animation và asset nhân vật vẫn dùng cấu trúc cũ. Trang phục giữ chức năng thẩm mỹ; sức mạnh chiến đấu V1 đến từ ba ô trang bị mới, tránh cộng thêm nguồn ngoài thiết kế.

## Bản lưu cũ

Khóa mới `cultivation_v1` chứa origin, instance/affix/seed, trang bị, tiến độ nghiên cứu và quan hệ. Load không roll lại. Lưu giá trị tiên thiên/nội công/kiếm pháp cũ trong phần `legacy`; chuyển ngộ tính/thần thức về giới hạn mới và phân phối đủ tổng 300, linh căn cũ chuyển thành 20 mỗi hành. Nội công đang dùng ánh xạ sang Tâm Pháp tương ứng; bí tịch ngoại phái đã học chuyển sang định nghĩa V1. Cấp Chân Truyền/Trưởng Lão cũ được giữ khi thêm cấp Tinh Anh. ID tông môn cũ vẫn dùng làm alias cho bản đồ và chiến tranh có sẵn.

## Kiểm thử

Chạy tại thư mục project bằng Godot console:

```powershell
& '.\tools\Godot-4.7.2-stable-win64\app\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tools/cultivation_v1_test.gd
& '.\tools\Godot-4.7.2-stable-win64\app\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tools/cultivation_v1_integration.gd
```

- Core: 47 kiểm tra, gồm 3.000 seed, học chéo, trạng thái liên phái, chi phí 45→36 không kích Tụ Linh Châu, triệu hồi/chuỗi vòng, pháp bảo chủ lực, save roundtrip và migration cũ.
- Integration: 30 kiểm tra trên scene thật, gồm đòn trúng mộc nhân, né, dash va chạm, duy trì triệu hồi, NPC/cửa hàng/Tàng Kinh, tàn quyển, UI và ghi/đọc save trên đĩa. Dùng file save thử trong `tools`, không ghi save người chơi.
- `sect_life_test.gd`: regression đời sống tông môn, thi nội môn, nhiệm vụ, quan hệ và thưởng một lần; đã cập nhật kỳ vọng chỉ số cấp Chân Truyền từ 2 thành 3.
- `cultivation_v1_shot.gd`: chụp giao diện thật, không ghi save người chơi. Ảnh `tools/v1_*.png`.

T1–T12 được bao phủ bởi kiểm tra core/integration. T13 có kiểm tra nội dung tooltip và xem ảnh giao diện. Log môi trường có lỗi đọc certificate store; không làm thất bại kiểm tra gameplay. Regression đời sống tông môn còn cảnh báo 4 ObjectDB instance khi thoát, cần theo dõi riêng nếu tối ưu vòng đời node.

## Giới hạn bản này

Chiến đấu/triệu hồi dùng hiệu ứng hình học và asset hiện có, chưa có bộ hoạt ảnh riêng cho từng bí tịch. Tham ngộ, nguồn ngoại phái và hậu quả chiếm đoạt là bản tối thiểu. Các con số cần playtest cân bằng dài hơn. Không triển khai hệ tự sáng công pháp, kinh tế luyện khí toàn diện hoặc chính trị tông môn mới; cảnh giới/đột phá hiện có được giữ.

## Cập nhật V1.2

- **Đã gỡ hệ cũ**: bẩm sinh/Luân hồi (`innate`, `creation_ui`), nội công (`noi_cong`), công pháp ghép (`technique*`, `sect_arts`), các chiêu kiếm cũ (phi kiếm, vạn kiếm, kiếm khí) và sách `cp_*`/`nc_*`. `SwordSchool` chỉ còn trạng thái bái sư, kiếm đeo lưng, rung/khựng hình. Bản lưu cũ vẫn được chuyển sang V1 qua `legacy`; vật phẩm của hệ cũ trong túi bị bỏ khi tải.
- **Thưởng bộ trang phục** cộng thêm lên tiên thiên (tu vi, khí huyết, tốc độ, sát thương) trong `Runtime.apply_attributes`.
- **Điều kiện học/dùng** (`need` = `Cultivation.step_index()`): Nội Truyền 6 (Luyện Khí tầng 7), Chân Truyền 12 (Trúc Cơ tầng 4), Trấn Phái 18 (Kim Đan tầng 1); trang bị nặng 6–12. Bản lưu cũ được miễn.
- **Cân bằng siêu khó (GIÁ TRỊ TEST)**: sách 900 linh thạch, trang bị 1400, tham ngộ 300 linh thạch/90s, công huân 160 × hệ số bảo mật (1/1.5/3/6), tàn quyển mỗi 10 quái ở di tích, cứ 4 tàn quyển thì 1 phẩm Huyền.
- **Phẩm chất**: Tàng Kinh Các cho Linh (Nội Truyền) và Huyền (Chân Truyền/Trấn Phái); chiến lợi phẩm cướp được là Huyền; thương hội/NPC luôn là Thường.
- **Dòng phụ**: pool riêng theo bí tịch (`affix_pool`), thêm nhóm Điều kiện (`opportunist`, `finisher`), Chuyển hóa (`bloodthirst`), Kích hoạt (`windstep`), Tích lũy (`crit_qi`), Đánh đổi (`glass`).
- **Tông của người chơi** theo tông V1 đã chọn: `SectWar.PLAYER` là biến tĩnh, `Maps.refresh_sects()` dựng lại sân tông. Test: `tools/sect_switch_test.gd`.

## V1.3 — cân bằng theo mô phỏng

- **Công cụ**: `tools/build_sim.gd` (mọi tổ hợp Công–Tâm–Thân–pháp bảo × 4 kịch bản, dùng đúng `CombatResolver`), `tools/build_sim_analyze.py` (phương sai từng ô, hệ số phối hợp), `tools/balance_fit.py` (tự cân sát thương Công Pháp), `tools/balance_v1.py base` (bảng số gốc V1.3).
- **Tài nguyên khan hiếm**: hồi linh lực khi chiến đấu `qi_regen` = 1,5/s (trước 3), phí chiêu ×~2,5. Linh lực là ràng buộc thật; hiệu ứng hồi/hoàn linh lực có giá trị.
- **Họ trạng thái** (`family`: mark, dot, control, debuff, buff): Tâm Pháp nhận cả họ, không gắn tên một trạng thái. Điều kiện `family`, `families`, `target_family`; hiệu ứng có `scale` (theo lượng sự kiện gốc) và `pct` (theo tối đa).
- **Thân Pháp có vai trò riêng**: Thừa Thế (+40% sát thương), hồi linh lực, gây Hàn Khí/Suy Yếu/Hồn Ấn lên kẻ vừa đánh khi né hoàn hảo, nên Thân Pháp cấp trạng thái cho Tâm Pháp.
- **Sát thương có điều kiện theo họ trạng thái** (`conditional` trên bí tịch hoặc dòng phụ): Tâm Pháp chỉ tăng sát thương khi mục tiêu mang đúng họ (Ấn, sát thương theo thời gian, khống chế, suy yếu). Thừa Cơ/Phá Ấn cũng theo họ thay vì chỉ đếm tầng.
- **Kết quả đo cuối (3.000 tổ hợp có Công Pháp)**: dòng phụ sạch — Công/Tâm/Thân/pháp bảo giải thích 4,5/7,3/6,0/2,0% phương sai; hệ số phối hợp Công×Tâm 0,84–1,60 (p5–p95: 0,87–1,21); tổ hợp dưới 0,5: 0%. Dòng phụ roll thật — Công Pháp 15,5%, hệ số phối hợp 0,79–1,59.
- **Còn mở**: Dưỡng Huyết Kinh (+14%) và Phi Yến Bộ (+7%/+17% khi roll) vẫn nhỉnh; Liệt Phong Đao/Thanh Phong Kiếm còn lợi thế khi roll dòng phụ (+27%/+18%).

## V1.4 — bản sắc 5 tông môn

- `SectAmbience.STYLES` (khoá = id tông cũ) quy định tiền tố tài nguyên, bộ gạch sân, màu phủ nền/cột sáng/sương, kiểu hạt bay, binh khí tuần tra, màu ánh sáng. Mọi sân tông đều có kiếm trận, đảo bay, chim tuần, tháp riêng, bất kể ai là chủ.
- Tài nguyên theo tiền tố `kt` (Kiếm Tông), `xv` (Xích Viêm/Đao Môn), `hb` (Hàn Băng/Ngũ Hành), `dm` (Độc Môn/Huyền Thể), `hm` (Huyền Minh/Hồn Đạo): `<p>_tower`, `<p>_island`, `<p>_array`, `<p>_spire`, `<p>_bird_0..8`, gạch `assets/ground/<p>_{base,alt,path,rock}_{0..3}`. Thiếu ảnh thì dùng ảnh `kt_*`.
- Công cụ: `tools/fetch_pixellab.py` tải ảnh Pixellab về đúng chỗ; sau đó `tools/clean_bg.gd` + `tools/tidy_prop.gd`, rồi `--import`.

## Ô chiêu (4 ô trên thanh)
- J: nguồn chính (Công Pháp, hoặc Pháp Bảo với Bảo Tu). K: thứ còn lại trong {Công Pháp, Pháp Bảo}. U: Công Pháp phụ (ô `cong2`, cùng loại sách `cong`, một bản không ở cả hai ô). Space: Thân Pháp. Tâm Pháp tự kích hoạt.
- `cong2` hành xử như `cong` trong CombatResolver (qua `kind(slot)`): chi phí, discount, surge, điều kiện hiệu ứng theo `source_uid`. Hồi chiêu riêng.
