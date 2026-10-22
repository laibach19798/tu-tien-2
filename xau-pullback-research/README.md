# XAU/USD Trend Following + Pullback — Nghiên cứu định lượng

Thư mục nghiên cứu độc lập, **không liên quan đến game** Tu Tien 2D.
File `.gdignore` khiến Godot bỏ qua thư mục này.

Mục tiêu: kiểm tra xem thiết lập Trend Following + Pullback trên XAU/USD có
lợi thế thống kê sau chi phí hay không, và rủi ro có phù hợp giới hạn FTMO hay không.
Không giả định hệ thống có lợi nhuận.

## Trạng thái

| Bước | Nội dung | Trạng thái |
|---|---|---|
| 0 | Đặc tả v1.0 (của người dùng) | Xong |
| 1 | Đặc tả V1.1 — chốt các điểm mơ hồ (`spec/SPEC_V1_1.md`) | **Đề xuất, chờ duyệt** |
| 2 | Khung backtest + test logic trên dữ liệu tổng hợp | Chưa làm |
| 3 | Thu thập dữ liệu MT5 FTMO / nguồn phụ, kiểm tra chất lượng | Chưa làm |
| 4 | Backtest training → validation → holdout | Chưa làm |
| 5 | Mô phỏng FTMO | Chưa làm |
| 6 | Forward test demo | Chưa làm |

## Cấu trúc dự kiến

```
xau-pullback-research/
  spec/        đặc tả, nhật ký thay đổi
  src/         code backtest (Python)          — bước 2
  tests/       test logic trên dữ liệu tổng hợp — bước 2
  data/        dữ liệu thô và đã chuẩn hóa (không commit dữ liệu lớn)
  reports/     báo cáo chất lượng dữ liệu, kết quả
```
