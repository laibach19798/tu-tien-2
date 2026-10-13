# Đời sống Kiếm Tông — bản đầu tiên

Mở dự án gốc `project.godot`, chạy game và nhấn **H** để xem sư môn, lịch sinh hoạt, vị trí NPC và mục tiêu hiện tại. **E** trò chuyện; **H/Esc** đóng bảng.

## Hành trình

1. Gia nhập Kiếm Tông qua Kiếm sư Lăng Tiêu như trước.
2. Đến sân Kiếm Tông phía nam làng, gặp **Mặc Trần**. Đánh trúng mộc nhân cạnh Lăng Tiêu 10 lần rồi báo cáo.
3. Qua cổng phía tây làng tới **Sói Lĩnh**, gặp **Lục An** ở gần lối vào `(460, 960)`.
4. Chọn cứu người (hạ 3 sói), phối hợp Hàn Phong (thiện cảm tối thiểu 15; hạ 2 sói), hoặc ưu tiên thành tích (hạ 5 sói). Chỉ sói bị hạ tại Sói Lĩnh sau khi chọn nhánh mới được tính.
5. Nhánh cứu người phải quay lại đón Lục An; nhánh thành tích báo cáo thẳng với Mặc Trần. Nhận 100 cống hiến và linh thạch, đúng một lần.
6. Gặp Mặc Trần để khảo hạch: được đưa tới sân mộc nhân, đánh trúng 12 lần trong 60 giây. Đóng các giao diện để thời gian thi tiếp tục. Thất bại có thể thi lại miễn phí. Rời bản đồ hoặc trọng thương hủy lượt thi.
7. Sau khi đỗ, trở lại bái Mặc Trần làm sư phụ và nhận bí kíp nếu chưa có. Người cứu Lục An được nhận quà cảm ơn một lần.

## Quan hệ và sinh hoạt

- Bốn NPC: Mặc Trần, Thanh Dao, Lục An, Hàn Phong.
- Buổi sáng: sân luyện kiếm; chiều: sân trước Chấp Sự Đường; tối: sân tĩnh tu. NPC đi theo đường tìm từ va chạm thực tế; gặp họ ở bất kỳ buổi nào đều có thể tiếp tục nhiệm vụ.
- Trò chuyện +5, quà Hồi Huyết Đan +3, mỗi hoạt động một lần/người/ngày trong game. Hoạt động thường chỉ nâng quan hệ tới 35; quyết định trong nhiệm vụ mở các mức cao hơn.
- Sổ H ghi lại những kỷ niệm quan trọng; trò chuyện thường không ghi đè chuyện cứu người hay bỏ lại đồng môn.
- Lục An vắng mặt ở tông môn trong thời gian mắc kẹt tại Sói Lĩnh.

## Lưu game và chức vị

Trạng thái xã hội nằm trong khóa JSON `sect_life`. `Inventory.inner_exam_passed` kiểm soát chức vị và quyền mua đồ nội môn. Cống hiến dùng được và tổng cống hiến vẫn riêng biệt.

Bản lưu cũ đã có ít nhất 100 tổng cống hiến được giữ chức vị, không phát lại thưởng. Bản mới cần vượt khảo hạch. Sau nội môn, các chức vị cao hơn vẫn tăng theo tổng cống hiến. Lượt thi đang dở không tiếp tục khi tải game, nhưng có thể đăng ký lại.

## Phạm vi

Bản này có một chuỗi nhiệm vụ phân nhánh và khảo hạch bằng mộc nhân. Chưa có AI đồng đội đi theo/chiến đấu, đấu tay đôi với Hàn Phong, nhiệm vụ riêng dài cho từng NPC hay khảo hạch chân truyền/hộ pháp. Nhánh phối hợp thể hiện hỗ trợ của Hàn Phong qua hội thoại và giảm số sói cần hạ.

## Kiểm tra

- `tools/sect_life_test.gd`: các nhánh, giết quái thực tế, JSON lưu/tải, chuyển map, giới hạn ngày, quà một lần, đường đi sinh hoạt, điều kiện chức vị và tương thích save cũ.
- `tools/sect_life_shot.gd`: ảnh bảng sư môn và sân sinh hoạt, không ghi save.
- Chạy kiểm tra với Godot: `--headless --path . --script res://tools/sect_life_test.gd`.

Mã chính ở `scripts/sect_life.gd`; `main.gd` nối các sự kiện NPC, đánh mộc nhân, hạ quái, đổi map và lưu/tải.
