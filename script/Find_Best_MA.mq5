//+------------------------------------------------------------------+
//|                                                Find_Best_MA.mq5  |
//|                  Scanner MA với cơ chế Train/Test Split & Top N  |
//+------------------------------------------------------------------+
#property copyright "Do Nhat Phong"
#property version "1.0.0"
#property script_show_inputs

// --- INPUTS ---
input group "1. Danh sách Period cần quét";
input string CustomPeriods = "10,13,20,21,30,34,50,55,89,100,144,200,233";  // Nhập các số cách nhau bởi dấu phẩy
input ENUM_MA_METHOD Method = MODE_EMA;                                     // Loại MA

input group "2. Cấu hình Logic Bounce";
input double SlopePoints = 0.2;  // Độ dốc tối thiểu để xác nhận Trend tính theo points
input double TouchZone = 0.01;   // Vùng đệm nhận diện chạm (%) - QUAN TRỌNG

input group "3. Cấu hình Dữ liệu & Hiển thị";
input int LookBack = 1000;   // Số nến quá khứ
input int TestPercent = 20;  // % Dữ liệu dùng để Test (Out-of-Sample)

input group "4. Cấu hình Vẽ (Visual)";
input bool AutoDraw = true;  // Tự động vẽ đường tốt nhất lên chart?
input int DrawCount = 5;     // Số đường vẽ tối đa
input int DrawWidth = 1;     // Độ dày nét vẽ

// --- STRUCT LƯU KẾT QUẢ ---
struct MAResult
{
   int period;
   int bounces;             // Số lần bật thành công
   int failures;            // Số lần gãy (đóng nến qua MA)
   double win_rate;         // Tỷ lệ thành công (%)
   int bounces_test;        // Số lần bật thành công vùng Test
   int failures_test;       // Số lần gãy vùng Test
   double score_test_rate;  // Tỷ lệ thành công ở vùng Test
   double total_rate;       // Tỷ lệ thành công toàn bộ

   void calc(int p, int b, int f, int b_test, int f_test)
   {
      period = p;
      bounces = b;
      failures = f;
      int total = b + f;
      // Tính % Win Rate toàn bộ
      if (total > 0)
         win_rate = (double)b / total * 100.0;
      else
         win_rate = 0;

      // Tính % Win Rate vùng Test để verify
      bounces_test = b_test;
      failures_test = f_test;
      int total_test = b_test + f_test;
      if (total_test > 0)
         score_test_rate = (double)b_test / total_test * 100.0;
      else
         score_test_rate = 0;

      total_rate = win_rate * (100.0 - TestPercent) / 100.0 + score_test_rate * (TestPercent / 100.0);
   }
};

int g_ma_handle;
color g_DrawColors[] = {clrGold,         clrLawnGreen, clrDeepSkyBlue,  clrOrange,
                        clrSpringGreen,  clrSkyBlue,   clrLightCoral,   clrLightSalmon,
                        clrLemonChiffon, clrLightCyan, clrLightSkyBlue, clrLightYellow};  // Màu sắc của đường MA

