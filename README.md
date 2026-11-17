# Đồ án cuối kỳ BI — Olist

Repo bàn giao bối cảnh cho nhóm hai người và agent tiếp tục công việc. GitHub remote: [shinjo124/BI-DSS-Olist](https://github.com/shinjo124/BI-DSS-Olist). Trong repo hiện có đề cương và tài liệu thiết kế; **chưa có sản phẩm Olist được xác minh**. Chưa có deadline cụ thể.

## Đọc trước

1. [Bàn giao và việc tiếp theo](HANDOFF.md): yêu cầu, quyết định, câu hỏi còn mở và thứ tự làm việc.
2. [Đề cương gốc](references/Olist-original-outline.docx): phương án đề xuất, gồm schema, 10 câu hỏi, MDX và mining; không mặc định mọi lựa chọn trong đó đã được duyệt.
3. [Flow và phân công](PHAN_CONG.md): sơ đồ dự án, checklist A/B và các điểm bàn giao đã thống nhất.

Chưa có mã ETL, cube, báo cáo hay kết quả mining. Snapshot Olist đã profile nằm local trong `2_Dataset/raw/` và bị Git ignore; ZIP cũng nằm local ở gốc và bị ignore. ZIP đã được xác minh trong Drive/`2_Dataset/`; người clone nên tải bản đó và xác nhận hash theo `2_Dataset/KIEM_TRA_DATASET.md`. Không có lệnh build/test chung; từng sản phẩm cần ghi hướng dẫn chạy và kiểm chứng. Không coi project lab là sản phẩm đồ án.

## Cấu trúc dự kiến khi triển khai

`1_Report/`, `2_Dataset/`, `3_SSIS/`, `4_SSAS/`, `5_DataMining/`, `6_Videos/` tương ứng các phần nộp bài; cây thư mục này đã được tạo trong [Drive nhóm](https://drive.google.com/drive/folders/1hKuZP3kOY0uqP6j4WBQASlRBnHyWJew3?usp=sharing). Đã xác minh `olist-download.zip` có trong `2_Dataset/`. Git lưu source và tài liệu; Drive dùng cho dataset, video và bộ nộp. Chưa xác minh quyền truy cập của từng thành viên hoặc giảng viên. Không lưu mật khẩu hay cấu hình gắn cứng với máy cá nhân.
