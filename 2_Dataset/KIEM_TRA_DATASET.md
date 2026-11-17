# Kiểm tra dataset Olist — 17/11/2026

## Nguồn và phạm vi

Đã tải archive từ API của [Olist trên Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce); giấy phép trên trang nguồn: **CC BY-NC-SA 4.0**. Archive được tải ngày 17/11/2026, SHA-256 `967e41e04fc306fe604e2a693f488995a8b41e5047418f8a5c8e4abd6deca784`; kiểm tra toàn vẹn ZIP thành công. Chưa xác định được số version Kaggle từ metadata nên dùng hash để nhận diện snapshot, không tự suy đoán version. Có thể tải lại bằng `https://www.kaggle.com/api/v1/datasets/download/olistbr/brazilian-ecommerce` và đối chiếu hash; nếu bản nguồn thay đổi, phải giữ snapshot cũ hoặc chạy lại kiểm tra.

CSV được giải nén ở `2_Dataset/raw/` trên máy kiểm tra và được Git ignore. Đã xác minh `olist-download.zip` có trong Drive/`2_Dataset/`. Chưa xác minh thành viên khác tải được file hay quyền chia sẻ với giảng viên. Người khác nên tải ZIP này và đối chiếu SHA-256 bên dưới; link Kaggle có thể trả archive mới hơn.

| CSV | Dòng | SHA-256 |
| --- | ---: | --- |
| olist_customers_dataset.csv | 99.441 | `983a422239e1712ded753b3bf9ecf47dc73f144d306029dcfa99e70a226883d2` |
| olist_geolocation_dataset.csv | 1.000.163 | `b514f6fc991b9566aeba02aa5d67e2c3630f034b60a0e05aa0d082a3b66d88d6` |
| olist_order_items_dataset.csv | 112.650 | `0bc4d068c4fe38cbb01bd90e8746e3c613fe7b4baef75fab7b0e329701c3e279` |
| olist_order_payments_dataset.csv | 103.886 | `4f713964f2815dbbaa40b9488268c55aac3627bfce5aa96cf58d1f3616de3cc0` |
| olist_order_reviews_dataset.csv | 99.224 | `012b61c7593e34f51fa614efdf802b9c7056ce6aae5307ddb93236e7cfc797d7` |
| olist_orders_dataset.csv | 99.441 | `8df58ef3d2d7e9944010f7beecd9b75367f5588ec6e3c91cec19ae3345ef9ecf` |
| olist_products_dataset.csv | 32.951 | `3e6569628a17fbc75fd206ee357b59e20364b9afa90f5b6cd5b4d624c58aa9cc` |
| olist_sellers_dataset.csv | 3.095 | `1f643d2b950373b85735e7794b20986f528d7a000432e7c6f9bcbb44d0846a0e` |
| product_category_name_translation.csv | 71 | `a81f0d1f27b27e7293f761bc79e3ce8f348ee39c4b3ed3e49bde38f478586278` |

## Kết quả kiểm tra

Đọc CSV bằng pandas 3.0.6, đếm dòng, NULL, khóa trùng và join keys; các phép đếm dưới đây theo snapshot và quy tắc được chỉ rõ, không phải kết quả từ warehouse hay cube.

