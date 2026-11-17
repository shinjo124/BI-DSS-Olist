# Bàn giao — 17/11/2026

## Mục tiêu và yêu cầu

Nhóm hai người cần hoàn thành đồ án BI. Theo yêu cầu người dùng cung cấp: báo cáo tối đa 100 trang mô tả chọn dữ liệu và SSIS; schema, xây cube, phân tích thủ công và báo cáo 10 câu với SSAS/Power BI; phân tích bằng MDX và Excel Pivot; data mining với 2 thuật toán. Nộp link Google Drive, chia sẻ `phungntk@uit.edu.vn`, gồm báo cáo DOCX/PDF, dataset, project SSIS, SSAS kèm Power BI và Excel, mã mining; video là bonus. Đã xác minh cây thư mục Drive và `olist-download.zip` trong `2_Dataset/`; quyền tải của từng thành viên và quyền chia sẻ với giảng viên chưa xác minh.

Repo source của nhóm là [shinjo124/BI-DSS-Olist](https://github.com/shinjo124/BI-DSS-Olist); local `origin` đã trỏ tới URL này. GitHub hiện trống và workspace chưa có commit/push.

Đề cương Olist là nguồn làm việc ban đầu, không phải bằng chứng đã triển khai hoặc yêu cầu bổ sung của giảng viên. File gốc được sao chép nguyên vẹn vào `references/`. Yêu cầu dán ở trên là căn cứ đối chiếu; nếu có rubric chính thức khác cần đối chiếu lại.

## Quyết định đã chốt và phần còn mở

- Đã xác nhận nhóm 2 người, chưa có deadline cụ thể. Các project SSIS/SSAS lab đã khảo sát chỉ là bài tham khảo, không phải đồ án.
- Giữ Olist và 10 câu làm định hướng; được sửa schema, measure và MDX nếu cần, ghi lại thay đổi và lý do. Thiết kế logic đã chốt trong [THIET_KE_OLIST.md](THIET_KE_OLIST.md): ba measure group theo grain Sales/Order/Payment; SSAS many-to-many cần kiểm chứng khi triển khai.
- Thực hiện 10 câu với SSAS thủ công và Power BI. Nhóm đặt mục tiêu ít nhất 3 câu MDX và 3 phân tích Excel; số 3 là quyết định nhóm, không phải yêu cầu được nêu trong đề. Điều chỉnh nếu giảng viên yêu cầu thêm.
- Câu 4/10 giữ từng phương thức thanh toán riêng theo `payment_type`, cộng `payment_value` từ các dòng thực tế; đơn có nhiều phương thức đóng góp vào từng loại tương ứng. Không chọn phương thức chính hay gộp thành một nhóm “All”.
- Dùng K-Means phân nhóm khách hàng và Random Forest dự đoán đánh giá thấp tại lúc giao hàng. Snapshot cho thấy chỉ 3,04% khách trong scope mua lặp; cohort Random Forest theo proxy `review_answer_timestamp >= delivered_customer_date` có 91.170 mẫu, 9,46% score ≤ 2. Chi tiết, giới hạn proxy và cách nhận diện snapshot ở [báo cáo kiểm tra dataset](2_Dataset/KIEM_TRA_DATASET.md).
- [Phân công A/B](PHAN_CONG.md) là phương án ban đầu đã được người dùng chốt; tên thành viên và cân bằng khối lượng thực tế còn cần xác nhận. Ưu tiên phần bắt buộc trước video.
- Nguồn dataset đã chọn là [Olist trên Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce). Snapshot đã tải và kiểm tra, nhận diện bằng SHA-256 trong [KIEM_TRA_DATASET.md](2_Dataset/KIEM_TRA_DATASET.md). Đã xác minh `olist-download.zip` có trong Drive/`2_Dataset/`; local ZIP/CSV vẫn bị Git ignore. Git lưu source và tài liệu; Drive lưu dataset, video và bộ nộp. Quyền tải của thành viên và quyền giảng viên chưa xác minh.

## Môi trường và tài nguyên

Mỗi thành viên cần tự kiểm tra SQL Server, SSIS, SSAS Multidimensional, Power BI Desktop, Excel và Python trên máy mình; phiên bản, instance, quyền truy cập và đường dẫn có thể khác nhau. Chưa có cấu hình chung hoặc hướng dẫn cài đặt đã kiểm chứng cho nhóm. Khi có project, ghi lại phiên bản cần thiết, cách cấu hình kết nối và cách chạy trên máy mới.

Đề cương đã có trong repo; dataset Olist có snapshot local và ZIP đã upload vào Drive/`2_Dataset/`; tài liệu môn học chưa được đưa vào repo. Chưa xác minh thành viên khác tải được file hoặc quyền chia sẻ với giảng viên.

## Điểm thiết kế cần kiểm chứng

- Quy ước grain và các chỉ số đã ghi ở `THIET_KE_OLIST.md`; khi triển khai cần kiểm thử số liệu, NULL, ngày, nạp lại và các trường hợp nhiều item/seller/payment.
- SSAS many-to-many Product/Seller→Orders và tổ hợp Product+Seller cùng item là điểm kỹ thuật cần kiểm chứng; không công bố tổ hợp chưa chứng minh đúng.
- Cohort mining đã profile theo snapshot. Tách train/test theo thời gian, chỉ dùng feature có sẵn tại thời điểm dự đoán và báo cáo giới hạn timestamp review.

Các quy ước đã đối chiếu với snapshot CSV; việc xác nhận cuối cùng là bằng kết quả SQL/SSAS sau khi triển khai.

## Việc tiếp theo

1. Điền tên A/B; nhờ thành viên khác tải ZIP từ Drive/`2_Dataset/` và đối chiếu hash.
2. Dùng các quy ước và expected totals trong [thiết kế warehouse](THIET_KE_OLIST.md) làm hợp đồng triển khai; ghi lại nếu dữ liệu/chứng cứ mới buộc phải đổi.
3. Dựng warehouse/SSIS và kiểm tra tính lặp; sau đó build/process SSAS, chứng minh many-to-many/filter context rồi tạo report và Pivot.
4. Thực hiện hai thuật toán mining theo cohort và đặc trưng hợp lệ; ghi cách chia dữ liệu, baseline, đánh giá và kết quả thật.
5. Gom minh chứng, viết DOCX/PDF không quá 100 trang, kiểm tra cấu trúc nộp, quyền chia sẻ Drive và link. Video làm sau phần bắt buộc nếu nhóm chọn.

Không dựng số liệu, ảnh hay kết quả chạy. Trước khi chạy thao tác xóa/nạp, deploy hoặc process trên máy thật, xác định rõ mục tiêu và ảnh hưởng; không ghi đè dữ liệu lab. Khi có sản phẩm, cập nhật trạng thái, đường dẫn tương đối và cách xác minh vào đây hoặc README.
