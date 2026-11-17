# Thiết kế warehouse và chỉ số Olist

**Trạng thái: thiết kế logic và hợp đồng measure đã chốt theo snapshot; chưa triển khai hoặc xác minh trên SSAS.** Quy ước về đơn có nhiều nhóm, payment theo số tiền từng dòng và cohort dự đoán đã được chốt. Một đơn có thể đóng góp vào nhiều phương thức đúng theo các dòng thanh toán; không chọn một phương thức chính hoặc gộp thành một loại “All”. Bằng chứng snapshot: [kiểm tra dataset](2_Dataset/KIEM_TRA_DATASET.md); đề cương gốc tại `references/`. Các giới hạn triển khai SSAS được ghi rõ bên dưới và phải được kiểm tra trong lúc build.

## Phạm vi dữ liệu và ngày

- Tập phân tích: order status khác `canceled`, `unavailable` **và có ít nhất một order item**. Tất cả các measure dưới đây dùng tập này; 8 đơn đủ trạng thái nhưng không item được ghi riêng trong báo cáo kiểm soát, không tính vào Order Count. Trạng thái khác vẫn được giữ; đây là doanh thu theo đơn trong tập phân tích, không phải doanh thu đã quyết toán.
- Ngày phân tích chung là **ngày đặt hàng** `order_purchase_timestamp` theo ngày lịch trong dữ liệu nguồn. Ngày giao và ngày dự kiến chỉ dùng tính thời gian/trễ. Không tự gán múi giờ vì CSV không có offset. `DateKey = YYYYMMDD`; tuần ISO thứ hai = 1 đến chủ nhật = 7, không phụ thuộc `DATEFIRST`.
- `Revenue` = tổng `order_items.price`, không gồm freight, không phải thanh toán thực tế; `Freight Value` = tổng `order_items.freight_value`. Đơn vị BRL, tiền lưu `decimal(19,2)`. `Payment Amount` = tổng `payment_value` ở từng dòng thanh toán; không suy ra bằng Revenue. Điều chỉnh Câu 4/10 so với đề cương: đo **số tiền thanh toán**, không gọi là doanh thu sản phẩm.
- Một đơn được tính một lần trong mỗi danh mục/seller mà đơn có ít nhất một item tương ứng. Từng nhóm đúng theo ngữ cảnh của nó; tổng số đơn/review các nhóm có thể lớn hơn tổng chung. Review là đánh giá **đơn hàng**, không phải đánh giá riêng seller hay sản phẩm.

## Mô hình đề xuất

Ba measure group với grain riêng, các dimension dùng chung và `DimOrder` làm cầu. Đây là fact constellation (các star dùng chung dimension), không phải star đơn 1 fact/5 dimension trong đề cương; mô tả rõ trong báo cáo.

| Bảng | Grain, khóa và cột chính |
| --- | --- |
| `DimDate` | `DateKey int` PK; `FullDate date` unique, Year, Quarter, Month, Day, MonthName, ISOWeekdayNo/Name. Hierarchy Year → Quarter → Month → Date; key quarter = year+quarter, month = year+month. Bao phủ toàn bộ ngày đặt hàng, kiểm tra biên khi nạp. |
| `DimCustomer` | `CustomerKey int` PK; `CustomerID char(32)` unique, `CustomerUniqueID char(32)`, City, State, Region; `CustomerID` là ID trên từng đơn, `CustomerUniqueID` dùng phân biệt người mua. City key theo cặp State+City; state/region không biết = Unknown. |
| `DimProduct` | `ProductKey int` PK; `ProductID char(32)` unique, CategoryOriginal, CategoryEnglish, WeightG nullable. Category gốc thiếu = `Unknown`; thiếu bản dịch nhưng có tên gốc giữ tên gốc và đánh dấu thiếu bản dịch, không gom mất vào unknown. |
| `DimSeller` | `SellerKey int` PK; `SellerID char(32)` unique, City, State, Region; city key State+City, unknown như customer. |
| `DimPayment` | `PaymentKey int` PK; `PaymentType` unique (`credit_card`, `boleto`, `debit_card`, `voucher`, giá trị khác/unknown nếu xuất hiện). Không tạo dòng thanh toán giả cho đơn thiếu payment. |
| `DimOrder` | `OrderKey int` PK; `OrderID char(32)` unique. Dimension nối `FactSales`, `FactOrder`, `FactPayment`; có thể ẩn khỏi báo cáo thông thường. |
| `FactSales` | Một order item, unique `(OrderKey, OrderItemID)`; FK DateKey, CustomerKey, ProductKey, SellerKey, OrderKey; Quantity = 1, Price, FreightValue. Không join thẳng payment hay review nhiều dòng. |
| `FactOrder` | Một order trong tập phân tích, `OrderKey` PK/FK; FK DateKey, CustomerKey; ReviewScore nullable, ReviewPresent 0/1, DeliveryDays nullable, DeliveredFlag 0/1, LateFlag 0/1 nullable, LateEligibleFlag 0/1. Chỉ một review chọn theo quy tắc dưới đây. |
| `FactPayment` | Một dòng `(OrderKey, PaymentSequential)` unique; FK OrderKey, DateKey, CustomerKey, PaymentKey; PaymentValue và PaymentInstallments. Giữ mọi dòng payment thực tế của các đơn trong tập; đơn không payment không tạo dòng giả. |

