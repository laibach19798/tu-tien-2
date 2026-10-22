# XAU/USD Trend Following + Pullback — Đặc tả V1.1 (ĐỀ XUẤT, CHỜ DUYỆT)

Trạng thái: **Đề xuất**. Chưa đóng băng. Chưa có dữ liệu, chưa có kết quả.
Cơ sở: tài liệu "Data Specification & Quantitative Backtest Plan" v1.0.

V1.1 không thêm ý tưởng giao dịch mới. Nó chỉ thay mọi chỗ còn phải "tự hiểu"
trong v1.0 bằng một quy tắc có số cụ thể, để code không chứa tham số ẩn.
Mọi giá trị dưới đây là **giá trị khởi tạo được đăng ký trước**, không phải
giá trị tối ưu. Sau khi duyệt, file này được đóng băng; mọi thay đổi về sau là
một phiên bản mới (V1.2, V2…) và phải ghi vào mục 12 "Nhật ký thay đổi".

Ký hiệu: `[i]` là nến M15 thứ i; mọi giá trị chỉ báo `X[i]` được tính **tại
lúc đóng nến i**, chỉ dùng dữ liệu đến hết nến i.

---

## 1. Quy ước dữ liệu và thời gian

| # | Quyết định |
|---|---|
| 1.1 | `timestamp_utc` là **thời điểm mở nến**, chuẩn hóa về UTC. Nến M15 mở lúc `t` đóng lúc `t+15m`; nến H1 mở lúc `h` đóng lúc `h+1h`. |
| 1.2 | OHLC gốc là giá **bid** (mặc định của MT5). Giá ask được dựng bằng `ask = bid + spread`. Nếu nguồn có bid/ask thật thì dùng giá thật và ghi `source`. |
| 1.3 | Cột `spread` của MT5 là spread **nhỏ nhất** trong nến, nên đánh giá thấp chi phí. Spread mô hình = `max(spread_nến, trung vị spread cùng giờ-trong-tuần của 4 tuần trước)`. |
| 1.4 | Giờ server MT5 được chuyển về UTC bằng bảng lệch múi giờ có ghi DST; bước kiểm tra chất lượng phải xác nhận nến cuối tuần mở/đóng đúng giờ thị trường vàng. |

## 2. Chỉ báo

| # | Quyết định |
|---|---|
| 2.1 | EMA: `α = 2/(n+1)`, khởi tạo bằng SMA của n giá đóng cửa đầu tiên. |
| 2.2 | ATR(14): True Range, làm mượt kiểu Wilder (`α = 1/14`), khởi tạo bằng SMA 14 TR đầu tiên. *Lưu ý: ATR mặc định của MT5 dùng SMA; khi đối chiếu với biểu đồ MT5 sẽ thấy chênh lệch nhỏ — chấp nhận, không đổi.* |
| 2.3 | Warm-up: bỏ mọi tín hiệu trước khi có đủ **1.000 nến H1** và **500 nến M15** tính từ đầu dữ liệu, và sau mỗi khoảng trống dữ liệu bị đánh dấu lỗi > 1 ngày giao dịch. |

## 3. Ghép H1 với M15 (điểm A1, A2)

| # | Quyết định |
|---|---|
| 3.1 | Nến M15 `[i]` (đóng lúc `T`) dùng **nến H1 đã đóng gần nhất có thời điểm đóng ≤ T**. Ví dụ: M15 09:45–10:00 dùng H1 09:00–10:00; M15 10:00–10:15 cũng dùng H1 09:00–10:00. |
| 3.2 | `trend[i]` ∈ {UP, DOWN, NONE} theo đúng 3 điều kiện của v1.0 §3.1, so EMA50 hiện tại với EMA50 của **5 nến H1 trước** (`EMA50[h] vs EMA50[h−5]`). |
| 3.3 | Xu hướng phải hợp lệ và **cùng chiều** tại **mọi nến M15** từ lúc bắt đầu theo dõi pullback đến nến trigger. Nếu mất xu hướng giữa chừng → hủy nhịp, `rejection_reason = trend_lost`. |

## 4. Pullback (điểm A3–A8) — mô tả cho Buy, Sell đối xứng

