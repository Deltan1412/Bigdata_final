## **5 câu hỏi kinh doanh từ dữ liệu dự báo bán hàng theo tuần**

1. **Cửa hàng nào cần được kiểm tra nguy cơ thiếu hàng trước?** Ở đâu sản lượng thực tế liên tục vượt dự báo, và phần chênh lệch này có đủ lớn để ưu tiên rà soát kế hoạch bổ sung hàng cho tuần sau?
2. **Cửa hàng nào có dấu hiệu được lập kế hoạch nhập hàng quá cao?** Ở đâu dự báo liên tục vượt sản lượng thực tế, kể cả khi chỉ xét các tuần đủ dữ liệu? Cửa hàng nào nên được kiểm tra tồn kho trước khi quyết định giảm lượng nhập?
3. **Nếu mục tiêu là bảo vệ doanh thu, nên ưu tiên cải thiện dự báo ở cửa hàng nào?** Cửa hàng có sai lệch sản lượng lớn nhất có đồng thời có sai lệch doanh thu lớn nhất không? Thứ tự ưu tiên thay đổi thế nào khi xếp hạng theo giá trị doanh thu thay vì số đơn vị?
4. **Dự báo có thiên lệch theo khu vực không?** Khi so sánh CA, TX và WI theo tỷ lệ chênh lệch so với sản lượng thực tế, khu vực nào thường bị dự báo cao hoặc thấp? Xu hướng đó xuất hiện ở nhiều cửa hàng hay chủ yếu do một cửa hàng chi phối?
5. **Tổng số theo khu vực có đang che giấu sai lệch ở từng cửa hàng không?** Có tuần nào tổng dự báo của khu vực gần sát thực tế vì cửa hàng dự báo thừa bù cho cửa hàng dự báo thiếu? Nếu có, nên điều chỉnh dự báo ở cửa hàng nào trước khi thay đổi kế hoạch cho cả khu vực?

---

# **Kế hoạch Triển khai Week 4 — M5 Retail Forecasting**

**Mục tiêu:** Hoàn thiện dashboard dự báo cho 10 cửa hàng, demo luồng **MySQL → KNIME → Mô hình → MySQL → Power BI**, giải thích 3 quyết định về tồn kho, doanh thu và thiên lệch khu vực.

## **1. Action Plan theo 6 yêu cầu Week 4**

- **Demo hệ thống End-to-End:**  
  - Trình bày luồng dữ liệu: MySQL cấp dữ liệu → KNIME (Linear Regression dự báo sản lượng) → Ghi kết quả vào *sales_predictions* → SQL ghép giá, tính doanh thu và tổng hợp theo Cửa hàng–Tuần cho Power BI.  
  - Phân tích Data Aggregation: **39.496 dòng dự báo → 19.748 dòng chi tiết → 110 dòng cửa hàng–tuần**. Bộ lọc đảm bảo 100% không có số âm. Doanh thu tính ở cấp SKU–cửa hàng–ngày rồi mới cộng theo tuần.  
  - Kiểm tra trước demo: Chạy lại DB Writer, đối soát số dòng, mở mẫu dự báo trong MySQL. Chuẩn bị sẵn truy vấn/hướng dẫn tái tạo bảng từ dữ liệu nguồn và đảm bảo không phát sinh bản ghi trùng.
- **Hoàn thiện Interactive Dashboard:**  
  - Lấy nguồn từ MySQL. Hiển thị Sản lượng &amp; Doanh thu Thực tế vs. Dự báo kèm bộ lọc **Bang, Cửa hàng, Tuần**. Dùng biểu đồ đường xem theo thời gian và biểu đồ cột có trục 0 để thấy mức lệch theo vùng.  
  - Tách biệt dữ liệu: Giữ **110 dòng** trên dashboard, dùng **100 dòng đủ 7 ngày** làm tập chính để báo cáo sai số.  
  - Kiểm tra trước demo: Refresh dữ liệu, lọc thử *CA -&gt; CA_3* kiểm tra KPI và biểu đồ.
- **Chốt 3 Đề xuất Kinh doanh:**  
  - **Rà soát nguy cơ thiếu hàng ở CA_1 &amp; CA_3:** Sản lượng thực tế vượt dự báo ở cả 2 cửa hàng trong **10/10 tuần đủ ngày**. *Hành động:* Tìm SKU lệch nhiều, đối chiếu tồn khả dụng để điều chỉnh điểm đặt hàng.  
  - **Ưu tiên giảm sai số doanh thu ở CA_3:** CA_3 có **MAE doanh thu cao nhất (~128.73 USD/tuần)**. *Hành động:* Tìm SKU đóng góp nhiều nhất vào sai số để rà soát lại dự báo và xếp thứ tự ưu tiên theo giá trị tiền.  
  - **Hiệu chỉnh dự báo theo vùng:** Dự báo doanh thu thấp hơn thực tế **20.20% ở CA**, nhưng cao hơn **4.76% ở TX** và **3.27% ở WI**. *Hành động:* Kiểm tra nguyên nhân lệch và thử hiệu chỉnh hệ số theo bang (chỉ áp dụng nếu giảm thiên lệch và cải thiện MAE).