SSAS Multidimensional: measure groups Sales, Orders và Payments. Date/Customer liên kết regular với cả ba; Order liên kết regular với cả ba. Product và Seller regular với Sales; với Orders, dùng many-to-many qua measure group Sales và dimension Order, có khóa/quan hệ trong DSV theo [hướng dẫn Microsoft](https://learn.microsoft.com/en-us/analysis-services/multidimensional-tutorial/lesson-5-3-defining-a-many-to-many-relationship?view=sql-analysis-services-2025). Không mặc định Payment có quan hệ với Product/Seller: các câu 4/10 chỉ dùng Payment, Date và Customer. Ẩn hoặc chặn các tổ hợp không được hỗ trợ; không để SSAS trả grand total như thể đã lọc. Nếu cần lọc đồng thời Product và Seller cho chỉ số theo đơn, phải test ngữ nghĩa cùng item: các quan hệ many-to-many riêng có thể chỉ giao tập đơn, không đảm bảo product và seller thuộc cùng item. Không công bố kết quả tổ hợp đó nếu chưa chứng minh đúng; thêm bridge order–product–seller hoặc cách lọc khác nếu cần.

## ETL và tính tái lập

1. Nạp CSV vào staging giữ business key và timestamp gốc. Kiểm tra uniqueness trước join; tách lỗi có lý do, số dòng và số tiền, không loại âm thầm. Dùng mapping bang Brazil đầy đủ trong đề cương, so sánh mã chính xác và có Unknown riêng, không mặc định bang lạ là Norte.
2. Với review, chọn đúng một dòng trên mỗi order bằng `ROW_NUMBER` theo `review_creation_date DESC, review_answer_timestamp DESC, review_id DESC, review_score DESC`. Review count là số **đơn có review được chọn**, không phải tổng số review gốc. Lưu ID/ngày nguồn để truy vết. Giá trị rỗng không biến thành 0 score.
3. `DeliveryDays = DATEDIFF(day, CAST(purchase AS date), CAST(delivered AS date))` khi có ngày giao; `DeliveredFlag = 1` khi có ngày giao, không dựa riêng vào status. `LateEligibleFlag = 1` khi có cả ngày giao và ngày dự kiến; `LateFlag = 1` nếu ngày giao lịch > ngày dự kiến lịch, = 0 nếu đủ ngày và không trễ; thiếu một trong hai → NULL, không tính mẫu số.
4. Dùng full reload có kiểm soát: staging riêng, kiểm tra và nạp vào bản mới hoặc transaction phù hợp; chỉ thay bản sử dụng sau khi mọi kiểm tra thành công. Xóa fact trước dimension khi cần, rollback khi lỗi; không truncate bản đang dùng rồi để lại warehouse dở dang. Business-key unique, FK và kiểm tra số dòng/tổng tiền trước/sau hai lần chạy; không dựa chỉ vào truncate staging để chống trùng.
5. Lookup lỗi: giữ thống kê và hàng lỗi kèm business key; dùng unknown member khi có quy tắc phù hợp. Nếu có thể làm thất thoát item hoặc tiền, dừng công bố/đổi bản cho tới khi xử lý và đối chiếu, không coi load một phần là thành công.

## Hợp đồng measure

Các tổng bên dưới là `SUM`, cờ 0/1 được nạp rõ ràng; mẫu số bằng 0 hoặc NULL → kết quả NULL/blank. Thực hiện phép chia số thực/decimal, không chia nguyên. Giá trị cộng theo dimension chỉ hợp lệ trong quan hệ được hỗ trợ như trên.

| Measure | Định nghĩa và grain |
| --- | --- |
| Revenue; Freight Value; Quantity | `SUM(Price)`; `SUM(FreightValue)`; `SUM(Quantity)` từ Sales/item. |
| Order Count | `SUM(1)` từ Orders/đơn; Product/Seller lọc qua many-to-many, đếm mỗi đơn một lần trong ngữ cảnh. Không cộng Order Count của các nhóm chồng lấn. |
| Review Score Sum; Review Count; Avg Review | `SUM(ReviewScore)` theo đơn có review; `SUM(ReviewPresent)`; chia hai tổng. Khi Product/Seller lọc, lấy một review của mỗi đơn có item tương ứng. |
| Delivery Days Sum; Delivered Count; Avg Delivery Days | `SUM(DeliveryDays)`; `SUM(DeliveredFlag)`; chia hai tổng ở grain đơn. |
| Late Count; Late Eligible Count; Late Rate | `SUM(LateFlag)`; `SUM(LateEligibleFlag)`; chia hai tổng. Không tự thay mẫu số bằng tổng đơn hoặc số giao khi ngày dự kiến thiếu. |
| Freight Ratio | Freight Value / Revenue, đơn vị tỷ lệ, không phải tỷ lệ trên thanh toán. |
| Avg Order Value | Revenue / Order Count: giá trị **sản phẩm trong ngữ cảnh lọc trên mỗi đơn có item phù hợp**, không gồm freight. Với seller/category, đây không nhất thiết là giá trị toàn bộ giỏ hàng. |
| Payment Amount; Payment Share | `SUM(PaymentValue)` theo loại payment; chia cho Payment Amount của mọi loại trong cùng ngữ cảnh ngày/khách hàng. Đơn nhiều phương thức đóng góp số tiền thực tế cho mỗi phương thức. Không gọi chỉ số này Revenue. |
| MoM Growth | `(Revenue tháng hiện tại − Revenue tháng trước) / Revenue tháng trước`; tháng trước thiếu hoặc bằng 0 → blank. Câu 5 tháng 01/2017 so với 12/2016; ghi rõ mức nền rất nhỏ và không suy diễn vững chắc. |

## Ánh xạ 10 câu hỏi

| Câu | Phạm vi và đầu ra cần chứng minh |
| --- | --- |
| 1 | Năm/quý theo ngày đặt: Revenue, Order Count; thể hiện tổng năm và drill quý. |
| 2 | Top 10 danh mục theo Revenue, kèm Quantity; giữ nhóm unknown. |
| 3 | Top 5 bang khách theo Revenue; Order Count và Avg Order Value. |
| 4 | Theo phương thức: Payment Amount và Payment Share; so với tổng Payment Amount cùng filter, không phải tỷ trọng Revenue. |
| 5 | Từng tháng 2017: Revenue và MoM Growth; dùng tháng trước xuyên năm và bảo vệ chia 0. |
| 6 | 10 danh mục Avg Review thấp nhất, chỉ nhóm có Review Count ≥ 100 đơn; ghi rõ review cấp đơn, nhóm có thể chồng lấn. |
| 7 | Theo bang khách: Avg Delivery Days, Late Rate, Delivered Count và Late Eligible Count để thấy mẫu số. |
| 8 | Top 10 seller theo Revenue, kèm bang seller, Order Count và Avg Review của các đơn có seller; không gọi là review riêng seller. |
| 9 | Freight Ratio theo vùng khách, so 2017/2018 cùng kỳ **tháng 1–8**; ghi rõ khoảng thời gian, không so cả năm như hai năm đủ dữ liệu. |
| 10 | Payment Amount theo thứ ngày đặt hàng và phương thức; thứ tự thứ hai đến chủ nhật. Cùng quy ước tiền thực tế như câu 4. |

## Kiểm chứng trước khi nhận thiết kế

- SQL độc lập và SSAS/Power BI phải khớp tổng toàn tập theo snapshot: 98.199 đơn, 112.101 item, Revenue 13.494.400,74, Freight 2.241.126,29; 102.565 dòng payment của 98.198 đơn, Payment Amount 15.738.221,95 BRL. Một đơn thiếu payment không có dòng FactPayment. Số tiền này không hứa bằng Revenue + Freight.
- Theo quy tắc chọn review trên snapshot: Review Count 97.467, Review Score Sum 401.198, Avg Review ≈ 4,116244; Delivery Days Sum 1.205.571, Delivered Count 96.470, Late Eligible Count 96.470, Late Count 6.534. Các số là kết quả kiểm tra CSV, không phải cube đã chạy.
- Tạo bộ kiểm thử nhỏ: 1 đơn có 2 item thuộc 2 category/seller, 1 đơn có 1 item; review 5 và 1 → tổng bình quân 3, từng category/seller tính mỗi đơn một lần, tổng nhóm có thể chồng lấn. Thêm đơn không review, thiếu ngày giao/ngày dự kiến; không làm sai mẫu số. Kiểm tra category + seller cùng item trước khi cho phép lọc đồng thời.
- Kiểm tra đơn nhiều phương thức cộng đúng payment từng dòng, đơn thiếu `payment_sequential=1` vẫn giữ dòng payment khác, đơn không payment vẫn tính Sales/Orders. Kiểm tra unknown, nạp hai lần, tháng trước 0/thiếu, ngày trễ cùng ngày, năm không đủ và số tiền khớp SQL. Kiểm tra dimension usage, all member, subtotal, drill và ngữ cảnh đồng thời trong SSAS trước khi coi thiết kế đã hoạt động.
- Data mining đã được profile trên snapshot này. RFM theo `customer_unique_id`, frequency = distinct order, tránh nối nhân tiền; chỉ 2.887/94.983 khách (3,04%) có mua lặp trong scope, nên frequency ít phân biệt và các cụm không được đặt nhãn “trung thành” nếu không có bằng chứng. Random Forest đặt scoring tại lúc giao; chỉ dùng feature đã có khi giao, giữ đơn có review được chọn và `review_answer_timestamp >= delivered_customer_date` làm proxy chưa có nhãn: 91.170 mẫu, 8.629 nhãn thấp (score ≤ 2, 9,46%). Loại các dòng có answer timestamp trước giao; timestamp không đảm bảo thời điểm score thực sự được biết. Tách train/test theo thời gian, fit xử lý trên train, baseline và đánh giá precision/recall/F1/confusion matrix; chưa có kết quả huấn luyện.