Máy trạng thái: `IDLE → TRACKING → TOUCHED → (SIGNAL | hủy) → IDLE`.

| # | Quyết định |
|---|---|
| 4.1 | **Bắt đầu:** tại nến `k` khi `close[k] < close[k−1]` **và** `close[k−1] < close[k−2]`. Nến `k−1` là *nến đầu nhịp hồi*; theo dõi bắt đầu tại nến `k` (đang `trend = UP`). |
| 4.2 | **Cửa sổ chạm:** phải có nến chạm EMA20 trong các nến `k … k+7` (8 nến, **tính cả nến k**). Hết cửa sổ chưa chạm → `no_touch`. |
| 4.3 | **Chạm:** nến `j` chạm khi `low[j] ≤ EMA20[j]`. |
| 4.4 | **Độ sâu (diễn giải "0,15 ATR"):** đây là **độ xuyên qua EMA20**, không phải vùng "gần EMA". Gọi `PL[j] = min(low[k−1 … j])` là đáy nhịp hồi đến nến j. Điều kiện: `EMA20[j] − PL[j] ≤ 0,15 × ATR[j]`. Kiểm tra tại nến chạm **và** tại mọi nến sau đó cho đến trigger. Vi phạm → hủy nhịp, `too_deep` (không chờ nến khác). |
| 4.5 | **Hạn chờ trigger:** nến trigger phải là nến chạm `j` hoặc một trong **4 nến sau đó** (`j … j+4`). Quá hạn → `trigger_expired`. |
| 4.6 | **Trigger Buy:** `close[s] > open[s]` và `close[s] > high[s−1]`. (Sell: `close[s] < open[s]` và `close[s] < low[s−1]`.) |
| 4.7 | **`pullback_extreme`:** Buy = `min(low[k−1 … s])`, **gồm cả nến trigger**; Sell = `max(high[k−1 … s])`. |
| 4.8 | **Không đếm trùng:** khi một nhịp kết thúc (ra tín hiệu hoặc bị hủy), nhịp mới chỉ được bắt đầu bởi một cặp 2 nến giảm mới nằm **hoàn toàn sau** nến kết thúc. Tại mỗi thời điểm chỉ theo dõi tối đa một nhịp mỗi chiều. |

## 5. Entry, SL, TP và khớp lệnh (điểm A9–A11)

| # | Quyết định |
|---|---|
| 5.1 | Vào lệnh tại **open của nến `s+1`**. Buy khớp `ask_open + slippage_entry`; Sell khớp `bid_open − slippage_entry`. |
| 5.2 | **SL dự kiến:** Buy `= extreme − 0,2 × ATR[s]` (mức bid); Sell `= extreme + 0,2 × ATR[s]` (mức ask). |
| 5.3 | **Bỏ lệnh — "đi quá xa":** nếu `|open[s+1] − close[s]| > 0,5 × ATR[s]` → `gap_too_far`. |
| 5.4 | **Bỏ lệnh — SL đã bị chạm:** Buy nếu `bid_open[s+1] ≤ SL`; Sell nếu `ask_open[s+1] ≥ SL` → `sl_already_hit`. |
| 5.5 | **R** `= |giá khớp thực tế − SL|` (đã gồm spread và slippage). Bỏ lệnh nếu `R < max(0,5 × ATR[s], 3 × spread)` → `sl_too_tight`, hoặc `R > 4 × ATR[s]` → `sl_too_wide`. |
| 5.6 | **TP** `= giá khớp ± RR × R`, RR ∈ {2, 3, 5, 7}. |
| 5.7 | **Kích hoạt thoát:** Buy đóng ở bid — SL khi `low_bid ≤ SL`, TP khi `high_bid ≥ TP`. Sell đóng ở ask — SL khi `high_bid + spread ≥ SL`, TP khi `low_bid + spread ≤ TP`. |
| 5.8 | **Giá thoát:** SL khớp tại `SL − slippage_stop` (Buy) / `SL + slippage_stop` (Sell). Nếu nến **mở gap qua SL** → khớp tại giá open (bất lợi hơn) trừ slippage. TP khớp **đúng tại TP**, kể cả khi gap qua TP (không ghi nhận phần lợi do gap). |
| 5.9 | **SL và TP cùng nến M15** (kể cả nến vào lệnh): tra dữ liệu M1 nếu có. Nếu vẫn không phân định được trong một nến M1, hoặc không có M1 → **tính là SL**. Ghi `exit_reason = sl_ambiguous` để đếm riêng. |