- **Hoàn thiện Báo cáo IEEE:**  
  - Xử lý cảnh báo Numeric Scorer từ Week 3, xác nhận biến đầu vào và thời gian chia Train/Test. Trình bày riêng điểm test KNIME và sai số sau tổng hợp.  
  - Số liệu chốt trên 100 dòng đủ ngày: **Sản lượng:** MAE = **12.59 đơn vị**, MAPE = **14.43%**. **Doanh thu:** MAE = **65.07 USD**, MAPE = **17.73%**.  
  - Quy cách: Bài 6–10 trang, 2 cột, tối thiểu 5 nguồn tham khảo. Nộp PDF kèm file chỉnh sửa (DOCX/LaTeX).
- **Đóng gói bài nộp &amp; Q&amp;A:**  
  - Gom SQL script, hướng dẫn data, workflow KNIME, file Power BI, bài IEEE và README lên GitHub/Workspace.  
  - Chuẩn bị phần Q&amp;A: Sẵn sàng giải thích về khóa nối, bản ghi trùng, công thức doanh thu, cách chia tập train/test, MAE/MAPE và chuyển số liệu thành đề xuất kinh doanh.
- **Tổng kết Plan vs Actual:**  
  - Lập bảng so sánh việc đã cam kết, giờ dự kiến vs. thực tế, chênh lệch và phương án xử lý.  
  - Mở đầu bằng 4 câu hỏi Week 4: *Bàn giao gì, khi nào, tại sao chọn sản phẩm đó và đã dùng bao nhiêu giờ công*.

## **2. Dàn ý Báo cáo IEEE (6 phần chính)**

- **Abstract &amp; Keywords**  
- **I. Introduction:** Bối cảnh 10 cửa hàng (CA, TX, WI) và 3 câu hỏi kinh doanh trọng tâm.  
- **II. Related Work:** Bộ dữ liệu M5, các phương pháp dự báo bán lẻ và lý do chọn Linear Regression, MAE, MAPE.  
- **III. Methodology:** Luồng hệ thống, tập dữ liệu, biến đầu vào, chia train/test, xử lý trùng, ghép giá và tổng hợp tuần.  
- **IV. Experiments &amp; Results:** Báo cáo điểm test KNIME và sai số cấp cửa hàng–tuần (bảng MAE/MAPE, biểu đồ Actual vs Forecast, độ lệch theo bang).  
- **V. Discussion &amp; Decision Recommendations:** 3 đề xuất kinh doanh kèm bằng chứng và rủi ro. Giải trình giới hạn dữ liệu 1 năm (chỉ bao phủ 1 chu kỳ mùa vụ) và làm rõ khoảng đánh giá chính từ 11/03 đến 22/05/2016 (10 tuần đủ ngày).  
- **VI. Conclusion:** Tóm tắt kết quả hệ thống và hướng phát triển tiếp theo.  
- **References**

## **3. Dàn ý Slide Thuyết trình (10 slide)**

1. **Week 4 bàn giao gì:** Mục tiêu, thời điểm bàn giao, lý do chọn sản phẩm và tổng giờ công.
2. **3 Câu hỏi Kinh doanh:** Cửa hàng nguy cơ thiếu hàng, ưu tiên sai số doanh thu ở đâu và bang nào bị dự báo lệch.
3. **Luồng hệ thống:** Sơ đồ MySQL → KNIME → Linear Regression → MySQL → Power BI.
4. **Data Aggregation:** Sơ đồ 39.496 → 19.748 → 110 dòng, cách tính doanh thu và tách tuần thiếu ngày.
5. **Thiết kế đánh giá &amp; Giới hạn:** Trục thời gian train/test, giới hạn data 1 năm và phạm vi 10 tuần đủ ngày.
6. **MAE, MAPE &amp; Sai lệch theo bang:** Khung chỉ số sai số doanh thu/sản lượng và biểu đồ độ lệch CA/TX/WI.
7. **Demo trực tiếp:** Chạy luồng ghi MySQL, refresh Power BI và lọc *CA -&gt; CA_3* đối chiếu thực tế vs. dự báo.
8. **3 Đề xuất Kinh doanh:** Trình bày rõ Số liệu chứng minh → Hành động → KPI theo dõi.
9. **Plan vs Actual &amp; Bàn giao:** Giờ kế hoạch vs. thực tế, đóng góp cá nhân và checklist file nộp.
10. **Kết luận &amp; Q&amp;A:** Tóm tắt giá trị Dashboard và chuẩn bị giải đáp thắc mắc.