//+------------------------------------------------------------------+
//| Main Program                                                     |
//+------------------------------------------------------------------+
int OnStart()
{
   Print("=== BẮT ĐẦU TÌM MA 'BEST FIT' (CONSISTENCY) ===");

   // 1. XỬ LÝ CHUỖI INPUT THÀNH MẢNG SỐ NGUYÊN
   string periodsStr[];
   int sep_count = StringSplit(CustomPeriods, ',', periodsStr);

   if (sep_count <= 0)
   {
      Print("Lỗi: Danh sách Period trống hoặc sai định dạng!");
      return 1;
   }

   int periodList[];
   ArrayResize(periodList, sep_count);
   for (int i = 0; i < sep_count; i++)
   {
      periodList[i] = (int)StringToInteger(periodsStr[i]);
   }

   // 2. CHUẨN BỊ DỮ LIỆU GIÁ
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, _Period, 1, LookBack + 5, rates);

   if (copied < LookBack)
   {
      Print("Lỗi: Không đủ dữ liệu!");
      return 1;
   }

   // Chuyển đổi % Zone thành hệ số nhân (Ví dụ 0.05% -> 0.0005)
   double zone_factor = TouchZone / 100.0;

   int split_idx = (int)(LookBack * TestPercent / 100.0);
   MAResult all_results[];

   // 3. DUYỆT QUA DANH SÁCH
   for (int i = 0; i < sep_count; i++)
   {
      int p = periodList[i];
      if (p < 2)
         continue;  // Bỏ qua period quá nhỏ

      int handle = iMA(_Symbol, _Period, p, 0, Method, PRICE_CLOSE);
      if (handle == INVALID_HANDLE)
      {
         Print("Lỗi tạo handle cho MA ", p);
         continue;
      }

      double maBuffer[];
      ArraySetAsSeries(maBuffer, true);

      if (CopyBuffer(handle, 0, 1, LookBack + 5, maBuffer) < 0)
      {
         IndicatorRelease(handle);
         continue;
      }

      double point = _Point;
      if (point == 0)
         point = 0.00001;

      int b_total = 0, f_total = 0;  // Bounce & Fail toàn bộ
      int b_test = 0, f_test = 0;    // Bounce & Fail vùng Test
      int trend = 0;                 // 1: tăng, -1: giảm, 0: neutral

      for (int i = LookBack - 1; i >= 0; i--)
      {
         double ma_curr = maBuffer[i];
         double ma_prev = maBuffer[i + 1];
         if (ma_prev == 0)
            continue;

         // Chênh lệch giá trị theo Point
         double diff = maBuffer[i] - maBuffer[i + 1];
         double slope_in_points = diff / point;
         double close = rates[i].close;
         double high = rates[i].high;
         double low = rates[i].low;

         // Biến kiểm tra kết quả nến hiện tại
         // 0: Không chạm, 1: Bounce (Tốt), -1: Fail (Xấu)
         int result = 0;

         if (trend == 0)
         {
            if (low > ma_curr)
            {
               trend = 1;
            }
            else if (high < ma_curr)
            {
               trend = -1;
            }
         }
         // 1. XU HƯỚNG TĂNG
         else if (trend == 1)
         {
            // Điều kiện Chạm: Low chạm vào MA (hoặc xuyên qua)
            if (low <= ma_curr * (1.0 + zone_factor))
            {
               // Đánh giá phản ứng:
               if (close > ma_curr * (1.0 - zone_factor))
                  result = 1;  // Rút chân thành công (Pinbar/Bounce)
               else
               {
                  trend = -1;
                  result = -1;  // Đóng cửa dưới MA -> Gãy (Fail)
               }
            }
         }
         // 2. XU HƯỚNG GIẢM
         else if (trend == -1)
         {
            // Điều kiện Chạm: High chạm vào MA (hoặc xuyên qua)
            if (high >= ma_curr * (1.0 - zone_factor))
            {
               // Đánh giá phản ứng:
               if (close < ma_curr * (1.0 + zone_factor))
                  result = 1;  // Rút chân thành công
               else
               {
                  trend = 1;
                  result = -1;  // Đóng cửa trên MA -> Gãy
               }
            }
         }

         // Không tính phản ứng khi MA đi ngang
         if (MathAbs(slope_in_points) < SlopePoints)
         {
            result = 0;
         }

         // Tổng hợp thống kê
         if (result != 0)
         {
            if (result == 1)
               b_total++;
            else
               f_total++;

            // Thống kê riêng cho vùng Test (Dữ liệu mới)
            if (i < split_idx)
            {
               if (result == 1)
                  b_test++;
               else
                  f_test++;
            }
         }
      }

      int size = ArraySize(all_results);
      ArrayResize(all_results, size + 1);
      all_results[size].calc(p, b_total, f_total, b_test, f_test);

      IndicatorRelease(handle);
   }

   // 4. SẮP XẾP THEO TEST RATE GIẢM DẦN
   int count = ArraySize(all_results);
   for (int i = 0; i < count - 1; i++)
   {
      for (int j = 0; j < count - i - 1; j++)
      {
         if (all_results[j].total_rate < all_results[j + 1].total_rate)
         {
            MAResult temp = all_results[j];
            all_results[j] = all_results[j + 1];
            all_results[j + 1] = temp;
         }
      }
   }

   // 5. IN KẾT QUẢ
   Print(
       "---------------------------------------------------------------------------------------------------------------"
       "--------------------");
   Print("CHIẾN LƯỢC: TÌM SỰ NHẤT QUÁN (CONSISTENCY / WIN RATE)");
   Print("Loại bỏ các đường MA bị xuyên phá (Fail) quá nhiều.");
   Print(
       "---------------------------------------------------------------------------------------------------------------"
       "--------------------");
   PrintFormat("| %-5s | %-6s | %-10s | %-12s | %-12s | %-10s | %-10s | %-14s | %-12s |", "RANK", "PERIOD", "WIN RATE",
               "TEST RATE", "TOTAL RATE", "BOUNCES", "FAILS", "BOUNCES TEST", "FAILS TEST");
   Print(
       "---------------------------------------------------------------------------------------------------------------"
       "--------------------");

   for (int i = 0; i < count; i++)
   {
      string comment = "";

      // Cảnh báo nếu vùng Test (gần đây) bị sụt giảm hiệu suất nghiêm trọng
      if (all_results[i].score_test_rate < all_results[i].win_rate * 0.8)
      {
         comment = " [Cảnh báo: Gần đây yếu đi]";
      }
      else if (all_results[i].score_test_rate > 90.0)
      {
         comment = " [Rất mạnh gần đây]";
      }

      PrintFormat("| #%-4d | %-6d | %-9.1f%% | %-11.1f%% | %-11.1f%% | %-10d | %-10d | %-14d | %-12d |%s", i + 1,
                  all_results[i].period, all_results[i].win_rate, all_results[i].score_test_rate,
                  all_results[i].total_rate, all_results[i].bounces, all_results[i].failures,
                  all_results[i].bounces_test, all_results[i].failures_test, comment);
   }
   Print(
       "---------------------------------------------------------------------------------------------------------------"
       "--------------------");

   // 6. TỰ ĐỘNG VẼ LÊN CHART
   int draw_count = MathMin(DrawCount, count);
   if (AutoDraw && draw_count > 0)
   {
      int color_size = ArraySize(g_DrawColors);
      for (int i = 0; i < draw_count; i++)
      {
         int p = all_results[i].period;
         Print(">> Đang thêm đường MA vào biểu đồ: ", p);

         // Dùng "Examples\\Custom Moving Average" (đã modified để thêm inputs) để chỉnh màu
         // Đường dẫn này tồn tại mặc định trong mọi MT5
         g_ma_handle = iCustom(NULL, 0, "Examples\\Custom Moving Average",
                               p,                             // Period
                               0,                             // Shift
                               Method,                        // Method
                               g_DrawColors[i % color_size],  // Color
                               DrawWidth,                     // Width
                               PRICE_CLOSE                    // Price
         );

         if (g_ma_handle != INVALID_HANDLE)
         {
            // Thêm vào cửa sổ chính (subwin = 0)
            if (!ChartIndicatorAdd(0, 0, g_ma_handle))
            {
               Print("Lỗi thêm Indicator: ", GetLastError());
            }
         }
      }
   }

   return 0;
}