## 6. Chi phí

| Tham số | Cơ sở | Kịch bản bất lợi (stress) |
|---|---|---|
| Spread | theo 1.3 | × 2 |
| `slippage_entry` | 0,10 USD/oz | 0,30 USD/oz |
| `slippage_stop` | 0,10 USD/oz | 0,50 USD/oz |
| Commission | **lấy từ thông số hợp đồng FTMO** (chưa có — để trống, không đoán) | × 1,5 |
| Swap | lấy từ thông số FTMO, tính theo số lần qua mốc rollover; thứ Tư × 3 nếu FTMO áp dụng | × 1,5 |

Các số USD/oz là **giả định ban đầu**, sẽ thay bằng số đo được trong forward test.

## 7. Giữ lệnh và cuối tuần (điểm A12)

| # | Quyết định |
|---|---|
| 7.1 | Được giữ lệnh qua đêm (tính swap). |
| 7.2 | **Không giữ qua cuối tuần:** đóng mọi vị thế tại **close của nến M15 kết thúc 15 phút trước giờ đóng cửa thứ Sáu** theo lịch giao dịch FTMO (`exit_reason = weekend_close`). Không mở lệnh mới trong **2 giờ** cuối cùng trước giờ đóng cửa thứ Sáu (`pre_weekend`). Giờ đóng cửa lấy theo lịch đã biết trước, không suy ra từ khoảng trống dữ liệu (tránh look-ahead). |
| 7.3 | Không có bộ lọc phiên (đúng v1.0). Ngày nghỉ lễ thị trường đóng sớm: xử lý như 7.2 theo lịch giờ giao dịch. |

## 8. Quản trị lệnh và ngày giao dịch (điểm A13–A14)

| # | Quyết định |
|---|---|
| 8.1 | **Ngày giao dịch** bắt đầu lúc **00:00 giờ Europe/Prague** (múi giờ reset ngày của FTMO), áp dụng cho mọi quy tắc theo ngày, kể cả trong backtest nghiên cứu. |
| 8.2 | Tối đa 1 vị thế. Tín hiệu đến khi đang có vị thế → ghi lại, `position_open`. |
| 8.3 | Tối đa 3 lệnh **đã khớp** mỗi ngày giao dịch. Vượt → `daily_cap`. |
| 8.4 | **Dừng ngày −1%:** `P&L ngày = P&L đã đóng trong ngày + P&L thả nổi (mark-to-market tại close nến M15)` so với `equity lúc 00:00 Prague`. Khi ≤ −1% → không mở lệnh mới đến hết ngày (`daily_loss_stop`). Lệnh đang mở **không** bị đóng bởi quy tắc này (giữ đúng V1: không can thiệp SL/TP). |
| 8.5 | **Rủi ro mỗi lệnh** `= 0,25% × equity tại close nến s` (khi không có vị thế mở thì equity = balance). |
| 8.6 | **Khối lượng:** `lots = floor_to_step( risk_amount / (R × contract_size + commission_khứ_hồi_mỗi_lot) )`. Nếu `lots < min_lot` → `size_below_min`. Nếu làm tròn khiến rủi ro thực < 50% ngân sách → vẫn vào, ghi `risk_amount` thực tế. |

## 9. Hai chế độ chạy (để so sánh RR công bằng)

| Chế độ | Mô tả | Dùng cho |
|---|---|---|
| **Signal-level** | Mỗi tín hiệu được mô phỏng độc lập, **không** áp 8.2–8.4 và rủi ro cố định 1R. Tập tín hiệu giống hệt nhau cho cả 4 mức RR. | So sánh RR thuần túy, ước lượng expectancy và khoảng tin cậy. |
| **Portfolio** | Áp đủ mục 7–8, equity thay đổi theo thời gian. | Drawdown, chuỗi thua, mô phỏng FTMO. |

Lưu ý: trong chế độ Portfolio, RR lớn giữ lệnh lâu hơn nên chặn nhiều tín hiệu
hơn — đây là khác biệt thật, phải báo cáo, không phải lỗi.