- `orders.order_id`, `customers.customer_id`, `products.product_id`, `sellers.seller_id`, `(order_id, order_item_id)` và `(order_id, payment_sequential)` không trùng. Không thấy item thiếu order/product/seller, order thiếu customer, hoặc payment/review thiếu order. Chưa chứng minh mọi quy tắc chất lượng khác đều đạt.
- Trạng thái: delivered 96.478; shipped 1.107; canceled 625; unavailable 609; invoiced 314; processing 301; created 5; approved 2. Purchase timestamp toàn bộ: 04/09/2016–17/10/2018.
- Loại canceled/unavailable như đề cương: 98.207 đơn; 8 đơn không có item. Nếu chỉ tính đơn có ít nhất một item: **98.199 đơn, 112.101 item**, tổng item price **13.494.400,74 BRL**, freight **2.241.126,29 BRL**. Không thấy giá hay freight âm trong tập item này. Tám đơn không item phải được báo cáo riêng, không tự biến mất khỏi số lượng kiểm soát.
- Trong 98.199 đơn có item: 9.761 đơn có nhiều item (98.199 − 88.438 đơn một item); 1.277 đơn có nhiều seller; 785 đơn có nhiều danh mục (coi danh mục NULL là unknown). Các chiều phân tích theo order không thể cộng số đơn/review giữa các nhóm để suy ra tổng chung.
- Có 2.961 đơn toàn bộ có nhiều dòng thanh toán, 2.246 đơn nhiều loại thanh toán; trong tập 98.199 đơn có item, 2.211 đơn nhiều loại. Trong cùng tập có **80 đơn không có payment_sequential = 1**: 79 có dòng payment khác và 1 không có payment. Không được inner join hoặc bỏ các đơn này một cách im lặng.
- Tổng cộng 547 order có nhiều dòng review; 314 dòng thuộc các cặp trùng `(order_id, review_creation_date)` trên toàn bộ review. Trong tập đơn có item, 97.467 đơn có review, 732 không có. Sắp giảm dần theo `review_creation_date`, `review_answer_timestamp`, `review_id`, `review_score`, rồi lấy dòng đầu cho mỗi order cho ra tổng review score 401.198, trung bình theo đơn **4,11624**. Nối review đó với item rồi lấy trung bình cho ra **4,04446** — hai đại lượng khác nhau.
- Toàn bộ order có 2.965 giá trị `order_delivered_customer_date` thiếu; 160 thiếu approval timestamp. Trong tập 98.199 đơn có item, 96.470 có ngày giao; 8 đơn status delivered vẫn thiếu ngày giao. Product có 610 category NULL; 13 product có category khác NULL nhưng không khớp bảng dịch. Không mặc định translation thiếu là product thiếu.
- Theo calendar date, ngày giao trước ngày mua: 0 trong tập đơn đủ điều kiện. Với cách chênh lệch ngày lịch và giao sau ngày dự kiến là trễ, tập đơn có item có tổng **1.205.571 ngày**, 96.470 đơn có ngày giao, **6.534 đơn trễ** (mẫu số đủ cả ngày giao lẫn ngày dự kiến: 96.470). Đây là phép kiểm tra phương án định nghĩa, chưa phải kết quả cube.
- Trong phạm vi warehouse (98.199 đơn có item), có **94.983** `customer_unique_id`; **92.096** khách có đúng một đơn và **2.887** có nhiều hơn một (3,04%). Frequency RFM có ít độ phân biệt; không tự gọi cụm có nhiều doanh thu là trung thành.
- Theo review được chọn cho mỗi đơn bằng quy tắc ở trên, trong phạm vi warehouse có ngày giao và review có **95.824** đơn. Với mốc scoring tại timestamp giao và `review_answer_timestamp >= delivered_customer_date` làm điều kiện xấp xỉ nhãn chưa xuất hiện: **91.170** mẫu còn lại, trong đó **8.629 (9,46%)** có score ≤ 2. Có 4.966 dòng review được chọn có ngày tạo trước ngày giao, 3.161 cùng ngày; 4.654 dòng có timestamp trả lời trước lúc giao. Timestamp trả lời không chứng minh tuyệt đối thời điểm score được biết, nên đây là cohort sạch hơn theo proxy chứ không phải bảo đảm không leakage. Nêu số mẫu bị loại và giới hạn này khi báo cáo mining.

Lưu ý về thời gian: 2018 không đầy đủ cả năm; khi so sánh năm, dùng cùng kỳ hoặc ghi rõ kỳ. Toàn bộ dữ liệu là lịch sử, không suy diễn tình hình kinh doanh hiện tại. Chưa train model, chưa test SSIS/SSAS với snapshot này, và chưa kiểm tra mọi trường hợp chất lượng hoặc quyền chia sẻ.