## 10. Chia dữ liệu và kiểm định (thiết kế chống overfitting)

| # | Quyết định |
|---|---|
| 10.1 | Chia theo thời gian 60 / 20 / 20. Ngưỡng tối thiểu (chế độ Signal-level): training ≥ 200 tín hiệu khớp, validation ≥ 100, holdout ≥ 100. Không đạt → chuyển sang **walk-forward neo gốc** (anchored), 1 lần quyết định, ghi vào nhật ký **trước** khi xem kết quả validation. |
| 10.2 | **Phép chọn duy nhất** trên validation: chọn 1 trong 4 mức RR. Không có tham số nào khác được chọn bằng dữ liệu. |
| 10.3 | **Độ nhạy (chỉ trên training, chỉ để kiểm tra độ bền, không dùng để chọn)** — thay **một** tham số mỗi lần, giữ nguyên phần còn lại: ngưỡng xuyên ATR {0,10; 0,15; 0,25}; cửa sổ chạm {6; 8; 10}; đệm SL {0,1; 0,2; 0,3}; hạn trigger {2; 4; 6}; cặp EMA H1 {(50,200); (34,144)}. Tổng 9 biến thể phụ × 4 RR. Yêu cầu: kết quả quanh giá trị gốc là "cao nguyên", không phải một đỉnh đơn lẻ. |
| 10.4 | **Baseline ngẫu nhiên:** trên các nến có `trend` hợp lệ, vào lệnh ngẫu nhiên cùng chiều xu hướng, khoảng SL lấy mẫu từ phân phối `R/ATR` của V1, cùng RR, cùng chi phí; 1.000 lần chạy. **Lợi thế của V1 = E_R(V1) − E_R(baseline).** Bắt buộc vì giai đoạn 2023–2026 vàng tăng mạnh. |
| 10.5 | Báo cáo **Long/Short riêng**, theo từng năm, và E_R sau khi **bỏ 5% lệnh thắng lớn nhất**. |
| 10.6 | **Khoảng tin cậy:** stationary block bootstrap trên chuỗi net R (độ dài khối trung bình 10 lệnh), 10.000 lần lặp, CI 95%. |

## 11. Tiêu chí đạt — đăng ký trước (đề xuất)

Đánh giá trên **validation** (chế độ Signal-level, RR đã chọn):
1. Cận dưới CI 95% của E_R ròng > 0.
2. E_R(V1) vượt E_R(baseline ngẫu nhiên) ở mức trên phân vị 95% của baseline.
3. E_R vẫn > 0 với chi phí stress (mục 6).
4. E_R vẫn > 0 sau khi bỏ 5% lệnh thắng lớn nhất.
5. Cả Long và Short không âm rõ rệt (nếu một chiều âm có ý nghĩa thống kê → ghi nhận, không tự ý bỏ chiều đó trong V1).

Đánh giá trên **holdout** (đóng băng, chỉ chạy một lần):
6. E_R ròng > 0 và ≥ 50% E_R của validation.

Chế độ **Portfolio** ở rủi ro 0,25%:
7. Max drawdown tổng < 5% và không ngày nào lỗ > 1,5% (giới hạn nội bộ, đặt thấp hơn mọi giới hạn FTMO).

Không đạt 1–4 → V1 bị loại hoặc "chưa kết luận" theo v1.0 §10. Không đạt 6 → không chuyển sang mô phỏng FTMO.

## 12. Còn để ngỏ (cần dữ liệu hoặc quyết định của bạn)

- Chương trình FTMO (2-Step hay 1-Step) — chỉ cần chốt trước bước mô phỏng FTMO.
- Thông số hợp đồng XAU/USD của FTMO: contract size, min lot, lot step, commission, swap, giờ giao dịch, giờ server.
- Độ dài lịch sử thực tế lấy được từ MT5 demo FTMO; có M1 hay không.

## 13. Nhật ký thay đổi

| Ngày | Phiên bản | Thay đổi | Lý do | Đã xem dữ liệu validation/holdout chưa? |
|---|---|---|---|---|
| 2026-10-22 | V1.1-đề xuất | Chốt các điểm mơ hồ của v1.0 | Đóng băng trước khi code | Chưa |
